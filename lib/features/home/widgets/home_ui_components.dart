import 'package:flutter/material.dart';

/// Soft circular gradient blob used as a decorative background element.
class AmbientBlob extends StatelessWidget {
  const AmbientBlob({super.key, required this.size, required this.color});
  final double size;
  final Color  color;

  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      shape:    BoxShape.circle,
      gradient: RadialGradient(colors: [color, Colors.transparent]),
    ),
  );
}

/// Thin divider with an uppercase label — used to introduce role sections.
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Row(
      children: [
        Text(label, style: TextStyle(
          fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5,
          color: onSurface.withValues(alpha: 0.35),
        )),
        const SizedBox(width: 10),
        Expanded(child: Divider(thickness: 0.5, color: onSurface.withValues(alpha: 0.1))),
      ],
    );
  }
}

/// Small pill badge with an icon and a text label.
class BadgePill extends StatelessWidget {
  const BadgePill({super.key, required this.icon, required this.label, required this.color});
  final IconData icon;
  final String   label;
  final Color    color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color:        color.withValues(alpha: 0.09),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color.withValues(alpha: 0.8)),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w600,
          color: color.withValues(alpha: 0.8),
        )),
      ],
    ),
  );
}
