import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Service for device fingerprinting to prevent proxy attendance
class DeviceService {
  static final DeviceService _instance = DeviceService._internal();
  factory DeviceService() => _instance;
  DeviceService._internal();

  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  String? _cachedFingerprint;

  /// Generate a unique device fingerprint
  Future<String> getDeviceFingerprint() async {
    if (_cachedFingerprint != null) return _cachedFingerprint!;

    try {
      String fingerprint;

      if (kIsWeb) {
        final webInfo = await _deviceInfo.webBrowserInfo;
        fingerprint = '${webInfo.browserName}_${webInfo.platform}_${webInfo.userAgent?.hashCode}';
      } else if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        fingerprint = '${androidInfo.id}_${androidInfo.model}_${androidInfo.device}';
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        fingerprint = '${iosInfo.identifierForVendor}_${iosInfo.model}';
      } else {
        fingerprint = 'unknown_${DateTime.now().millisecondsSinceEpoch}';
      }

      _cachedFingerprint = fingerprint;
      return fingerprint;
    } catch (e) {
      // Fallback fingerprint
      final fallback = 'fallback_${DateTime.now().millisecondsSinceEpoch}';
      _cachedFingerprint = fallback;
      return fallback;
    }
  }

  /// Check if this device has already registered for a session
  bool isDeviceAlreadyRegistered(
    String deviceFingerprint,
    List<String> registeredFingerprints,
  ) {
    return registeredFingerprints.contains(deviceFingerprint);
  }
}
