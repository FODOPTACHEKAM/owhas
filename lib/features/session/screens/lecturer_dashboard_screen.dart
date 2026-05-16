import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/route_constants.dart';
import '../../../core/extensions/context_extensions.dart';
import '../notifiers/session_state_notifier.dart';
import '../../attendance/notifiers/attendance_record_notifier.dart';
import '../../reports/notifiers/report_notifier.dart';
import '../../../utils/dialog_helpers.dart';
import '../../../widgets/dashboard/session_header.dart';
import '../../../widgets/dashboard/qr_code_section.dart';
import '../../../widgets/dashboard/attendance_records_section.dart';
import '../widgets/dashboard_app_bar.dart';
import '../widgets/dashboard_body.dart';

/// Live-session dashboard — reads [SessionStateNotifier], [AttendanceRecordNotifier],
/// and [ReportNotifier]; [AttendanceProvider] is no longer used here.
class LecturerDashboardScreen extends StatefulWidget {
  const LecturerDashboardScreen({super.key});

  @override
  State<LecturerDashboardScreen> createState() => _LecturerDashboardScreenState();
}

class _LecturerDashboardScreenState extends State<LecturerDashboardScreen> {
  bool   _isEndingSession = false;
  int    _qrRefreshKey   = 0;
  Timer? _refreshTimer;

  // ── Lifecycle ─────────────────────────────────────────────────────────────────

  @override
  void initState() { super.initState(); _startAutoRefresh(); }

  @override
  void dispose() { _refreshTimer?.cancel(); super.dispose(); }

  // ── Auto-refresh ──────────────────────────────────────────────────────────────

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!mounted) { _refreshTimer?.cancel(); return; }

      final sn      = context.read<SessionStateNotifier>();
      final rn      = context.read<AttendanceRecordNotifier>();
      final session = sn.activeSession;

      if (session != null && session.endTime != null &&
          DateTime.now().isAfter(session.endTime!)) {
        _refreshTimer?.cancel();
        await sn.forceEndSession();
        rn.clear();
        if (!mounted) return;
        context.showInfo('Session ended — time limit reached');
        context.navigateTo(RouteConstants.home);
        return;
      }

      if (session != null) {
        await Future.wait([
          rn.refreshRecords(session),
          rn.refreshWifiDeviceCount(),
        ]);
      }
    });
  }

  // ── Actions ───────────────────────────────────────────────────────────────────

  Future<void> _shareReport() async {
    final sn      = context.read<SessionStateNotifier>();
    final rn      = context.read<AttendanceRecordNotifier>();
    final report  = context.read<ReportNotifier>();
    final session = sn.activeSession;
    if (session == null) return;
    final success = await report.generateAndSharePDFReport(
      session:            session,
      records:            rn.records,
      previousAttendance: sn.previousAttendance,
      sessionNumber:      sn.sessionNumber,
    );
    if (!mounted) return;
    success
        ? context.showSuccess('PDF shared')
        : context.showError(report.error ?? 'Failed to share PDF');
  }

  Future<void> _downloadPdfToDevice() async {
    final sn      = context.read<SessionStateNotifier>();
    final rn      = context.read<AttendanceRecordNotifier>();
    final report  = context.read<ReportNotifier>();
    final session = sn.activeSession;
    if (session == null) return;
    final filePath = await report.downloadPDFReport(
      session:            session,
      records:            rn.records,
      previousAttendance: sn.previousAttendance,
      sessionNumber:      sn.sessionNumber,
    );
    if (!mounted) return;
    filePath != null
        ? context.showSuccess('PDF saved to: $filePath')
        : context.showError(report.error ?? 'Failed to download PDF');
  }

  Future<void> _showAddManualStudentDialog() async {
    final data = await DialogHelpers.showAddManualStudentDialog(context);
    if (data == null || !mounted) return;
    final sn      = context.read<SessionStateNotifier>();
    final rn      = context.read<AttendanceRecordNotifier>();
    final session = sn.activeSession;
    if (session == null) return;
    final success = await rn.registerManualStudent(
      session: session, matricule: data.matricule,
      studentName: data.name, email: data.email,
    );
    if (!mounted) return;
    success
        ? context.showSuccess('Student added manually')
        : context.showError(rn.error ?? 'Failed to add student');
  }

  Future<void> _confirmRemoveStudent(dynamic record) async {
    final confirm = await DialogHelpers.showConfirmRemoveStudentDialog(
      context, record.studentName as String, record.matricule as String,
    );
    if (confirm != true || !mounted) return;
    final sn      = context.read<SessionStateNotifier>();
    final session = sn.activeSession;
    if (session == null) return;
    final success = await context.read<AttendanceRecordNotifier>()
        .removeStudent(record.id as String, session);
    if (!mounted) return;
    success
        ? context.showSuccess('Student removed')
        : context.showError('Failed to remove student');
  }

  Future<void> _endSession() async {
    final confirm = await DialogHelpers.showEndSessionDialog(context);
    if (confirm != true || !mounted) return;
    setState(() => _isEndingSession = true);
    try {
      await context.read<SessionStateNotifier>().forceEndSession();
      if (mounted) context.read<AttendanceRecordNotifier>().clear();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isEndingSession = false);
      context.showError('Failed to end session: $e');
      return;
    }
    if (!mounted) return;
    context.navigateTo(RouteConstants.home);
  }

  Future<void> _retryServerConnection(SessionStateNotifier sn) async {
    final messenger = ScaffoldMessenger.of(context);
    await sn.retryServerConnection();
    if (!mounted) return;
    if (sn.serverWarning == null) {
      setState(() => _qrRefreshKey++);
      messenger.showSnackBar(const SnackBar(
        content:         Text('Server connected successfully'),
        backgroundColor: Colors.green,
      ));
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final sn      = context.watch<SessionStateNotifier>();
    final rn      = context.watch<AttendanceRecordNotifier>();
    final session = sn.activeSession;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.navigateTo(RouteConstants.home);
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        appBar: DashboardAppBar(
          onBack:        () => context.navigateTo(RouteConstants.home),
          onRefresh:     () { if (session != null) rn.refreshRecords(session); },
          onShareReport: _shareReport,
          onDownloadPdf: _downloadPdfToDevice,
          onAddManual:   _showAddManualStudentDialog,
          onSignature:   () => context.navigateTo(RouteConstants.signature),
          onEndSession:  _endSession,
        ),
        body: _isEndingSession
            ? const SessionEndingSpinner()
            : session == null
                ? NoActiveSessionPlaceholder(
                    onCreateSession: () => context.navigateTo(RouteConstants.setup),
                  )
                : Column(
                    children: [
                      SessionHeader(
                        session:          session,
                        stats:            rn.getStats(),
                        activeWifiDevices: rn.activeWifiDevices,
                      ),
                      if (sn.serverWarning != null)
                        ServerWarningBanner(
                          message: sn.serverWarning!,
                          onRetry: () => _retryServerConnection(sn),
                        ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              QrCodeSection(
                                key:          ValueKey(_qrRefreshKey),
                                sessionToken: session.sessionToken,
                              ),
                              const SizedBox(height: 16),
                              AttendanceRecordsSection(
                                records:  rn.records,
                                onRemove: _confirmRemoveStudent,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}
