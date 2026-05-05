import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/session.dart';
import '../models/attendance_record.dart';

class PdfService {
  /// Generates an attendance PDF report.
  ///
  /// [previousAttendance] is a map of **matricule → cumulative mark** from
  /// previous sessions. When a student in [records] has a matching matricule
  /// and is verified, their cumulative mark becomes `previous + 1`.
  ///
  /// [signatureBytes] is an optional PNG image of the lecturer's digital
  /// signature, embedded at the bottom of the report.
  static Future<Uint8List> generateAttendancePDF({
    required AttendanceSession session,
    required List<AttendanceRecord> records,
    Map<String, int>? previousAttendance,
    Uint8List? signatureBytes,
    String? lecturerName,
    int sessionNumber = 1,
  }) async {
    final pdf = pw.Document();
    final hasPreviousData = previousAttendance != null && previousAttendance.isNotEmpty;
    final hasSignature = signatureBytes != null && signatureBytes.isNotEmpty;
    final hasLecturerName = lecturerName != null && lecturerName.isNotEmpty;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) => [
          // Header
          pw.Header(
            level: 0,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(
                  '${session.courseName} Attendance Report',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                if (session.courseCode != null)
                  pw.Text(
                    'Course Code: ${session.courseCode}',
                    style: pw.TextStyle(
                      fontSize: 14,
                      color: PdfColors.grey700,
                    ),
                  ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          // Session Info
          pw.Text(
            'Course: ${session.courseName}',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            'Session Date: ${session.startTime.toString().substring(0, 16)}',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            'Duration Required: ${session.requiredConnectionMinutes} min',
            style: pw.TextStyle(fontSize: 14),
          ),
          if (hasPreviousData)
            pw.Text(
              'T.P $sessionNumber',
              style: pw.TextStyle(
                fontSize: 14,
                color: PdfColors.blue900,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          if (hasPreviousData)
            pw.Text(
              'Previous Session Data: Uploaded',
              style: pw.TextStyle(
                fontSize: 12,
                color: PdfColors.green700,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          pw.SizedBox(height: 20),

          // Daily Snapshot Table
          _buildDailySnapshotTable(records, hasPreviousData, previousAttendance),

          pw.SizedBox(height: 20),

          // Summary Section
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
              children: [
                _buildSummaryItem('Total Students', records.length.toString()),
                _buildSummaryItem(
                  'Verified',
                  records.where((r) => r.isVerified).length.toString(),
                ),
                _buildSummaryItem(
                  'Pending',
                  records.where((r) => !r.isVerified).length.toString(),
                ),
              ],
            ),
          ),

          // Master Roster with Cumulative Marks (if previous data exists)
          if (hasPreviousData) ...[
            pw.SizedBox(height: 30),
            pw.Header(
              level: 1,
              child: pw.Text(
                'MASTER ROSTER - Cumulative Attendance',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue900,
                ),
              ),
            ),
            pw.SizedBox(height: 10),
            _buildMasterRosterTable(records, previousAttendance, session.maxAttendanceCount),
          ],

          // T.P Table (if previous data exists)
          if (hasPreviousData) ...[
            pw.SizedBox(height: 30),
            pw.Header(
              level: 1,
              child: pw.Text(
                'T.P $sessionNumber - Total Presence',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue900,
                ),
              ),
            ),
            pw.SizedBox(height: 10),
            _buildTPTable(records, previousAttendance, session.maxAttendanceCount),
          ],

          pw.SizedBox(height: 30),

          // Signature Section
          if (hasSignature || hasLecturerName) ...[
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  if (hasLecturerName) ...[
                    pw.Text(
                      lecturerName,
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                  ],
                  if (hasSignature) ...[
                    pw.Container(
                      width: 150,
                      height: 60,
                      child: pw.Image(
                        pw.MemoryImage(signatureBytes),
                        fit: pw.BoxFit.contain,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Container(
                      width: 150,
                      height: 1,
                      color: PdfColors.black,
                    ),
                    pw.SizedBox(height: 4),
                  ],
                  pw.Text(
                    'Lecturer Signature',
                    style: pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
          ],

          // Footer
          pw.Container(
            alignment: pw.Alignment.center,
            child: pw.Text(
              'Generated by Hotspot Attendance System',
              style: pw.TextStyle(
                fontSize: 10,
                color: PdfColors.grey,
                fontStyle: pw.FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildDailySnapshotTable(
    List<AttendanceRecord> records,
    bool hasPreviousData,
    Map<String, int>? previousAttendance,
  ) {
    // Tighter column widths to fit everything on A4 with smaller padding
    final columnWidths = hasPreviousData
        ? {
            0: const pw.FlexColumnWidth(2.0),   // Student Name
            1: const pw.FlexColumnWidth(1.2),   // Matricule
            2: const pw.FlexColumnWidth(2.4),   // Email (wider for long emails)
            3: const pw.FlexColumnWidth(0.5),   // Status (small circle)
            4: const pw.FlexColumnWidth(0.8),   // Joined At
            5: const pw.FlexColumnWidth(0.8),   // Duration
            6: const pw.FlexColumnWidth(0.8),   // Cumulative
          }
        : {
            0: const pw.FlexColumnWidth(2.2),   // Student Name
            1: const pw.FlexColumnWidth(1.3),   // Matricule
            2: const pw.FlexColumnWidth(2.6),   // Email (wider for long emails)
            3: const pw.FlexColumnWidth(0.5),   // Status (small circle)
            4: const pw.FlexColumnWidth(0.9),   // Joined At
            5: const pw.FlexColumnWidth(0.9),   // Duration
          };

    final headers = hasPreviousData
        ? ['Student Name', 'Matricule', 'Email', '', 'Joined', 'Dur.', 'Cum.']
        : ['Student Name', 'Matricule', 'Email', '', 'Joined', 'Dur.'];

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: columnWidths,
      children: [
        // Table Header
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.blue900),
          children: headers.map((h) => _buildHeaderCell(h)).toList(),
        ),
        // Data Rows
        ...records.map((record) {
          final cells = [
            _buildCompactDataCell(record.studentName),
            _buildCompactDataCell(record.matricule),
            _buildEmailCell(record.email),
            _buildStatusCircle(record.isVerified, record.isManual),
            _buildCompactDataCell(
              '${record.joinedAt.hour.toString().padLeft(2, '0')}:${record.joinedAt.minute.toString().padLeft(2, '0')}',
            ),
            _buildCompactDataCell('${record.connectionDurationMinutes}m'),
          ];

          if (hasPreviousData && previousAttendance != null) {
            final previousTotal = previousAttendance[record.matricule] ?? 0;
            final cumulative = record.isVerified ? previousTotal + 1 : previousTotal;
            cells.add(_buildCompactDataCell(cumulative.toString(), bold: record.isVerified));
          }

          return pw.TableRow(children: cells);
        }),
        // Total row
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.blue50),
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Text(
                'Total: ${records.length}',
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue900,
                ),
              ),
            ),
            ...List.generate(
              hasPreviousData ? 6 : 5,
              (_) => pw.SizedBox.shrink(),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildMasterRosterTable(
    List<AttendanceRecord> records,
    Map<String, int> previousAttendance,
    int maxAttendanceCount,
  ) {
    // Build master list
    final masterList = <String, _MasterRosterEntry>{};

    // Add all previous attendance entries
    previousAttendance.forEach((matricule, total) {
      masterList[matricule] = _MasterRosterEntry(
        matricule: matricule,
        name: '',
        previousTotal: total,
        newTotal: total,
      );
    });

    // Process current records
    for (final record in records) {
      final previousTotal = previousAttendance[record.matricule] ?? 0;
      final newTotal = record.isVerified
          ? (previousTotal + 1).clamp(0, maxAttendanceCount)
          : previousTotal;

      masterList[record.matricule] = _MasterRosterEntry(
        matricule: record.matricule,
        name: record.studentName,
        previousTotal: previousTotal,
        newTotal: newTotal,
      );
    }

    final sortedList = masterList.values.toList()
      ..sort((a, b) => a.matricule.compareTo(b.matricule));

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(1.5), // Matricule
        1: const pw.FlexColumnWidth(2.5), // Name
        2: const pw.FlexColumnWidth(1.0), // Previous
        3: const pw.FlexColumnWidth(1.0), // New Total
        4: const pw.FlexColumnWidth(0.8), // Change
        5: const pw.FlexColumnWidth(0.8), // Percentage
      },
      children: [
        // Header
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.blue900),
          children: [
            _buildHeaderCell('Matricule'),
            _buildHeaderCell('Name'),
            _buildHeaderCell('Prev.'),
            _buildHeaderCell('New'),
            _buildHeaderCell('+/-'),
            _buildHeaderCell('%'),
          ],
        ),
        // Data rows
        ...sortedList.map((entry) {
          final change = entry.newTotal - entry.previousTotal;
          final percentage = maxAttendanceCount > 0
              ? (entry.newTotal / maxAttendanceCount * 100).toStringAsFixed(1)
              : '0.0';

          return pw.TableRow(
            children: [
              _buildCompactDataCell(entry.matricule),
              _buildCompactDataCell(entry.name.isNotEmpty ? entry.name : 'N/A'),
              _buildCompactDataCell(entry.previousTotal.toString()),
              _buildCompactDataCell(entry.newTotal.toString(), bold: true),
              _buildChangeCell(change),
              _buildCompactDataCell('$percentage%'),
            ],
          );
        }),
        // Total row
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.blue50),
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Text(
                'Total: ${sortedList.length}',
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue900,
                ),
              ),
            ),
            ...List.generate(5, (_) => pw.SizedBox.shrink()),
          ],
        ),
      ],
    );
  }

