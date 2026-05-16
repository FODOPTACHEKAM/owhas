import 'package:flutter/material.dart';
import '../../../theme.dart';

/// Animated green success dialog — auto-dismisses after 2 seconds.
class SuccessDialog extends StatefulWidget {
  const SuccessDialog({super.key, this.onDismissed});
  final VoidCallback? onDismissed;

  @override
  State<SuccessDialog> createState() => _SuccessDialogState();
}

class _SuccessDialogState extends State<SuccessDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _scale;

  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _scale = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
    _ctrl.forward();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) { Navigator.pop(context); widget.onDismissed?.call(); }
    });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          padding:    AppSpacing.paddingXl,
          decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(AppRadius.xl)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 80),
              const SizedBox(height: AppSpacing.md),
              Text('Registered Successfully!',
                  style: context.textStyles.titleLarge?.bold.withColor(Colors.white),
                  textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.sm),
              Text('Stay connected for verification',
                  style: context.textStyles.bodyMedium?.withColor(Colors.white.withValues(alpha: 0.9)),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
