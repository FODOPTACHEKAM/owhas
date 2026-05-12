import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

// Note: Ensure these paths match your project structure
import '../providers/attendance_provider.dart';
import '../theme.dart';

// ─── Animated Radar Painter ───────────────────────────────────────────────────

class _RadarPainter extends CustomPainter {
  final double progress;
  _RadarPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    // Positioning the origin near the bottom-center of the 90x90 box
    final arcOrigin = Offset(size.width / 2, size.height * 0.75);

    // 1. Pulsing "Signal" rings
    final pulsePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (int i = 0; i < 3; i++) {
      final ringProgress = (progress + i / 3) % 1.0;
      final radius = 4.0 + ringProgress * 45;
      final opacity = (1.0 - ringProgress) * 0.3;
      
      canvas.drawCircle(
        arcOrigin,
        radius,
        pulsePaint..color = Colors.white.withValues(alpha: opacity),
      );
    }

    // 2. Static Signal Arcs (Wifi Shape)
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    // Flutter angles: 0 is right (3 o'clock), π/2 is bottom, π is left, 3π/2 is top.
    // To center a 90° arc at the top, we start at 225° (-0.75π) and sweep 90° (0.5π).
    const double sweepAngle = math.pi * 0.5; 
    const double startAngle = -math.pi * 0.75; 

    final radii = [18.0, 32.0, 46.0];
    final opacities = [0.4, 0.7, 1.0];

    for (int i = 0; i < radii.length; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: arcOrigin, radius: radii[i]),
        startAngle,
        sweepAngle,
        false,
        arcPaint..color = Colors.white.withValues(alpha: opacities[i]),
      );
    }

    // 3. Center dot (The "Hotspot" source)
    canvas.drawCircle(arcOrigin, 5.0, Paint()..color = Colors.white);
    canvas.drawCircle(
      arcOrigin,
      2.5,
      Paint()..color = const Color(0xFF1A3A6B).withValues(alpha: 0.4),
    );
  }

  @override
  bool shouldRepaint(_RadarPainter old) => old.progress != progress;
}

// ─── Animated Radar Icon Widget ───────────────────────────────────────────────

class _AnimatedRadarIcon extends StatefulWidget {
  const _AnimatedRadarIcon();

  @override
  State<_AnimatedRadarIcon> createState() => _AnimatedRadarIconState();
}

class _AnimatedRadarIconState extends State<_AnimatedRadarIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) => CustomPaint(
        size: const Size(90, 90),
        painter: _RadarPainter(_controller.value),
      ),
    );
  }
}

