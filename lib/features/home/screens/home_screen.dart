import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/route_constants.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../session/notifiers/session_state_notifier.dart';
import '../../../theme.dart';
import '../widgets/home_animations.dart';
import '../widgets/home_ui_components.dart';
import '../widgets/role_card.dart';

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
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Scale relative to a 780 pt reference height.
                // Clamped: never shrinks below 70 % or grows past 100 %.
                final s = (constraints.maxHeight / 780.0).clamp(0.70, 1.0);
                final iconSize  = 110.0 * s;
                final titleSize = (34.0 * s).clamp(22.0, 34.0);
                final hPad      = 24.0 * s;

                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 500),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: hPad),
                      child: Column(
                        children: [
                          const Spacer(flex: 3),

                          // ── Header ──────────────────────────────────────
                          _buildHeader(iconSize, titleSize, s),

                          const Spacer(flex: 2),

                          // ── Server status ────────────────────────────────
                          const SectionHeader(label: 'SERVER STATUS'),
                          SizedBox(height: 8 * s),
                          const ServerStatusBanner(),

                          const Spacer(flex: 3),

                          // ── Role selection ───────────────────────────────
                          const SectionHeader(label: 'SELECT YOUR ROLE'),
                          SizedBox(height: 10 * s),
                          _buildLecturerCard(),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () => context.pushRoute(RouteConstants.catalogue),
                              icon:  const Icon(Icons.menu_book_outlined, size: 13),
                              label: const Text('View Course Catalogue',
                                  style: TextStyle(fontSize: 12)),
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF1A3A6B),
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              ),
                            ),
                          ),
                          SizedBox(height: 6 * s),
                          RoleCard(
                            title: 'Student',
                            subtitle: 'Register attendance for active sessions',
                            icon: Icons.person_rounded,
                            accentColor: const Color(0xFF2E6BB8),
                            onTap: () => context.navigateTo(RouteConstants.register),
                            entranceDelay: 320,
                          ),

                          const Spacer(flex: 3),

                          // ── Footer ───────────────────────────────────────
                          Text('Smart attendance · Powered by Wi-Fi hotspot',
                              style: TextStyle(fontSize: 11,
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.28))),
                          const Spacer(flex: 1),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Private builders ──────────────────────────────────────────────────────────

  Widget _buildHeader(double iconSize, double titleSize, double s) =>
      AnimatedBuilder(
        animation: _headerAnim,
        builder: (_, child) => Opacity(
          opacity: _headerAnim.value,
          child: Transform.translate(
              offset: Offset(0, -24 * (1 - _headerAnim.value)), child: child),
        ),
        child: Column(
          children: [
            // FittedBox scales the fixed FloatingIconBox to our computed iconSize
            SizedBox(
              width: iconSize, height: iconSize,
              child: const FittedBox(
                fit: BoxFit.contain,
                child: FloatingIconBox(child: AnimatedRadarIcon()),
              ),
            ),
            SizedBox(height: 14 * s),
            Text('Offline Hotspot Attendance',
                style: TextStyle(
                  fontSize: titleSize,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                textAlign: TextAlign.center),
            SizedBox(height: 8 * s),
            const Wrap(
              alignment: WrapAlignment.center, spacing: 6, runSpacing: 6,
              children: [
                BadgePill(icon: Icons.wifi_off_rounded,      label: 'Offline-first', color: Color(0xFF1A3A6B)),
                BadgePill(icon: Icons.verified_user_rounded, label: 'Secure',        color: Color(0xFF27AE60)),
                BadgePill(icon: Icons.backup_rounded,        label: 'Cloud-based',   color: Color(0xFF27AE60)),
              ],
            ),
          ],
        ),
      );

  Widget _buildLecturerCard() => Consumer<SessionStateNotifier>(
    builder: (ctx, sn, _) => RoleCard(
      title:       'Lecturer',
      subtitle:    sn.hasActiveSession
          ? 'Active session: ${sn.activeSession!.courseName}'
          : 'Create and manage attendance sessions',
      icon:        Icons.school_rounded,
      accentColor: const Color(0xFF1A3A6B),
      onTap:       () => _handleLecturerTap(ctx),
      entranceDelay: 180,
    ),
  );
}
