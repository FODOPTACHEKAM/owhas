import 'dart:async';
import 'package:network_discovery/network_discovery.dart';

/// Service for scanning the Wi-Fi subnet to count active devices.
///
/// Since Flutter cannot directly inspect OS-level connection tables,
/// this uses the [network_discovery] package to perform a lightweight
/// TCP port scan over the hotspot subnet (typically 192.168.137.x).
class NetworkDiscoveryService {
  static const String _defaultSubnet = '192.168.137';
  static const int _defaultPort = 5501;
  static const Duration _scanTimeout = Duration(seconds: 30);

  final String subnet;
  final int port;

  NetworkDiscoveryService({
    this.subnet = _defaultSubnet,
    this.port = _defaultPort,
  });

  /// Scans the configured subnet and returns the count of active hosts
  /// that have [port] open, plus their IP addresses.
  Future<NetworkScanResult> scanActiveDevices() async {
    final devices = <String>[];

    try {
      final stream = NetworkDiscovery.discover(subnet, port);
      await for (final NetworkAddress addr in stream.timeout(_scanTimeout)) {
        devices.add(addr.ip);
      }
    } on TimeoutException {
      // Expected when no more devices respond within the timeout window
    } catch (e) {
      // Swallow scan errors (e.g., no Wi-Fi, permission denied)
    }

    return NetworkScanResult(
      activeDeviceCount: devices.length,
      deviceIps: devices,
    );
  }
}

/// Immutable result of a network discovery scan.
class NetworkScanResult {
  final int activeDeviceCount;
  final List<String> deviceIps;

  const NetworkScanResult({
    required this.activeDeviceCount,
    required this.deviceIps,
  });

  bool get isEmpty => activeDeviceCount == 0;

  @override
  String toString() =>
      'NetworkScanResult(count: $activeDeviceCount, ips: $deviceIps)';
}

