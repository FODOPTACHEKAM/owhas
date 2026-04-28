import 'dart:async';
import 'package:http/http.dart' as http;

/// Centralized server address detection.
///
/// When running on the Android Emulator, the host machine is reachable via
/// the special loopback IP 10.0.2.2. When running on a real phone connected
/// to the Windows Mobile Hotspot, the server is at 192.168.137.1.
///
/// This service auto-detects the correct IP at startup and caches it.
class ServerConfig {
  static final ServerConfig _instance = ServerConfig._internal();
  factory ServerConfig() => _instance;
  ServerConfig._internal();

  static const String _emulatorHost = '10.0.2.2';
  static const String _hotspotHost = '192.168.137.1';
  static const int _port = 5501;
  static const Duration _pingTimeout = Duration(seconds: 3);

  String? _detectedHost;
  bool _hasDetected = false;

  /// The detected host IP (e.g. '10.0.2.2' or '192.168.137.1').
  String get host => _detectedHost ?? _hotspotHost;

  /// The full base URL for API calls (e.g. 'http://10.0.2.2:5501').
  String get baseUrl => 'http://$host:$_port';

  /// The full URL for the poster QR code.
  String get baseQrUrl => '$baseUrl/public/hotspot.html';

  /// The /24 subnet for network discovery scans.
  String get subnet {
    // For emulator loopback we can't scan the subnet meaningfully,
    // so fall back to the hotspot subnet which is the real use-case.
    if (host == _emulatorHost) return _hotspotHost;
    return host;
  }

  /// Auto-detect the correct server IP.
  /// Call once at app startup (e.g. in main() before runApp).
  Future<void> detect() async {
    if (_hasDetected) return;

    // 1. Try emulator loopback first (fastest path during development)
    if (await _ping(_emulatorHost)) {
      _detectedHost = _emulatorHost;
      _hasDetected = true;
      print('[ServerConfig] Detected emulator host: $_emulatorHost');
      return;
    }

    // 2. Try Windows Mobile Hotspot IP
    if (await _ping(_hotspotHost)) {
      _detectedHost = _hotspotHost;
      _hasDetected = true;
      print('[ServerConfig] Detected hotspot host: $_hotspotHost');
      return;
    }

    // 3. Default to hotspot IP even if unreachable (will fail fast on requests)
    _detectedHost = _hotspotHost;
    _hasDetected = true;
    print('[ServerConfig] No host reachable, defaulting to: $_hotspotHost');
  }

  /// Reset detection so the next call to [detect] will re-scan.
  void reset() {
    _hasDetected = false;
    _detectedHost = null;
  }

  Future<bool> _ping(String host) async {
    try {
      final response = await http
          .get(Uri.parse('http://$host:$_port/ping'))
          .timeout(_pingTimeout);
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}

