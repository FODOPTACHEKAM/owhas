import 'package:flutter/foundation.dart';

/// Eliminates the _isLoading/_error boilerplate that was copy-pasted
/// across every method in AttendanceProvider.
///
/// Usage:
///   class MyNotifier extends ChangeNotifier with LoadingMixin { ... }
///   await runWithLoading(() => someService.doWork());
mixin LoadingMixin on ChangeNotifier {
  bool _isLoading = false;
  String? _error;

  bool get isLoading => _isLoading;
  String? get error => _error;

  void setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void setError(String? message) {
    _error = message;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Wraps [action] with loading/error state management.
  /// Sets [_isLoading] true, awaits the action, then sets it false.
  /// Any exception is caught and stored in [_error]; returns null on failure.
  Future<T?> runWithLoading<T>(
    Future<T> Function() action, {
    bool clearErrorFirst = true,
  }) async {
    if (clearErrorFirst) _error = null;
    _isLoading = true;
    notifyListeners();
    try {
      final result = await action();
      _isLoading = false;
      notifyListeners();
      return result;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }
}
