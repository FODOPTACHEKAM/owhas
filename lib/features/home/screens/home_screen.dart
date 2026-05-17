import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/route_constants.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../session/notifiers/session_state_notifier.dart';
import '../../../theme.dart';
import '../widgets/home_animations.dart';
import '../widgets/home_ui_components.dart';
import '../widgets/role_card.dart';

/// Refactored home screen — build() ≤ 60 lines.
///
/// The existing [HomePage] in `lib/pages/` is untouched until routing
/// is migrated in a later phase.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _entranceCtrl;
  late Animation<double>   _headerAnim;

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 700),
    );
    _headerAnim = CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOutCubic);
    _entranceCtrl.forward();
  }

  @override
  void dispose() { _entranceCtrl.dispose(); super.dispose(); }

  // ── Actions ───────────────────────────────────────────────────────────────────

  void _handleLecturerTap(BuildContext ctx) {
    final hasSession = ctx.read<SessionStateNotifier>().hasActiveSession;
    if (!hasSession) { ctx.navigateTo(RouteConstants.setup); return; }

    showDialog<void>(
      context: ctx,
      builder: (dlg) => AlertDialog(
        shape:   RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title:   const Text('Lecturer Options'),
        content: const Text('You already have an active session running. What would you like to do?'),
        actions: [
          TextButton(
            onPressed: () { Navigator.pop(dlg); ctx.navigateTo(RouteConstants.dashboard); },
            child: const Text('Go to Active Session'),
          ),
          FilledButton(
            onPressed: () { Navigator.pop(dlg); ctx.navigateTo(RouteConstants.setup); },
            child: const Text('Create New Session'),
          ),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFF4FB),
      body: Stack(
        children: [
          Positioned(top: -90, right: -90,
              child: AmbientBlob(size: 320, color: const Color(0xFF4A90D9).withValues(alpha: 0.15))),
          Positioned(bottom: 80, left: -70,
              child: AmbientBlob(size: 220, color: const Color(0xFF1A3A6B).withValues(alpha: 0.08))),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: AppSpacing.paddingXl,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Column(
                    children: [
                      _buildHeader(),
                      const SizedBox(height: AppSpacing.xxl),
                      const SectionHeader(label: 'SELECT YOUR ROLE'),
                      const SizedBox(height: AppSpacing.md),
                      _buildLecturerCard(),
                      const SizedBox(height: AppSpacing.xs),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => context.pushRoute(RouteConstants.catalogue),
                          icon:  const Icon(Icons.menu_book_outlined, size: 15),
                          label: const Text('View Course Catalogue'),
                          style: TextButton.styleFrom(foregroundColor: const Color(0xFF1A3A6B)),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      RoleCard(
                        title: 'Student', subtitle: 'Register attendance for active sessions',
                        icon: Icons.person_rounded, accentColor: const Color(0xFF2E6BB8),
                        onTap: () => context.navigateTo(RouteConstants.register),
                        entranceDelay: 320,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Text('Smart attendance · Powered by Wi-Fi hotspot',
                          style: TextStyle(fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3))),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Private builders ──────────────────────────────────────────────────────────

  Widget _buildHeader() => AnimatedBuilder(
    animation: _headerAnim,
    builder: (_, child) => Opacity(
      opacity: _headerAnim.value,
      child:   Transform.translate(offset: Offset(0, -24 * (1 - _headerAnim.value)), child: child),
    ),
    child: Column(
      children: [
        const FloatingIconBox(child: AnimatedRadarIcon()),
        const SizedBox(height: AppSpacing.xl),
        Text('Offline Hotspot Attendance',
            style: context.textStyles.displaySmall?.bold, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.sm),
        const Wrap(
          alignment: WrapAlignment.center, spacing: 8, runSpacing: 8,
          children: [
            BadgePill(icon: Icons.wifi_off_rounded,    label: 'Offline-first', color: Color(0xFF1A3A6B)),
            BadgePill(icon: Icons.verified_user_rounded, label: 'Secure',       color: Color(0xFF27AE60)),
            BadgePill(icon: Icons.backup_rounded,       label: 'Cloud-based',   color: Color(0xFF27AE60)),
          ],
        ),
      ],
    ),
  );

  Widget _buildLecturerCard() => Consumer<SessionStateNotifier>(
    builder: (ctx, sn, _) {
      final hasSession = sn.hasActiveSession;
      return RoleCard(
        title:       'Lecturer',
        subtitle:    hasSession
            ? 'Active session: ${sn.activeSession!.courseName}'
            : 'Create and manage attendance sessions',
        icon:        Icons.school_rounded,
        accentColor: const Color(0xFF1A3A6B),
        onTap:       () => _handleLecturerTap(ctx),
        entranceDelay: 180,
      );
    },
  );
}
