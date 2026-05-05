import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../services/cloud_service.dart';
import '../services/storage_service.dart';
import '../theme.dart';

/// Page to view and download cloud-stored attendance sessions
class CloudSessionsPage extends StatefulWidget {
  const CloudSessionsPage({super.key});

  @override
  State<CloudSessionsPage> createState() => _CloudSessionsPageState();
}

class _CloudSessionsPageState extends State<CloudSessionsPage> {
  final CloudService _cloudService = CloudService();
  final StorageService _storage = StorageService();

  List<Map<String, dynamic>> _sessions = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final sessions = await _cloudService.fetchSessions();
      setState(() {
        _sessions = sessions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _downloadSession(String sessionId, String courseName) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
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

      // Store locally for offline access and export
      // (The existing PDF/Excel export can then use this data)

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Downloaded ${records.length} records for $courseName'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _signOut() async {
    await _cloudService.signOut();
    if (mounted) {
      context.go('/');
    }
  }

  String _formatDate(String? isoDate) {
    if (isoDate == null) return 'Unknown';
    try {
      final date = DateTime.parse(isoDate);
      return DateFormat('MMM dd, yyyy - HH:mm').format(date);
    } catch (_) {
      return isoDate;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _cloudService.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cloud Sessions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorView()
              : _sessions.isEmpty
                  ? _buildEmptyView()
                  : _buildSessionsList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loadSessions,
        icon: const Icon(Icons.refresh),
        label: const Text('Refresh'),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: AppSpacing.paddingLg,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Failed to load sessions',
              style: context.textStyles.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              _error!,
              style: context.textStyles.bodyMedium?.withColor(Colors.red[700]!),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton.icon(
              onPressed: _loadSessions,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Padding(
        padding: AppSpacing.paddingLg,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No Cloud Sessions',
              style: context.textStyles.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Your synced sessions will appear here.\nCreate a session while signed in to sync to the cloud.',
              style: context.textStyles.bodyMedium?.withColor(Colors.grey[600]!),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionsList() {
    return ListView.builder(
      padding: AppSpacing.paddingMd,
      itemCount: _sessions.length,
      itemBuilder: (context, index) {
        final session = _sessions[index];
        final isActive = session['isActive'] == true;
        final courseName = session['courseName'] ?? 'Untitled';
        final courseCode = session['courseCode'] as String?;
        final sessionNumber = session['sessionNumber'] ?? 1;
        final totalAttendees = session['totalAttendees'] ?? 0;
        final verifiedCount = session['verifiedCount'] ?? 0;
        final startTime = _formatDate(session['startTime']);
        final sessionPin = session['sessionPin'] as String?;

        return Card(
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: ExpansionTile(
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isActive
                    ? Colors.green[100]
                    : Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(
                isActive ? Icons.play_circle : Icons.check_circle,
                color: isActive ? Colors.green[700] : null,
              ),
            ),
            title: Text(
              courseName,
              style: context.textStyles.titleMedium?.semiBold,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (courseCode != null) Text('Code: $courseCode'),
                Text('Session #$sessionNumber • $startTime'),
              ],
            ),
            children: [
              Padding(
                padding: AppSpacing.paddingMd,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stats row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _StatChip(
                          icon: Icons.people,
                          label: 'Total',
                          value: totalAttendees.toString(),
                          color: Colors.blue,
                        ),
                        _StatChip(
                          icon: Icons.verified,
                          label: 'Verified',
                          value: verifiedCount.toString(),
                          color: Colors.green,
                        ),
                        _StatChip(
                          icon: Icons.pending,
                          label: 'Pending',
                          value: (totalAttendees - verifiedCount).toString(),
                          color: Colors.orange,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // PIN display
                    if (sessionPin != null) ...[
                      Container(
                        padding: AppSpacing.paddingMd,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.pin),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              'PIN: $sessionPin',
                              style: context.textStyles.titleMedium?.semiBold,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],

                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _downloadSession(
                              session['id'],
                              courseName,
                            ),
                            icon: const Icon(Icons.download),
                            label: const Text('Download Records'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  Theme.of(context).colorScheme.primary,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: context.textStyles.titleMedium?.semiBold.withColor(color),
        ),
        Text(
          label,
          style: context.textStyles.bodySmall?.withColor(Colors.grey[600]!),
        ),
      ],
    );
  }
}
