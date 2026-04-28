import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../providers/attendance_provider.dart';
import '../services/signature_service.dart';
import '../theme.dart';

class LecturerDashboardPage extends StatefulWidget {
  const LecturerDashboardPage({super.key});

  @override
  State<LecturerDashboardPage> createState() => _LecturerDashboardPageState();
}

class _LecturerDashboardPageState extends State<LecturerDashboardPage> {
  Offset _dragOffset = const Offset(0, 0);
  String _searchQuery = '';

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

  Future<void> _showAddManualStudentDialog() async {
    final nameController = TextEditingController();
    final matriculeController = TextEditingController();
    final emailController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Student Manually'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'For students with discharged phones or no Wi-Fi access. They will appear in the report with no status.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Student Name *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: matriculeController,
                decoration: const InputDecoration(
                  labelText: 'Matricule *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.badge),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email (optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (nameController.text.trim().isEmpty ||
                  matriculeController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Name and Matricule are required')),
                );
                return;
              }
              Navigator.pop(context, true);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      final provider = context.read<AttendanceProvider>();
      final success = await provider.registerManualStudent(
        matricule: matriculeController.text.trim(),
        studentName: nameController.text.trim(),
        email: emailController.text.trim().isEmpty
            ? null
            : emailController.text.trim(),
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

    nameController.dispose();
    matriculeController.dispose();
    emailController.dispose();
  }

  Future<void> _confirmRemoveStudent(dynamic record) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Student?'),
        content: Text('Are you sure you want to remove ${record.studentName} (${record.matricule}) from this session?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
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
              icon: const Icon(Icons.draw),
              tooltip: 'Digital Signature',
              onPressed: () => context.go('/signature'),
            ),
            IconButton(
              icon: const Icon(Icons.share),
              tooltip: 'Share PDF Report',
              onPressed: _downloadAndShareServerPdf,
            ),
            IconButton(
              icon: const Icon(Icons.stop),
              onPressed: _endSession,
            ),
          ],
        ),
        body: Stack(
          children: [
            Consumer<AttendanceProvider>(
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
                              value: () {
                                final total = stats['total'] ?? 0;
                                final verified = stats['verified'] ?? 0;
                                if (total == 0) return '0%';
                                return '${((verified / total) * 100).toStringAsFixed(0)}%';
                              }(),
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
                              TextField(
                                onChanged: (value) {
                                  setState(() {
                                    _searchQuery = value.trim().toLowerCase();
                                  });
                                },
                                decoration: InputDecoration(
                                  hintText: 'Search by name or matricule...',
                                  prefixIcon: const Icon(Icons.search),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(AppRadius.sm),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Builder(
                                builder: (context) {
                                  final filteredRecords = provider.currentRecords.where((r) {
                                    if (_searchQuery.isEmpty) return true;
                                    return r.studentName.toLowerCase().contains(_searchQuery) ||
                                        r.matricule.toLowerCase().contains(_searchQuery);
                                  }).toList();

                                  if (filteredRecords.isEmpty) {
                                    return const Padding(
                                      padding: AppSpacing.paddingLg,
                                      child: Center(
                                        child: Text('No students found'),
                                      ),
                                    );
                                  }

                                  return ListView.separated(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: filteredRecords.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: AppSpacing.sm),
                                    itemBuilder: (context, index) {
                                      final record = filteredRecords[index];
                                      return _AttendanceRecordTile(
                                        record: record,
                                        onRemove: () => _confirmRemoveStudent(record),
                                      );
                                    },
                                  );
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
            LayoutBuilder(
              builder: (context, constraints) {
                final maxX = constraints.maxWidth - 72; // FAB width + padding
                final maxY = constraints.maxHeight - 72;
                return Positioned(
                  left: (16 + _dragOffset.dx).clamp(0.0, maxX),
                  top: (constraints.maxHeight - 72 - _dragOffset.dy).clamp(0.0, maxY),
                  child: GestureDetector(
                    onPanUpdate: (details) {
                      setState(() {
                        _dragOffset += Offset(details.delta.dx, -details.delta.dy);
                      });
                    },
                    child: FloatingActionButton.small(
                      onPressed: _showAddManualStudentDialog,
                      tooltip: 'Add Student',
                      child: const Icon(Icons.person_add),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionInfoCard extends StatelessWidget {
  final dynamic session;

  const _SessionInfoCard({required this.session});

  // Base URL for the permanent poster QR — never changes
  static const String _baseQrUrl = 'http://192.168.137.1:5501/public/hotspot.html';

  @override
  Widget build(BuildContext context) {
    final pin = session.sessionPin as String?;
    final token = session.sessionToken as String?;
    final tokenQrUrl = token != null ? '$_baseQrUrl?s=$token' : null;

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
                      if (session.courseCode != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          session.courseCode!,
                          style: context.textStyles.bodyMedium?.withColor(
                            Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
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
                      FutureBuilder<String?>(
                        future: SignatureService.loadLecturerName(),
                        builder: (context, snapshot) {
                          if (snapshot.hasData && snapshot.data != null) {
                            return Padding(
                              padding: const EdgeInsets.only(top: AppSpacing.xs),
                              child: Text(
                                'Lecturer: ${snapshot.data}',
                                style: context.textStyles.bodySmall?.withColor(
                                  Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ],
                  ),
                ),
                // Token QR (ad-hoc fallback) — smaller, optional
                if (tokenQrUrl != null)
                  Container(
                    padding: AppSpacing.paddingSm,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: QrImageView(
                      data: tokenQrUrl,
                      size: 80,
                    ),
                  ),
              ],
            ),
            const Divider(height: AppSpacing.lg),

            // ─── PIN DISPLAY (Large & Prominent) ───
            if (pin != null)
              Container(
                width: double.infinity,
                padding: AppSpacing.paddingLg,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Column(
                  children: [
                    Text(
                      'SESSION PIN',
                      style: context.textStyles.labelLarge?.withColor(
                        Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      pin,
                      style: context.textStyles.displayLarge?.bold.withColor(
                        Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Write this on the board',
                      style: context.textStyles.bodySmall?.withColor(
                        Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),

            if (pin != null) const SizedBox(height: AppSpacing.md),

            // ─── STATIC POSTER QR ───
            Row(
              children: [
                Container(
                  padding: AppSpacing.paddingSm,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: QrImageView(
                    data: _baseQrUrl,
                    size: 80,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Permanent Poster QR',
                        style: context.textStyles.titleSmall?.semiBold,
                      ),
                      Text(
                        'Students scan this once and bookmark the page. The PIN changes each session.',
                        style: context.textStyles.bodySmall?.withColor(
                          Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                const Icon(Icons.link, size: 16),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    _baseQrUrl,
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
  final VoidCallback? onRemove;
  const _AttendanceRecordTile({required this.record, this.onRemove});

  @override
  Widget build(BuildContext context) {
    final isVerified = record.isVerified;
    final isManual = record.isManual as bool? ?? false;

    final statusColor = isManual
        ? Colors.grey
        : isVerified
            ? Colors.green
            : Colors.orange;

    final statusIcon = isManual
        ? Icons.person_outline
        : isVerified
            ? Icons.check_circle
            : Icons.pending;

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
            statusIcon,
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
                if (isManual)
                  Text(
                    'Manual entry',
                    style: context.textStyles.labelSmall?.withColor(
                      Colors.grey,
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
          if (onRemove != null) ...[
            const SizedBox(width: AppSpacing.sm),
            IconButton(
              icon: const Icon(Icons.person_remove, color: Colors.red),
              tooltip: 'Remove student',
              onPressed: onRemove,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ],
      ),
    );
  }
}

