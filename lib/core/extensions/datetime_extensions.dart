import 'package:intl/intl.dart';

extension DateTimeExtensions on DateTime {
  /// e.g. "16 May 2026"
  String get displayDate     => DateFormat('dd MMM yyyy').format(this);

  /// e.g. "14:35"
  String get displayTime     => DateFormat('HH:mm').format(this);

  /// e.g. "16 May 2026 14:35"
  String get displayDateTime => DateFormat('dd MMM yyyy HH:mm').format(this);

  /// e.g. "2026-05-16"  — safe for file names and JSON
  String get fileNameSafe    => DateFormat('yyyy-MM-dd').format(this);

  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }

  /// Remaining minutes until [other], or 0 if [other] is in the past.
  int minutesUntil(DateTime other) {
    final diff = other.difference(this).inMinutes;
    return diff < 0 ? 0 : diff;
  }
}
