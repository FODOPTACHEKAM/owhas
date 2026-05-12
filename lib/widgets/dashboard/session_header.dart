import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/session.dart';
import 'compact_stat_chip.dart';

class SessionHeader extends StatelessWidget {
  final AttendanceSession session;
  final Map<String, dynamic> stats;
  final int activeWifiDevices;

  const SessionHeader({
    super.key,
    required this.session,
    required this.stats,
    required this.activeWifiDevices,
  });

  @override
  Widget build(BuildContext context) {
    final pin = session.sessionPin;
    final endTime = session.startTime.add(Duration(minutes: session.durationMinutes));
    final timeRemaining = endTime.difference(DateTime.now());
    final isEndingSoon = timeRemaining.inMinutes <= 15 && timeRemaining.inSeconds > 0;
    final isExpired = timeRemaining.inSeconds <= 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 560;
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          color: Theme.of(context).colorScheme.primary,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                isNarrow
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildHeaderInfo(context, endTime, timeRemaining, isEndingSoon, isExpired),
                          const SizedBox(height: 14),
                          if (pin != null) Center(child: _PinBadge(pin: pin)),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildHeaderInfo(context, endTime, timeRemaining, isEndingSoon, isExpired),
                          ),
                          if (pin != null) ...[
                            const SizedBox(width: 16),
                            _PinBadge(pin: pin),
                          ],
                        ],
                      ),
                const SizedBox(height: 14),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      CompactStatChip(
                        label: 'Total',
                        value: stats['total'].toString(),
                        icon: Icons.people,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                      const SizedBox(width: 8),
                      CompactStatChip(
                        label: 'Verified',
                        value: stats['verified'].toString(),
                        icon: Icons.check_circle,
                        color: Colors.greenAccent,
                      ),
                      const SizedBox(width: 8),
                      CompactStatChip(
                        label: 'Pending',
                        value: stats['pending'].toString(),
                        icon: Icons.pending,
                        color: Colors.orangeAccent,
                      ),
                      const SizedBox(width: 8),
                      CompactStatChip(
                        label: 'Wi-Fi',
                        value: activeWifiDevices.toString(),
                        icon: Icons.wifi_tethering,
                        color: Colors.lightBlueAccent,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeaderInfo(
    BuildContext context,
    DateTime endTime,
    Duration timeRemaining,
    bool isEndingSoon,
    bool isExpired,
  ) {
    final minsLeft = timeRemaining.inMinutes;
    final Color timeColor = isExpired
        ? Colors.redAccent
        : isEndingSoon
            ? Colors.orangeAccent
            : Colors.greenAccent.shade200;

    final String timeLabel;
    if (isExpired) {
      timeLabel = 'Ended';
    } else if (minsLeft < 60) {
      timeLabel = '$minsLeft min left';
    } else {
      final h = timeRemaining.inHours;
      final m = minsLeft % 60;
      timeLabel = m > 0 ? '${h}h ${m}m left' : '${h}h left';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          session.courseName,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Theme.of(context).colorScheme.onPrimary,
            fontWeight: FontWeight.bold,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (session.courseCode != null) ...[
          const SizedBox(height: 3),
          Text(
            session.courseCode!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.primaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 10),
        Row(
          children: [
            Icon(Icons.schedule_rounded, size: 15, color: timeColor),
            const SizedBox(width: 5),
            Text(
              'Ends ${DateFormat('HH:mm').format(endTime)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onPrimary.withAlpha(200),
              ),
            ),
            const SizedBox(width: 8),
            _TimeChip(label: timeLabel, color: timeColor, warn: isEndingSoon || isExpired),
          ],
        ),
      ],
    );
  }
}

class _TimeChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool warn;

  const _TimeChip({required this.label, required this.color, required this.warn});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(38),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(110), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (warn) ...[
            Icon(Icons.warning_amber_rounded, size: 11, color: color),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _PinBadge extends StatefulWidget {
  final String pin;
  const _PinBadge({required this.pin});

  @override
  State<_PinBadge> createState() => _PinBadgeState();
}

class _PinBadgeState extends State<_PinBadge> with SingleTickerProviderStateMixin {
  bool _copied = false;
  late final AnimationController _scaleController;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      reverseDuration: const Duration(milliseconds: 200),
      lowerBound: 0.94,
      upperBound: 1.0,
      value: 1.0,
    );
    _scaleAnim = CurvedAnimation(parent: _scaleController, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  Future<void> _copy() async {
    _scaleController.reverse().then((_) => _scaleController.forward());
    await Clipboard.setData(ClipboardData(text: widget.pin));
    if (!mounted) return;
    setState(() => _copied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final onPrimary = Theme.of(context).colorScheme.onPrimary;

    return ScaleTransition(
      scale: _scaleAnim,
      child: GestureDetector(
        onTap: _copy,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          width: 152,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: _copied ? const Color(0xFF2E7D32) : onPrimary,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(50),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Label row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.lock_rounded,
                    size: 12,
                    color: _copied ? Colors.white.withAlpha(180) : primary.withAlpha(160),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'SESSION PIN',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: _copied ? Colors.white.withAlpha(180) : primary.withAlpha(160),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // PIN digits
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  widget.pin,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                    color: _copied ? Colors.white : primary,
                    height: 1.0,
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Divider
              Container(
                height: 1,
                color: _copied
                    ? Colors.white.withAlpha(40)
                    : primary.withAlpha(30),
              ),

              const SizedBox(height: 8),

              // Copy feedback row
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, anim) =>
                    FadeTransition(opacity: anim, child: child),
                child: _copied
                    ? Row(
                        key: const ValueKey('copied'),
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_rounded, size: 13, color: Colors.white.withAlpha(210)),
                          const SizedBox(width: 5),
                          Text(
                            'Copied!',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Colors.white.withAlpha(210),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      )
                    : Row(
                        key: const ValueKey('tap'),
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.copy_rounded, size: 12, color: primary.withAlpha(130)),
                          const SizedBox(width: 5),
                          Text(
                            'Tap to copy',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: primary.withAlpha(130),
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
