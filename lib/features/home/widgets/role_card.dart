import 'package:flutter/material.dart';
import '../../../theme.dart';

/// Animated role selection card with entrance slide and press-scale feedback.
class RoleCard extends StatefulWidget {
  const RoleCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.onTap,
    this.entranceDelay = 0,
  });

  final String        title;
  final String        subtitle;
  final IconData      icon;
  final Color         accentColor;
  final VoidCallback  onTap;
  final int           entranceDelay;

  @override
  State<RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<RoleCard> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _anim;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 550));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    Future.delayed(Duration(milliseconds: widget.entranceDelay), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, child) => Opacity(
        opacity: _anim.value,
        child:   Transform.translate(offset: Offset(0, 28 * (1 - _anim.value)), child: child),
      ),
      child: GestureDetector(
        onTapDown:   (_) => setState(() => _pressed = true),
        onTapUp:     (_) { setState(() => _pressed = false); widget.onTap(); },
        onTapCancel: ()  => setState(() => _pressed = false),
        child: AnimatedScale(
          scale:    _pressed ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 100),
          child: Container(
            decoration: BoxDecoration(
              color:        Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              boxShadow: [BoxShadow(
                color:      widget.accentColor.withValues(alpha: 0.10),
                blurRadius: 22,
                offset:     const Offset(0, 8),
              )],
            ),
            child: Padding(
              padding: AppSpacing.paddingLg,
              child: Row(
                children: [
                  Container(
                    width: 58, height: 58,
                    decoration: BoxDecoration(
                      color:        widget.accentColor.withValues(alpha: 0.08),
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
                        Text(widget.subtitle,
                            style: context.textStyles.bodyMedium?.withColor(
                                Theme.of(context).colorScheme.onSurfaceVariant)),
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
