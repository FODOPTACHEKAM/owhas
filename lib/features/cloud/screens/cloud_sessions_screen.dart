import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../services/cloud_service.dart';
import '../../../services/storage_service.dart';
import '../../../theme.dart';
import '../widgets/cloud_session_card.dart';
import '../widgets/cloud_session_placeholders.dart';

/// Refactored cloud-sessions screen — build() ≤ 25 lines.
///
/// The existing [CloudSessionsPage] in `lib/pages/` is untouched
/// until routing is migrated in a later phase.
class CloudSessionsScreen extends StatefulWidget {
  const CloudSessionsScreen({super.key});

  @override
  State<CloudSessionsScreen> createState() => _CloudSessionsScreenState();
}

class _CloudSessionsScreenState extends State<CloudSessionsScreen> {
  final CloudService   _cloudService = CloudService();
  // ignore: unused_field
  final StorageService _storage      = StorageService();

  List<Map<String, dynamic>> _sessions = [];
  bool    _isLoading = true;
  String? _error;

  @override
  void initState() { super.initState(); _loadSessions(); }

  Future<void> _loadSessions() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final sessions = await _cloudService.fetchSessions();
      setState(() { _sessions = sessions; _isLoading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  Future<void> _downloadSession(String sessionId, String courseName) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Downloading...'),
          ],
        ),
      ),
    );
    try {
      final records = await _cloudService.fetchRecords(sessionId);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:         Text('Downloaded ${records.length} records for $courseName'),
        backgroundColor: Colors.green,
      ));
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:         Text('Download failed: $e'),
        backgroundColor: Colors.red,
      ));
    }
  }

  Future<void> _signOut() async {
    await _cloudService.signOut();
    if (mounted) context.go('/');
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:   const Text('Cloud Sessions'),
        actions: [
          IconButton(
            icon:      const Icon(Icons.logout),
            onPressed: _signOut,
            tooltip:   'Sign Out',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? CloudErrorView(error: _error!, onRetry: _loadSessions)
              : _sessions.isEmpty
                  ? const CloudEmptyView()
                  : _buildSessionsList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loadSessions,
        icon:      const Icon(Icons.refresh),
        label:     const Text('Refresh'),
      ),
    );
  }

  Widget _buildSessionsList() {
    return ListView.builder(
      padding:   AppSpacing.paddingMd,
      itemCount: _sessions.length,
      itemBuilder: (_, i) => CloudSessionCard(
        key:        ValueKey(_sessions[i]['id']),
        session:    _sessions[i],
        onDownload: _downloadSession,
      ),
    );
  }
}
