import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'server_config.dart';

/// Service for communicating with the Node.js Hotspot server
class ApiService {
  /// Dynamic base URL auto-detected for emulator (10.0.2.2) or hotspot (192.168.137.1)
  static String get baseUrl => ServerConfig().baseUrl;

  String? _sessionPin;
  // ignore: unused_field — stored for future token-auth headers
  String? _sessionToken;

  void setSessionPin(String pin) => _sessionPin = pin;
  void setSessionToken(String token) => _sessionToken = token;
  void clearSession() {
    _sessionPin = null;
    _sessionToken = null;
  }

  /// Ping the server to check if it's reachable
  Future<void> pingServer() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/ping'),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) {
        throw Exception('Server responded with status ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Server is not reachable at $baseUrl: $e');
    }
  }

  /// Fetch the attendance PDF bytes from the server's /export endpoint
  Future<Uint8List?> fetchServerPdf() async {
    try {
      final pin = _sessionPin;
      if (pin == null) throw Exception('No session PIN set');

      final response = await http.get(
        Uri.parse('$baseUrl/export?pin=$pin'),
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
      final pin = _sessionPin;
      if (pin == null) throw Exception('No session PIN set');

      final response = await http.get(
        Uri.parse('$baseUrl/api/attendees?pin=$pin'),
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
      final pin = _sessionPin;
      if (pin == null) throw Exception('No session PIN set');

      final response = await http.get(
        Uri.parse('$baseUrl/api/stats?pin=$pin'),
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
      final pin = _sessionPin;
      if (pin == null) throw Exception('No session PIN set');

      final response = await http.post(
        Uri.parse('$baseUrl/connect'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'matricule': matricule,
          if (email != null && email.isNotEmpty) 'email': email,
          'sessionPin': pin,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception('Server responded with status ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to register student on server: $e');
    }
  }

  /// Reset the server's attendee list (call when creating a new session)
  Future<void> resetServerSession({
    required String pin,
    String? courseName,
    String? courseCode,
    String? lecturerId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/reset'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'pin': pin,
          if (courseName != null) 'courseName': courseName,
          if (courseCode != null) 'courseCode': courseCode,
          if (lecturerId != null) 'lecturerId': lecturerId,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception('Server responded with status ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to reset server session: $e');
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

  /// Remove an attendee from the server by matricule
  Future<void> removeAttendeeOnServer(String matricule) async {
    try {
      final pin = _sessionPin;
      if (pin == null) throw Exception('No session PIN set');

      final response = await http.post(
        Uri.parse('$baseUrl/api/remove-attendee'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'matricule': matricule,
          'pin': pin,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception('Server responded with status ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to remove attendee from server: $e');
    }
  }

  /// Check whether a PIN matches an active session on the server.
  /// Returns true if the server confirms the PIN, false otherwise.
  Future<bool> verifySessionPin(String pin) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/stats?pin=$pin'),
      ).timeout(const Duration(seconds: 8));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Upload a PDF file to the server for text extraction and parsing
  /// Returns a map with 'students' list and 'sessionNumber'
  Future<Map<String, dynamic>> parsePdfOnServer(Uint8List pdfBytes) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/api/parse-pdf'));
      request.files.add(http.MultipartFile.fromBytes('pdf', pdfBytes, filename: 'previous_session.pdf'));

      final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          final students = data['students'] as List<dynamic>? ?? [];
          final sessionNumber = data['sessionNumber'] as int? ?? 1;
          return {
            'students': students.cast<Map<String, dynamic>>(),
            'sessionNumber': sessionNumber,
          };
        } else {
          throw Exception(data['error'] ?? 'Server failed to parse PDF');
        }
      } else {
        throw Exception('Server responded with status ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to parse PDF on server: $e');
    }
  }
}

