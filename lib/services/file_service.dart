import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Service for saving files locally and triggering native share dialogs
class FileService {
  /// Save PDF bytes to temporary storage and open the native share menu
  Future<void> saveAndSharePdf(Uint8List bytes, {String fileName = 'attendance_report'}) async {
    try {
      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/$fileName.pdf';
      final file = File(filePath);

      // Write bytes to local file
      await file.writeAsBytes(bytes, flush: true);

      // Trigger native share dialog
      await Share.shareXFiles(
        [XFile(filePath)],
        text: 'Student Attendance List',
        subject: 'Attendance Report',
      );
    } catch (e) {
      throw Exception('Failed to save or share PDF: $e');
    }
  }

  /// Save PDF bytes to device's Downloads folder (or Documents on iOS)
  Future<String?> savePdfToDevice(Uint8List bytes, {String fileName = 'attendance_report'}) async {
    try {
      Directory? directory;

      if (Platform.isAndroid) {
        // For Android, try to use Downloads directory
        directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) {
          // Fallback to app documents directory
          directory = await getExternalStorageDirectory();
        }
      } else {
        // For iOS and other platforms, use documents directory
        directory = await getApplicationDocumentsDirectory();
      }

      if (directory == null) {
        throw Exception('Could not access storage directory');
      }

      final filePath = '${directory.path}/$fileName.pdf';
      final file = File(filePath);

      // Write bytes to local file
      await file.writeAsBytes(bytes, flush: true);

      return filePath;
    } catch (e) {
      throw Exception('Failed to save PDF to device: $e');
    }
  }
}

