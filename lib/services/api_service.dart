import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

/// Service for communicating with the Node.js Hotspot server
class ApiService {
  // Use your Windows Mobile Hotspot IP.
  // From ipconfig, your hotspot adapter is "Connexion au réseau local* 10"
  // with IPv4 Address: 192.168.137.1
  static const String baseUrl = 'http://192.168.137.1:5501';

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

  /// Reset the server's attendee list (call when creating a new session)
  Future<void> resetServerSession({
    String? courseName,
    String? courseCode,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/reset'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          if (courseName != null) 'courseName': courseName,
          if (courseCode != null) 'courseCode': courseCode,
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
      final response = await http.post(
        Uri.parse('$baseUrl/api/remove-attendee'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'matricule': matricule}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception('Server responded with status ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to remove attendee from server: $e');
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
