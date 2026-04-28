import 'dart:convert';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for saving and loading the lecturer's digital signature and name.
/// Signature is stored as base64-encoded PNG bytes in SharedPreferences.
/// Lecturer name is stored as a plain string.
class SignatureService {
  static const String _signatureKey = 'lecturer_signature_png';
  static const String _lecturerNameKey = 'lecturer_name';

  /// Save signature PNG bytes to persistent storage.
  static Future<bool> saveSignature(Uint8List pngBytes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final base64String = base64Encode(pngBytes);
      return await prefs.setString(_signatureKey, base64String);
    } catch (e) {
      return false;
    }
  }

  /// Load signature PNG bytes from persistent storage.
  /// Returns `null` if no signature has been saved.
  static Future<Uint8List?> loadSignature() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final base64String = prefs.getString(_signatureKey);
      if (base64String == null || base64String.isEmpty) return null;
      return base64Decode(base64String);
    } catch (e) {
      return null;
    }
  }

  /// Clear the saved signature from persistent storage.
  static Future<bool> clearSignature() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.remove(_signatureKey);
    } catch (e) {
      return false;
    }
  }

  /// Check whether a signature has been saved.
  static Future<bool> hasSignature() async {
    final bytes = await loadSignature();
    return bytes != null && bytes.isNotEmpty;
  }

  /// Save lecturer name to persistent storage.
  static Future<bool> saveLecturerName(String name) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(_lecturerNameKey, name.trim());
    } catch (e) {
      return false;
    }
  }

  /// Load lecturer name from persistent storage.
  /// Returns `null` if no name has been saved.
  static Future<String?> loadLecturerName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString(_lecturerNameKey);
      if (name == null || name.isEmpty) return null;
      return name;
    } catch (e) {
      return null;
    }
  }

  /// Clear the saved lecturer name from persistent storage.
  static Future<bool> clearLecturerName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.remove(_lecturerNameKey);
    } catch (e) {
      return false;
    }
  }

  /// Check whether a lecturer name has been saved.
  static Future<bool> hasLecturerName() async {
    final name = await loadLecturerName();
    return name != null && name.isNotEmpty;
  }
}

