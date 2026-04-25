import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../models/attendance_record.dart';

/// Data structure for student attendance from Excel
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

/// Service for Excel-based persistence and reporting
class ExcelService {
  static final ExcelService _instance = ExcelService._internal();
  factory ExcelService() => _instance;
  ExcelService._internal();

  /// Upload and parse previous session's Excel file
  Future<List<StudentAttendanceData>?> uploadPreviousSession() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );

      if (result == null || result.files.isEmpty) return null;

      final bytes = result.files.first.bytes;
      if (bytes == null) return null;

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
    } catch (e) {
      return null;
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
            (student.totalPresence / maxAttendanceCount * 100).toStringAsFixed(1);

        // Look up email from current session records
        final email = currentSessionRecords
            .firstWhere(
              (r) => r.matricule == student.matricule,
              orElse: () => AttendanceRecord(
                id: '', sessionId: '', studentId: '',
                matricule: '', studentName: '',
                joinedAt: DateTime.now(),
                connectionDurationMinutes: 0,
                isVerified: false,
                deviceFingerprint: '',
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ),
            )
            .email;

        _addCell(sheet, currentRow, 0, student.matricule);
        _addCell(sheet, currentRow, 1, student.name);
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
