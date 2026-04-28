import 'dart:io';
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../models/attendance_record.dart';
import 'api_service.dart';

/// Data structure for student attendance from Excel/PDF
class StudentAttendanceData {
  final String matricule;
  final String name;
  final int totalPresence;

  StudentAttendanceData({
    required this.matricule,
    required this.name,
    required this.totalPresence,
  });
}

/// Result of uploading and parsing a previous session file
class PreviousSessionResult {
  final List<StudentAttendanceData> students;
  final int sessionNumber;

  PreviousSessionResult({
    required this.students,
    required this.sessionNumber,
  });
}

/// Service for Excel/PDF-based persistence and reporting
class ExcelService {
  static final ExcelService _instance = ExcelService._internal();
  factory ExcelService() => _instance;
  ExcelService._internal();

  final ApiService _apiService = ApiService();

  /// Upload and parse previous session's Excel or PDF file
  /// Returns both the student list and the detected session number
  Future<PreviousSessionResult?> uploadPreviousSession() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'pdf'],
        withData: true, // Ensure bytes are loaded on all platforms
      );

      if (result == null || result.files.isEmpty) {
        print('FilePicker: User cancelled or no file selected');
        return null;
      }

      final file = result.files.first;
      List<int>? bytes = file.bytes;

      // Fallback: read from path if bytes not available (common on some Android versions)
      if (bytes == null && file.path != null) {
        print('FilePicker: bytes null, reading from path: ${file.path}');
        final fileObj = File(file.path!);
        if (await fileObj.exists()) {
          bytes = await fileObj.readAsBytes();
        }
      }

      if (bytes == null || bytes.isEmpty) {
        print('FilePicker: Could not read file bytes (path: ${file.path})');
        throw Exception('Could not read file. Try a different file or location.');
      }

      final extension = file.extension?.toLowerCase() ?? '';
      print('FilePicker: Selected file with extension: $extension, size: ${bytes.length} bytes');

      if (extension == 'pdf') {
        return await _parsePdf(bytes);
      } else {
        final students = await _parseExcel(bytes);
        return PreviousSessionResult(students: students, sessionNumber: 1);
      }
    } on Exception catch (e) {
      print('Error uploading previous session: $e');
      rethrow; // Let provider handle the specific error message
    }
  }

  /// Parse Excel file to extract student attendance data
  Future<List<StudentAttendanceData>> _parseExcel(List<int> bytes) async {
    final excel = Excel.decodeBytes(bytes);
    final sheet = excel.tables[excel.tables.keys.first];
    if (sheet == null) return [];

    final List<StudentAttendanceData> students = [];

    // Find the "Master Roster" section or use the main sheet
    // Expected columns: Matricule, Name, Total Presence (or last column with numbers)
    for (var i = 1; i < sheet.rows.length; i++) {
      final row = sheet.rows[i];
      if (row.isEmpty) continue;

      try {
        final matricule = row[0]?.value?.toString() ?? '';
        final name = row[1]?.value?.toString() ?? '';

        // Look for total presence in the last numeric column
        int totalPresence = 0;
        for (var j = row.length - 1; j >= 2; j--) {
          final cell = row[j];
          if (cell?.value != null) {
            final valueString = cell!.value.toString();
            final parsed = int.tryParse(valueString);
            if (parsed != null) {
              totalPresence = parsed;
              break;
            }
          }
        }

        if (matricule.isNotEmpty && name.isNotEmpty) {
          students.add(StudentAttendanceData(
            matricule: matricule,
            name: name,
            totalPresence: totalPresence,
          ));
        }
      } catch (e) {
        continue;
      }
    }

    return students;
  }

  /// Parse PDF file by sending it to the Node.js server for text extraction
  Future<PreviousSessionResult> _parsePdf(List<int> bytes) async {
    try {
      final pdfBytes = Uint8List.fromList(bytes);
      print('PDF: Sending ${pdfBytes.length} bytes to server for parsing...');
      
      final result = await _apiService.parsePdfOnServer(pdfBytes);
      final parsedStudents = result['students'] as List<Map<String, dynamic>>;
      final sessionNumber = result['sessionNumber'] as int? ?? 1;

      print('PDF: Server returned ${parsedStudents.length} students, sessionNumber: $sessionNumber');

      if (parsedStudents.isEmpty) {
        throw Exception('Server could not extract any student data from the PDF. Ensure the PDF contains a MASTER ROSTER or student table.');
      }

      final students = parsedStudents.map((json) {
        return StudentAttendanceData(
          matricule: json['matricule'] as String? ?? '',
          name: json['name'] as String? ?? 'Unknown',
          totalPresence: json['totalPresence'] as int? ?? 0,
        );
      }).where((s) => s.matricule.isNotEmpty).toList();

      if (students.isEmpty) {
        throw Exception('Server found ${parsedStudents.length} entries but none had valid matricules.');
      }

      return PreviousSessionResult(
        students: students,
        sessionNumber: sessionNumber,
      );
    } on Exception catch (e) {
      print('Error parsing PDF via server: $e');
      rethrow;
    }
  }

  /// Generate hybrid Excel report with Daily Snapshot and Master Roster
  Future<String?> generateReport({
    required String courseName,
    required DateTime sessionDate,
    required List<AttendanceRecord> currentSessionRecords,
    required Map<String, int> previousAttendance,
    required int maxAttendanceCount,
  }) async {
    try {
      final excel = Excel.createExcel();
      excel.rename('Sheet1', 'Attendance Report');
      final sheet = excel['Attendance Report'];

      int currentRow = 0;

      // Header
      _addCell(sheet, currentRow, 0, 'Attendance Report', bold: true);
      currentRow++;
      _addCell(sheet, currentRow, 0, 'Course: $courseName');
      currentRow++;
      _addCell(sheet, currentRow, 0,
          'Date: ${DateFormat('yyyy-MM-dd HH:mm').format(sessionDate)}');
      currentRow++;
      _addCell(sheet, currentRow, 0,
          'Max Attendance: $maxAttendanceCount');
      currentRow += 2;

      // SECTION 1: Daily Snapshot
      _addCell(sheet, currentRow, 0, 'DAILY SNAPSHOT', bold: true);
      currentRow++;
      _addCell(sheet, currentRow, 0, 'Matricule', bold: true);
      _addCell(sheet, currentRow, 1, 'Name', bold: true);
      _addCell(sheet, currentRow, 2, 'Email', bold: true);
      _addCell(sheet, currentRow, 3, 'Joined At', bold: true);
      _addCell(sheet, currentRow, 4, 'Connection (min)', bold: true);
      _addCell(sheet, currentRow, 5, 'Verified', bold: true);
      currentRow++;

      for (final record in currentSessionRecords) {
        _addCell(sheet, currentRow, 0, record.matricule);
        _addCell(sheet, currentRow, 1, record.studentName);
        _addCell(sheet, currentRow, 2, record.email ?? 'N/A');
        _addCell(sheet, currentRow, 3,
            DateFormat('HH:mm').format(record.joinedAt));
        _addCell(sheet, currentRow, 4,
            record.connectionDurationMinutes.toString());
        _addCell(sheet, currentRow, 5,
            record.isVerified ? 'Yes' : 'No');
        currentRow++;
      }

      currentRow += 2;

      // SECTION 2: Master Roster with Cumulative Attendance
      _addCell(sheet, currentRow, 0, 'MASTER ROSTER', bold: true);
      currentRow++;
      _addCell(sheet, currentRow, 0, 'Matricule', bold: true);
      _addCell(sheet, currentRow, 1, 'Name', bold: true);
      _addCell(sheet, currentRow, 2, 'Email', bold: true);
      _addCell(sheet, currentRow, 3, 'Previous Total', bold: true);
      _addCell(sheet, currentRow, 4, 'New Total', bold: true);
      _addCell(sheet, currentRow, 5, 'Percentage', bold: true);
      currentRow++;

      // Build master list combining previous and current
      final Map<String, StudentAttendanceData> masterList = {};

      // Add students from previous attendance
      previousAttendance.forEach((matricule, total) {
        if (!masterList.containsKey(matricule)) {
          masterList[matricule] = StudentAttendanceData(
            matricule: matricule,
            name: '', // Will be updated if present in current session
            totalPresence: total,
          );
        }
      });

      // Process current session with increment/freeze logic
      for (final record in currentSessionRecords) {
        final previousTotal = previousAttendance[record.matricule] ?? 0;

        int newTotal;
        if (record.isVerified) {
          // Increment rule: +1 if present and verified, capped at max
          newTotal = (previousTotal + 1).clamp(0, maxAttendanceCount);
        } else {
          // Freeze rule: carry over previous value if absent
          newTotal = previousTotal;
        }

        masterList[record.matricule] = StudentAttendanceData(
          matricule: record.matricule,
          name: record.studentName,
          totalPresence: newTotal,
        );
      }

      // Add students who were absent (freeze their values)
      previousAttendance.forEach((matricule, total) {
        if (!masterList.containsKey(matricule)) {
          masterList[matricule] = StudentAttendanceData(
            matricule: matricule,
            name: '',
            totalPresence: total, // Frozen
          );
        }
      });

      // Write master roster
      final sortedMaster = masterList.values.toList()
        ..sort((a, b) => a.matricule.compareTo(b.matricule));

      for (final student in sortedMaster) {
        final previousTotal = previousAttendance[student.matricule] ?? 0;
        final percentage =
            maxAttendanceCount > 0
                ? (student.totalPresence / maxAttendanceCount * 100).toStringAsFixed(1)
                : '0.0';

        // Look up email from current session records
        String? email;
        try {
          final record = currentSessionRecords.firstWhere(
            (r) => r.matricule == student.matricule,
          );
          email = record.email;
        } catch (_) {
          email = null;
        }

        _addCell(sheet, currentRow, 0, student.matricule);
        _addCell(sheet, currentRow, 1, student.name.isNotEmpty ? student.name : 'N/A');
        _addCell(sheet, currentRow, 2, email ?? 'N/A');
        _addCell(sheet, currentRow, 3, previousTotal.toString());
        _addCell(sheet, currentRow, 4, student.totalPresence.toString());
        _addCell(sheet, currentRow, 5, '$percentage%');
        currentRow++;
      }

      // Save file
      final directory = await getApplicationDocumentsDirectory();
      final fileName =
          'attendance_${courseName.replaceAll(' ', '_')}_${DateFormat('yyyyMMdd_HHmmss').format(sessionDate)}.xlsx';
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(excel.encode()!);

      return filePath;
    } catch (e) {
      print('Error generating report: $e');
      return null;
    }
  }

  void _addCell(Sheet sheet, int row, int col, String value,
      {bool bold = false}) {
    final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
    cell.value = TextCellValue(value);
    if (bold) {
      cell.cellStyle = CellStyle(bold: true);
    }
  }
}