  /// Build the T.P (Total Presence) table showing cumulative attendance
  /// new t.p = old t.p + 1 for verified students
  static pw.Widget _buildTPTable(
    List<AttendanceRecord> records,
    Map<String, int> previousAttendance,
    int maxAttendanceCount,
  ) {
    // Build list combining previous and current attendance
    final tpList = <String, _MasterRosterEntry>{};

    // Add all previous attendance entries
    previousAttendance.forEach((matricule, total) {
      tpList[matricule] = _MasterRosterEntry(
        matricule: matricule,
        name: '',
        previousTotal: total,
        newTotal: total,
      );
    });

    // Process current records: new t.p = old t.p + 1 if verified
    for (final record in records) {
      final previousTotal = previousAttendance[record.matricule] ?? 0;
      final newTotal = record.isVerified
          ? (previousTotal + 1).clamp(0, maxAttendanceCount)
          : previousTotal;

      tpList[record.matricule] = _MasterRosterEntry(
        matricule: record.matricule,
        name: record.studentName,
        previousTotal: previousTotal,
        newTotal: newTotal,
      );
    }

    final sortedList = tpList.values.toList()
      ..sort((a, b) => a.matricule.compareTo(b.matricule));

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(1.5), // Matricule
        1: const pw.FlexColumnWidth(3.0), // Name
        2: const pw.FlexColumnWidth(1.0), // T.P
        3: const pw.FlexColumnWidth(1.0), // Percentage
      },
      children: [
        // Header
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.blue900),
          children: [
            _buildHeaderCell('Matricule'),
            _buildHeaderCell('Name'),
            _buildHeaderCell('T.P'),
            _buildHeaderCell('%'),
          ],
        ),
        // Data rows
        ...sortedList.map((entry) {
          final percentage = maxAttendanceCount > 0
              ? (entry.newTotal / maxAttendanceCount * 100).toStringAsFixed(1)
              : '0.0';

          return pw.TableRow(
            children: [
              _buildCompactDataCell(entry.matricule),
              _buildCompactDataCell(entry.name.isNotEmpty ? entry.name : 'N/A'),
              _buildCompactDataCell(entry.newTotal.toString(), bold: true),
              _buildCompactDataCell('$percentage%'),
            ],
          );
        }),
        // Total row
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.blue50),
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Text(
                'Total: ${sortedList.length}',
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue900,
                ),
              ),
            ),
            ...List.generate(3, (_) => pw.SizedBox.shrink()),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildHeaderCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
          fontSize: 9,
        ),
      ),
    );
  }

  static pw.Widget _buildCompactDataCell(String text, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  /// Dedicated email cell with smaller font and text wrapping to fit long addresses
  static pw.Widget _buildEmailCell(String? email) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: pw.Text(
        email ?? 'N/A',
        style: const pw.TextStyle(fontSize: 7),
        softWrap: true,
      ),
    );
  }

  /// Simple colored circle for status: green=verified, orange=pending, grey=manual
  static pw.Widget _buildStatusCircle(bool isVerified, bool isManual) {
    final PdfColor color;
    if (isManual) {
      color = PdfColors.grey400;
    } else if (isVerified) {
      color = PdfColors.green600;
    } else {
      color = PdfColors.orange600;
    }

    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Center(
        child: pw.Container(
          width: 12,
          height: 12,
          decoration: pw.BoxDecoration(
            color: color,
            shape: pw.BoxShape.circle,
          ),
        ),
      ),
    );
  }

  static pw.Widget _buildChangeCell(int change) {
    final color = change > 0
        ? PdfColors.green800
        : change < 0
            ? PdfColors.red800
            : PdfColors.grey700;
    final bgColor = change > 0
        ? PdfColors.green100
        : change < 0
            ? PdfColors.red100
            : PdfColors.grey100;

    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: pw.BoxDecoration(
          color: bgColor,
          borderRadius: pw.BorderRadius.circular(3),
        ),
        child: pw.Text(
          change > 0 ? '+$change' : change.toString(),
          style: pw.TextStyle(
            fontSize: 8,
            color: color,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ),
    );
  }

  static pw.Widget _buildSummaryItem(String label, String value) {
    return pw.Column(
      children: [
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 18,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blue900,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
        ),
      ],
    );
  }
}

/// Internal data class for master roster entries
class _MasterRosterEntry {
  final String matricule;
  final String name;
  final int previousTotal;
  final int newTotal;

  _MasterRosterEntry({
    required this.matricule,
    required this.name,
    required this.previousTotal,
    required this.newTotal,
  });
}
