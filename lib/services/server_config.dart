import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Server detection result from background isolate.
class _ServerDetectionResult {
  final String? url;
  final bool isOnline;

  _ServerDetectionResult({required this.url, required this.isOnline});
}

/// Top-level function for background server detection (runs in Isolate via compute).
/// This prevents UI jank by executing on a separate thread.
Future<_ServerDetectionResult> _detectServerInBackground(void _) async {
  const Duration strictTimeout = Duration(milliseconds: 800);

  // 1. Fixed candidates — covers hotspot gateways and known PC IPs.
  final fixedCandidates = <String>[
    'http://192.168.137.1:5501',  // Windows Mobile Hotspot
    'http://10.0.0.1:5501',
    'http://192.168.43.1:5501',   // Android hotspot
    'http://172.20.10.1:5501',    // iOS hotspot
    'http://192.168.50.1:5501',
  ];

  // 2. Full subnet scan of 192.168.0.x and 192.168.1.x (DHCP range .1–.254).
  // All run in parallel with a short timeout so the total wait is ~800 ms.
  final subnetCandidates = <String>[
    for (int i = 1; i <= 254; i++) 'http://192.168.0.$i:5501',
    for (int i = 1; i <= 254; i++) 'http://192.168.1.$i:5501',
    for (int i = 1; i <= 254; i++) 'http://10.0.0.$i:5501',
  ];

  try {
    final allCandidates = [...fixedCandidates, ...subnetCandidates];
    final results = await Future.wait(
      allCandidates.map((url) => _pingWithStrictTimeout(url, strictTimeout)),
      eagerError: false,
    );

    for (int i = 0; i < results.length; i++) {
      if (results[i]) {
        print('[ServerConfig] Detected server: ${allCandidates[i]}');
        return _ServerDetectionResult(url: allCandidates[i], isOnline: false);
      }
    }
  } catch (e) {
    print('[ServerConfig] Subnet scan error: $e');
  }

  // 3. Try emulator loopback.
  try {
    final emulatorUrl = ServerConfig().emulatorUrl;
    if (await _pingWithStrictTimeout(emulatorUrl, strictTimeout)) {
      print('[ServerConfig] Detected emulator URL: $emulatorUrl');
      return _ServerDetectionResult(url: emulatorUrl, isOnline: false);
    }
  } catch (e) {
    print('[ServerConfig] Emulator check error: $e');
  }

  // 4. Try online cloud URL.
  try {
    final onlineUrl = ServerConfig().onlineUrl;
    if (await _pingWithStrictTimeout(onlineUrl, const Duration(seconds: 2))) {
      print('[ServerConfig] Detected online server: $onlineUrl');
      return _ServerDetectionResult(url: onlineUrl, isOnline: true);
    }
  } catch (e) {
    print('[ServerConfig] Online check error: $e');
  }

  // 5. Fallback.
  print('[ServerConfig] No server detected. Falling back to default hotspot URL.');
  return _ServerDetectionResult(url: 'http://192.168.137.1:5501', isOnline: false);
}

/// Ping a URL with strict timeout to avoid UI jank.
Future<bool> _pingWithStrictTimeout(String url, Duration timeout) async {
  try {
    final response = await http
        .get(
          Uri.parse('$url/ping'),
          // Add explicit headers to avoid slowdowns
        )
        .timeout(timeout, onTimeout: () {
      throw TimeoutException('Ping timeout for $url');
    });
    return response.statusCode == 200;
  } catch (_) {
    // Silently fail; tried best effort
    return false;
  }
}


/// Centralized server address detection.
///
/// When running on the Android Emulator, the host machine is reachable via
/// the special loopback IP 10.0.2.2. When running on a real phone connected
/// to the Windows Mobile Hotspot, the server is at 192.168.137.1.
///
/// This service auto-detects the correct IP at startup and caches it.
/// Detection runs in a background isolate to prevent UI jank.
class ServerConfig {
  static final ServerConfig _instance = ServerConfig._internal();
  factory ServerConfig() => _instance;
  ServerConfig._internal();

  static const String _onlineUrl = 'https://owhas.com';
  static const String _defaultEmulatorHost = '10.0.2.2';
  static const String _defaultHotspotHost = '192.168.137.1';
  static const int _defaultServerPort = 5501;

  String? _detectedUrl;
  bool _hasDetected = false;
  bool _isOnline = false;

  /// The emulator host URL generated at runtime.
  String get emulatorUrl =>
      Uri(scheme: 'http', host: _defaultEmulatorHost, port: _defaultServerPort)
          .toString();

  /// The hotspot URL generated at runtime from the current hotspot host.
  String get hotspotUrl =>
      Uri(scheme: 'http', host: _defaultHotspotHost, port: _defaultServerPort)
          .toString();

  /// The fixed online cloud endpoint.
  String get onlineUrl => _onlineUrl;

  /// True if connected to the cloud, false if connected to local Intranet.
  bool get isOnline => _isOnline;

  /// The full base URL for API calls.
  String get baseUrl => _detectedUrl ?? hotspotUrl;

  /// The full URL for the poster QR code.
  String get baseQrUrl => '$baseUrl/public/hotspot.html';

  /// Fetch the dynamic QR URL from the server based on the hosting device's IP.
  Future<String> getDynamicQrUrl() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/qr-url')).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final qrUrl = data['qrUrl'] as String?;
        if (qrUrl != null && qrUrl.isNotEmpty) {
          return qrUrl;
        }
      }
    } catch (e) {
      print('[ServerConfig] Failed to fetch dynamic QR URL: $e');
    }
    // Fallback to static URL
    return baseQrUrl;
  }

  /// The /24 subnet for network discovery scans.
  String get subnet {
    if (baseUrl.contains('10.0.2.2')) return '192.168.137.1';
    if (baseUrl.contains('owhas.com')) return 'owhas.com';
    return '192.168.137.1';
  }

  /// Auto-detect the correct server URL using background isolate.
  ///
  /// This method runs detection in a background isolate to prevent UI jank.
  /// It performs parallel scanning of common local IP addresses with strict
  /// timeouts, then falls back to default if no server is found.
  Future<void> detect() async {
    if (_hasDetected) return;

    try {
      // Run server detection in background isolate (prevents UI jank)
      final result = await compute<void, _ServerDetectionResult>(
        _detectServerInBackground,
        null,
      );

      if (result.url != null) {
        _detectedUrl = result.url;
        _isOnline = result.isOnline;
        _hasDetected = true;
        print(
          '[ServerConfig] Server detection complete. '
          'URL: $_detectedUrl, Online: $_isOnline',
        );
      } else {
        // Graceful fallback (should not happen due to background logic)
        _detectedUrl = hotspotUrl;
        _isOnline = false;
        _hasDetected = true;
        print('[ServerConfig] Fallback to default hotspot URL');
      }
    } catch (e) {
      // Handle any unexpected errors gracefully
      print('[ServerConfig] Detection error: $e. Falling back to hotspot.');
      _detectedUrl = hotspotUrl;
      _isOnline = false;
      _hasDetected = true;
    }
  }

  void reset() {
    _hasDetected = false;
    _detectedUrl = null;
    _isOnline = false;
  }
}

