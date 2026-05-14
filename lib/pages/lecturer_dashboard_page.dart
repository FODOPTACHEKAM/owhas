import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/attendance_provider.dart';
import '../nav.dart';
import '../widgets/dashboard/session_header.dart';
import '../widgets/dashboard/qr_code_section.dart';
import '../widgets/dashboard/attendance_records_section.dart';
import '../utils/dialog_helpers.dart';

class LecturerDashboardPage extends StatefulWidget {
  const LecturerDashboardPage({super.key});

  @override
  State<LecturerDashboardPage> createState() => _LecturerDashboardPageState();
}

class _LecturerDashboardPageState extends State<LecturerDashboardPage> {
  bool _isEndingSession = false;
  int _qrRefreshKey = 0;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!mounted) {
        _refreshTimer?.cancel();
        return;
      }

      final provider = context.read<AttendanceProvider>();
      final session = provider.activeSession;

      if (session != null &&
          session.endTime != null &&
          DateTime.now().isAfter(session.endTime!)) {
        _refreshTimer?.cancel();
        await provider.forceEndSession();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Session ended — time limit reached'),
              duration: Duration(seconds: 4),
            ),
          );
          context.go(AppRoutes.home);
        }
        return;
      }

      // Refresh records and Wi-Fi count in parallel
      await Future.wait([
        provider.refreshRecords(),
        provider.refreshWifiDeviceCount(),
      ]);
    });
  }

  Future<void> _downloadAndShareServerPdf() async {
    final provider = context.read<AttendanceProvider>();
    final success = await provider.generateAndSharePDFReport();
    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF shared')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.error ?? 'Failed to share PDF'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _downloadPdfToDevice() async {
    final provider = context.read<AttendanceProvider>();
    final filePath = await provider.downloadPDFReport();
    if (mounted) {
      if (filePath != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF saved to: $filePath')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.error ?? 'Failed to download PDF'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _showAddManualStudentDialog() async {
    final data = await DialogHelpers.showAddManualStudentDialog(context);

    if (data != null && mounted) {
      final provider = context.read<AttendanceProvider>();
      final success = await provider.registerManualStudent(
        matricule: data.matricule,
        studentName: data.name,
        email: data.email,
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Student added manually')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(provider.error ?? 'Failed to add student'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _confirmRemoveStudent(dynamic record) async {
    final confirm = await DialogHelpers.showConfirmRemoveStudentDialog(
      context,
      record.studentName,
      record.matricule,
    );

    if (confirm == true && mounted) {
      final provider = context.read<AttendanceProvider>();
      final success = await provider.removeStudent(record.id as String);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Student removed' : 'Failed to remove student'),
            backgroundColor: success ? Colors.green : Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _endSession() async {
    final confirm = await DialogHelpers.showEndSessionDialog(context);
    if (confirm != true || !mounted) return;

    setState(() => _isEndingSession = true);

    try {
      await context.read<AttendanceProvider>().forceEndSession();
    } catch (e) {
      if (mounted) {
        setState(() => _isEndingSession = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to end session: $e')),
        );
        return;
      }
    }

    if (!mounted) return;
    context.go(AppRoutes.home);
  }

  Future<void> _retryServerConnection(AttendanceProvider provider) async {
    final messenger = ScaffoldMessenger.of(context);
    await provider.retryServerConnection();
    if (!mounted) return;
    if (provider.serverWarning == null) {
      setState(() => _qrRefreshKey++);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Server connected successfully'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        context.go('/');
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        appBar: AppBar(
          title: const Text('Live Session'),
          centerTitle: false,
          elevation: 0,
          backgroundColor: Theme.of(context).colorScheme.primary,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/'),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
              onPressed: () =>
                  context.read<AttendanceProvider>().refreshRecords(),
            ),
            IconButton(
              icon: const Icon(Icons.share_outlined),
              tooltip: 'Share Report',
              onPressed: _downloadAndShareServerPdf,
            ),
            IconButton(
              icon: const Icon(Icons.download_outlined),
              tooltip: 'Download PDF',
              onPressed: _downloadPdfToDevice,
            ),
            PopupMenuButton<String>(
              tooltip: 'More Actions',
              onSelected: (value) {
                switch (value) {
                  case 'signature':
                    context.go('/signature');
                    break;
                  case 'end_session':
                    _endSession();
                    break;
                  case 'add_manual':
                    _showAddManualStudentDialog();
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'signature',
                  child: Row(
                    children: [
                      Icon(Icons.draw, size: 20),
                      SizedBox(width: 8),
                      Text('Digital Signature'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'add_manual',
                  child: Row(
                    children: [
                      Icon(Icons.person_add, size: 20),
                      SizedBox(width: 8),
                      Text('Add Manual Student'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'end_session',
                  child: Row(
                    children: [
                      Icon(Icons.stop, size: 20, color: Colors.red),
                      SizedBox(width: 8),
                      Text('End Session', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        body: _isEndingSession
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Ending session…'),
                  ],
                ),
              )
            : Consumer<AttendanceProvider>(
          builder: (context, provider, _) {
            final session = provider.activeSession;
            if (session == null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.event_busy,
                      size: 64,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No Active Session',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create a new session to start taking attendance',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () => context.go('/setup'),
                      icon: const Icon(Icons.add),
                      label: const Text('Create Session'),
                    ),
                  ],
                ),
              );
            }

            final stats = provider.getStats();

            return Column(
              children: [
                // Session Header with PIN and quick stats
                SessionHeader(
                  session: session,
                  stats: stats,
                  activeWifiDevices: provider.activeWifiDevices,
                ),

                // Server warning banner with retry button
                if (provider.serverWarning != null)
                  _ServerWarningBanner(
                    message: provider.serverWarning!,
                    onRetry: () => _retryServerConnection(provider),
                  ),

                // Main Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // QR Code Section
                        QrCodeSection(
                          key: ValueKey(_qrRefreshKey),
                          sessionToken: session.sessionToken,
                        ),

                        const SizedBox(height: 16),

                        // Attendance Records
                        AttendanceRecordsSection(
                          records: provider.currentRecords,
                          onRemove: _confirmRemoveStudent,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ServerWarningBanner extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ServerWarningBanner({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.orange[800],
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.wifi_off, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: const Text('Retry', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}