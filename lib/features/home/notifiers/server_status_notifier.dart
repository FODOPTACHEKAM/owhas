import 'package:flutter/foundation.dart';
import '../../../services/server_config.dart';
import '../../../services/api_service.dart';

enum ServerConnectionStatus { checking, cloud, wifi, none }

class ServerStatusNotifier extends ChangeNotifier {
  ServerConnectionStatus _status    = ServerConnectionStatus.checking;
  String                 _serverUrl = '';

  ServerConnectionStatus get status    => _status;
  String                 get serverUrl => _serverUrl;

  /// Call once after app startup detection has already run.
  Future<void> initialize() => _updateStatus();

  /// Reset detection and re-probe from scratch.
  Future<void> refresh() async {
    _status = ServerConnectionStatus.checking;
    notifyListeners();
    ServerConfig().reset();
    await ServerConfig().detect();
    await _updateStatus();
  }

  Future<void> _updateStatus() async {
    _serverUrl = ServerConfig().baseUrl;
    try {
      await ApiService().pingServer();
      _status = ServerConfig().isOnline
          ? ServerConnectionStatus.cloud
          : ServerConnectionStatus.wifi;
    } catch (_) {
      _status = ServerConnectionStatus.none;
    }
    notifyListeners();
  }
}