// ─── Home Page ────────────────────────────────────────────────────────────────

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  late AnimationController _entranceController;
  late Animation<double> _headerAnim;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _headerAnim = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    );
    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  void _handleLecturerTap(BuildContext context) {
    final provider = context.read<AttendanceProvider>();
    final hasActiveSession = provider.activeSession != null;

    if (!hasActiveSession) {
      context.go('/setup');
      return;
    }

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: const Text('Lecturer Options'),
        content: const Text(
          'You already have an active session running. What would you like to do?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.go('/dashboard');
            },
            child: const Text('Go to Active Session'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.go('/setup');
            },
            child: const Text('Create New Session'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFF4FB),
      body: Stack(
        children: [
          // Background ambient blobs
          Positioned(
            top: -90,
            right: -90,
            child: _AmbientBlob(size: 320, color: const Color(0xFF4A90D9).withValues(alpha: 0.15)),
          ),
          Positioned(
            bottom: 80,
            left: -70,
            child: _AmbientBlob(size: 220, color: const Color(0xFF1A3A6B).withValues(alpha: 0.08)),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: AppSpacing.paddingXl,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Column(
                    children: [
                      // Header Section
                      AnimatedBuilder(
                        animation: _headerAnim,
                        builder: (_, child) => Opacity(
                          opacity: _headerAnim.value,
                          child: Transform.translate(
                            offset: Offset(0, -24 * (1 - _headerAnim.value)),
                            child: child,
                          ),
                        ),
                        child: Column(
                          children: [
                            const _FloatingIconBox(child: _AnimatedRadarIcon()),
                            const SizedBox(height: AppSpacing.xl),
                            Text(
                              'Offline Hotspot Attendance',
                              style: context.textStyles.displaySmall?.bold,
                              textAlign: TextAlign.center,
                            ),
                           const SizedBox(height: AppSpacing.sm),
                              Wrap(
                              alignment: WrapAlignment.center, // Centers items horizontally
                              spacing: 8.0,                   // Horizontal space between badges
                              runSpacing: 8.0,                // Vertical space between lines when wrapped
                              children: const [
                              _BadgePill(
                              icon: Icons.wifi_off_rounded,
                             label: 'Offline-first',
                             color: Color(0xFF1A3A6B),
                             ),
                              _BadgePill(
                             icon: Icons.verified_user_rounded,
                             label: 'Secure',
                             color: Color(0xFF27AE60),
                            ),
                            _BadgePill(
                            icon: Icons.backup_rounded,
                            label: 'Cloud-based',
                               color: Color(0xFF27AE60),
                              ),
                             ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: AppSpacing.xxl),

                      // Role Selection Divider
                      const _SectionHeader(label: 'SELECT YOUR ROLE'),
                      const SizedBox(height: AppSpacing.md),

                      // Role Cards
                      Consumer<AttendanceProvider>(
                        builder: (context, provider, _) {
                          final hasSession = provider.activeSession != null;
                          return _RoleCard(
                            title: 'Lecturer',
                            subtitle: hasSession
                                ? 'Active session: ${provider.activeSession!.courseName}'
                                : 'Create and manage attendance sessions',
                            icon: Icons.school_rounded,
                            accentColor: const Color(0xFF1A3A6B),
                            onTap: () => _handleLecturerTap(context),
                            entranceDelay: 180,
                          );
                        },
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _RoleCard(
                        title: 'Student',
                        subtitle: 'Register attendance for active sessions',
                        icon: Icons.person_rounded,
                        accentColor: const Color(0xFF2E6BB8),
                        onTap: () => context.go('/register'),
                        entranceDelay: 320,
                      ),

                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        'Smart attendance · Powered by Wi-Fi hotspot',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                        ),
                      ),
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
}

// ─── Supporting UI Components ─────────────────────────────────────────────────

class _AmbientBlob extends StatelessWidget {
  final double size;
  final Color color;
  const _AmbientBlob({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, Colors.transparent]),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Divider(
            thickness: 0.5,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
          ),
        ),
      ],
    );
  }
}

class _FloatingIconBox extends StatefulWidget {
  final Widget child;
  const _FloatingIconBox({required this.child});

  @override
  State<_FloatingIconBox> createState() => _FloatingIconBoxState();
}

class _FloatingIconBoxState extends State<_FloatingIconBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _float;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);
    _float = Tween<double>(begin: 0, end: -8).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _float,
      builder: (_, child) => Transform.translate(
        offset: Offset(0, _float.value),
        child: child,
      ),
      child: Container(
        width: 110,
        height: 110,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1A3A6B), Color(0xFF2E6BB8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1A3A6B).withValues(alpha: 0.35),
              blurRadius: 32,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: widget.child,
      ),
    );
  }
}

class _BadgePill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _BadgePill({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color.withValues(alpha: 0.8)),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;
  final int entranceDelay;

  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.onTap,
    this.entranceDelay = 0,
  });

  @override
  State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _anim;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _anim = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    Future.delayed(Duration(milliseconds: widget.entranceDelay), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, child) => Opacity(
        opacity: _anim.value,
        child: Transform.translate(
          offset: Offset(0, 28 * (1 - _anim.value)),
          child: child,
        ),
      ),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 100),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              boxShadow: [
                BoxShadow(
                  color: widget.accentColor.withValues(alpha: 0.10),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: AppSpacing.paddingLg,
              child: Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: widget.accentColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Icon(widget.icon, color: widget.accentColor, size: 28),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.title, style: context.textStyles.titleLarge?.semiBold),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          widget.subtitle,
                          style: context.textStyles.bodyMedium?.withColor(
                            Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_rounded, size: 18, color: widget.accentColor),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}