import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../providers/attendance_provider.dart';
import '../theme.dart';

class LecturerDashboardPage extends StatefulWidget {
  const LecturerDashboardPage({super.key});

  @override
  State<LecturerDashboardPage> createState() => _LecturerDashboardPageState();
}

class _LecturerDashboardPageState extends State<LecturerDashboardPage> {
  @override
  void initState() {
    super.initState();
    _startAutoRefresh();
  }

  void _startAutoRefresh() {
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        context.read<AttendanceProvider>().refreshRecords();
        context.read<AttendanceProvider>().refreshWifiDeviceCount();
        _startAutoRefresh();
      }
    });
  }

  Future<void> _generatePDFReport() async {
    final provider = context.read<AttendanceProvider>();
    final success = await provider.generateAndSharePDFReport();
    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF generated and shared')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.error ?? 'Failed to generate PDF'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _downloadAndShareServerPdf() async {
    final provider = context.read<AttendanceProvider>();
    final success = await provider.downloadAndShareServerPdf();
    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF downloaded and shared')),
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

  Future<void> _endSession() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Session?'),
        content: const Text(
          'This will close the session and generate the attendance report. Students will no longer be able to register.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('End Session'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final provider = context.read<AttendanceProvider>();
    final filePath = await provider.endSessionAndGenerateReport();

    if (mounted) {
      if (filePath != null) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Session Ended'),
            content: Text('Report saved to:\n$filePath'),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.go('/');
                },
                child: const Text('Done'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.error ?? 'Failed to generate report'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
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
        appBar: AppBar(
          title: const Text('Live Session'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/'),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () =>
                  context.read<AttendanceProvider>().refreshRecords(),
            ),
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              tooltip: 'Generate PDF Report',
              onPressed: _generatePDFReport,
            ),
            IconButton(
              icon: const Icon(Icons.share),
              tooltip: 'Download & Share Server PDF',
              onPressed: _downloadAndShareServerPdf,
            ),
            IconButton(
              icon: const Icon(Icons.stop),
              onPressed: _endSession,
            ),
          ],
        ),
        body: Consumer<AttendanceProvider>(
          builder: (context, provider, _) {
            final session = provider.activeSession;
            if (session == null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('No active session'),
                    const SizedBox(height: AppSpacing.md),
                    FilledButton(
                      onPressed: () => context.go('/setup'),
                      child: const Text('Create Session'),
                    ),
                  ],
                ),
              );
            }

            final stats = provider.getStats();

            return SingleChildScrollView(
              padding: AppSpacing.paddingMd,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SessionInfoCard(session: session),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          title: 'Total',
                          value: stats['total'].toString(),
                          icon: Icons.people,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _StatCard(
                          title: 'Verified',
                          value: stats['verified'].toString(),
                          icon: Icons.check_circle,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _StatCard(
                          title: 'Pending',
                          value: stats['pending'].toString(),
                          icon: Icons.pending,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          title: 'Wi-Fi Devices',
                          value: provider.activeWifiDevices.toString(),
                          icon: Icons.wifi_tethering,
                          color: Colors.blueAccent,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _StatCard(
                          title: 'Coverage',
                          value:
                              '${provider.currentRecords.isEmpty ? 0 : ((provider.activeWifiDevices / provider.currentRecords.length) * 100).toStringAsFixed(0)}%',
                          icon: Icons.signal_wifi_statusbar_4_bar,
                          color: Colors.teal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Card(
                    child: Padding(
                      padding: AppSpacing.paddingMd,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Real-Time Attendance Heatmap',
                            style: context.textStyles.titleLarge?.semiBold,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          if (provider.currentRecords.isEmpty)
                            const Padding(
                              padding: AppSpacing.paddingLg,
                              child: Center(
                                child: Text('No students registered yet'),
                              ),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: provider.currentRecords.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: AppSpacing.sm),
                              itemBuilder: (context, index) {
                                final record = provider.currentRecords[index];
                                return _AttendanceRecordTile(record: record);
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SessionInfoCard extends StatelessWidget {
  final dynamic session;

  const _SessionInfoCard({required this.session});

  // IMPORTANT: This URL must match your Windows Mobile Hotspot IP.
  // From ipconfig, your hotspot adapter is "Connexion au réseau local* 10"
  // with IPv4 Address: 192.168.137.1
  static const String _qrUrl = 'http://192.168.137.1:5501/public/hotspot.html';

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: AppSpacing.paddingMd,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.courseName,
                        style: context.textStyles.headlineSmall?.bold,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Started: ${DateFormat('HH:mm').format(session.startTime)}',
                        style: context.textStyles.bodyMedium?.withColor(
                          Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Req. connection: ${session.requiredConnectionMinutes} min',
                        style: context.textStyles.bodySmall?.withColor(
                          Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: AppSpacing.paddingSm,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: QrImageView(
                    data: _qrUrl,
                    size: 100,
                  ),
                ),
              ],
            ),
            const Divider(height: AppSpacing.lg),
            Row(
              children: [
                const Icon(Icons.link, size: 16),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    _qrUrl,
                    style: context.textStyles.bodySmall?.withColor(
                      Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: AppSpacing.paddingMd,
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: AppSpacing.xs),
            Text(
              value,
              style: context.textStyles.headlineMedium?.bold.withColor(color),
            ),
            Text(
              title,
              style: context.textStyles.labelSmall?.withColor(
                Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttendanceRecordTile extends StatelessWidget {
  final dynamic record;
  const _AttendanceRecordTile({required this.record});

  @override
  Widget build(BuildContext context) {
    final isVerified = record.isVerified;
    final statusColor = isVerified ? Colors.green : Colors.orange;

    return Container(
      padding: AppSpacing.paddingSm,
      decoration: BoxDecoration(
        color: statusColor.withAlpha(25),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: statusColor.withAlpha(76)),
      ),
      child: Row(
        children: [
          Icon(
            isVerified ? Icons.check_circle : Icons.pending,
            color: statusColor,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.studentName,
                  style: context.textStyles.bodyMedium?.semiBold,
                ),
                Text(
                  'Matricule: ${record.matricule}',
                  style: context.textStyles.bodySmall?.withColor(
                    Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${record.connectionDurationMinutes} min',
                style: context.textStyles.labelMedium?.semiBold,
              ),
              Text(
                DateFormat('HH:mm').format(record.joinedAt),
                style: context.textStyles.labelSmall?.withColor(
                  Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
