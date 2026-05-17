import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../theme.dart';

/// PIN verification lifecycle.
enum PinVerifyState { idle, verifying, success, error }

// ── Glass text field ──────────────────────────────────────────────────────────

/// TextFormField styled for the frosted-glass registration card.
class GlassTextField extends StatelessWidget {
  const GlassTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.inputFormatters,
    this.validator,
  });

  final TextEditingController            controller;
  final String                           label;
  final IconData                         icon;
  final TextInputType?                   keyboardType;
  final List<TextInputFormatter>?        inputFormatters;
  final String? Function(String?)?       validator;

  @override
  Widget build(BuildContext context) {
    final white = Colors.white;
    final borderRadius = BorderRadius.circular(AppRadius.md);
    final side        = BorderSide(color: white.withValues(alpha: 0.3));
    return TextFormField(
      controller:       controller,
      keyboardType:     keyboardType,
      inputFormatters:  inputFormatters,
      validator:        validator,
      style:            const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText:    label,
        labelStyle:   TextStyle(color: white.withValues(alpha: 0.8)),
        prefixIcon:   Icon(icon, color: white.withValues(alpha: 0.8)),
        filled:       true,
        fillColor:    white.withValues(alpha: 0.1),
        border:             OutlineInputBorder(borderRadius: borderRadius, borderSide: side),
        enabledBorder:      OutlineInputBorder(borderRadius: borderRadius, borderSide: side),
        focusedBorder:      OutlineInputBorder(borderRadius: borderRadius, borderSide: const BorderSide(color: Colors.white, width: 2)),
        errorBorder:        OutlineInputBorder(borderRadius: borderRadius, borderSide: const BorderSide(color: Colors.redAccent, width: 2)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: borderRadius, borderSide: const BorderSide(color: Colors.redAccent, width: 2)),
        errorStyle: const TextStyle(color: Colors.redAccent),
      ),
    );
  }
}

// ── Action button ─────────────────────────────────────────────────────────────

/// White-background primary action button for registration steps.
class RegistrationActionButton extends StatelessWidget {
  const RegistrationActionButton({
    super.key,
    required this.label,
    required this.isLoading,
    required this.onPressed,
    this.icon,
  });

  final String          label;
  final bool            isLoading;
  final VoidCallback?   onPressed;
  final IconData?       icon;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Theme.of(context).colorScheme.primary,
        padding:         AppSpacing.verticalMd,
        shape:           RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      ),
      child: isLoading
          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize:      MainAxisSize.min,
              children: [
                if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 6)],
                Text(label, style: context.textStyles.titleSmall?.semiBold),
              ],
            ),
    );
  }
}

// ── Back button ───────────────────────────────────────────────────────────────

/// Outlined "Back" button matching the glass card aesthetic.
class RegistrationBackButton extends StatelessWidget {
  const RegistrationBackButton({super.key, required this.onPressed});
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side:            BorderSide(color: Colors.white.withValues(alpha: 0.5)),
        padding:         AppSpacing.verticalMd,
        shape:           RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      ),
      child: Text('Back', style: context.textStyles.titleSmall?.withColor(Colors.white)),
    );
  }
}

// ── Error text ────────────────────────────────────────────────────────────────

/// Centered red error message shown within a step.
class ErrorText extends StatelessWidget {
  const ErrorText({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.sm),
    child:   Text(message,
        style:     context.textStyles.bodySmall?.withColor(Colors.redAccent),
        textAlign: TextAlign.center),
  );
}

// ── PIN status badge ──────────────────────────────────────────────────────────

/// Animated badge that reflects the current [PinVerifyState].
class PinStatusBadge extends StatelessWidget {
  const PinStatusBadge({super.key, required this.state, this.error});
  final PinVerifyState state;
  final String?        error;

  @override
  Widget build(BuildContext context) {
    Widget content = switch (state) {
      PinVerifyState.verifying => _badge(
          key: const ValueKey('v'), color: Colors.white.withValues(alpha: 0.15),
          border: Colors.white.withValues(alpha: 0.3),
          icon: const SizedBox(width: 14, height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white))),
          label: 'Verifying PIN with server…', labelColor: Colors.white.withValues(alpha: 0.9)),
      PinVerifyState.success => _badge(
          key: const ValueKey('s'), color: Colors.green.withValues(alpha: 0.25),
          border: Colors.greenAccent.withValues(alpha: 0.6),
          icon: const Icon(Icons.check_circle_rounded, size: 16, color: Colors.greenAccent),
          label: 'PIN Verified!', labelColor: Colors.greenAccent),
      PinVerifyState.error => _badge(
          key: const ValueKey('e'), color: Colors.red.withValues(alpha: 0.18),
          border: Colors.redAccent.withValues(alpha: 0.5),
          icon: const Icon(Icons.cancel_rounded, size: 16, color: Colors.redAccent),
          label: error ?? 'Invalid PIN.', labelColor: Colors.redAccent),
      PinVerifyState.idle => const SizedBox.shrink(key: ValueKey('i')),
    };

    return AnimatedSwitcher(
      duration:           const Duration(milliseconds: 250),
      transitionBuilder:  (child, anim) => FadeTransition(
        opacity: anim,
        child:   SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, -0.3), end: Offset.zero).animate(anim),
          child:    child,
        ),
      ),
      child: content,
    );
  }

  Widget _badge({required Key key, required Color color, required Color border,
      required Widget icon, required String label, required Color labelColor}) {
    return Container(
      key: key,
      padding:    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10),
          border: Border.all(color: border)),
      child: Row(children: [
        icon, const SizedBox(width: 10),
        Expanded(child: Text(label,
            style: TextStyle(color: labelColor, fontSize: 13, fontWeight: FontWeight.w500))),
      ]),
    );
  }
}
