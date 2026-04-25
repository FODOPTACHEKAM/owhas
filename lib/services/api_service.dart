import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

/// Service for communicating with the Node.js Hotspot server
class ApiService {
  // Use your Windows Mobile Hotspot IP.
  // From ipconfig, your hotspot adapter is "Connexion au réseau local* 10"
  // with IPv4 Address: 192.168.137.1
  static const String baseUrl = 'http://192.168.137.1:5501';

  /// Fetch the attendance PDF bytes from the server's /export endpoint
  Future<Uint8List?> fetchServerPdf() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/export'),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        throw Exception('Server responded with status ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to fetch PDF from server: $e');
    }
  }

  /// Fetch the full list of attendees from the server's /api/attendees endpoint
  Future<List<Map<String, dynamic>>> fetchServerAttendees() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/attendees'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final attendees = data['attendees'] as List<dynamic>? ?? [];
        return attendees.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Server responded with status ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to fetch attendees from server: $e');
    }
  }

  /// Fetch stats (total, verified, pending) from the server's /api/stats endpoint
  Future<Map<String, dynamic>> fetchServerStats() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/stats'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Server responded with status ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to fetch stats from server: $e');
    }
  }

  /// Register a student on the Node.js server (hotspot registration)
  Future<void> registerStudentOnServer({
    required String username,
    required String matricule,
    String? email,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/connect'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'matricule': matricule,
          if (email != null && email.isNotEmpty) 'email': email,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception('Server responded with status ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to register student on server: $e');
    }
  }

  /// Push session configuration to the server
  Future<void> pushSessionConfig({
    required int requiredConnectionMinutes,
    required int gracePeriodMinutes,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/session-config'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'requiredConnectionMinutes': requiredConnectionMinutes,
          'gracePeriodMinutes': gracePeriodMinutes,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception('Server responded with status ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to push session config to server: $e');
    }
  }
}

