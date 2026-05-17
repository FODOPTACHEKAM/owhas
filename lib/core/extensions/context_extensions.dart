import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Convenience shortcuts so screens never import ScaffoldMessenger,
/// Theme, or GoRouter individually.
extension ContextExtensions on BuildContext {
  // ── Theme shortcuts ───────────────────────────────────────────────────────────
  ColorScheme get colors    => Theme.of(this).colorScheme;
  TextTheme   get textTheme => Theme.of(this).textTheme;

  // ── SnackBar shortcuts ────────────────────────────────────────────────────────
  void showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: colors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void showInfo(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ── Navigation shortcuts ──────────────────────────────────────────────────────
  void navigateTo(String route)  => go(route);
  void pushRoute(String route)   => push(route);
}
