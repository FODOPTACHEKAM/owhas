import 'dart:convert';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';

/// Service for saving and loading the lecturer's digital signature and name.
/// Signature is stored as base64-encoded PNG bytes in SharedPreferences.
/// Lecturer name is stored as a plain string.
class SignatureService {
  static const String _signatureKey = 'lecturer_signature_png';
  static const String _lecturerNameKey = 'lecturer_name';
  static const String _sessionSignaturesKey = 'session_signatures';

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

  /// Generate a hash of the signature for uniqueness checking.
  static String generateSignatureHash(Uint8List pngBytes) {
    return sha256.convert(pngBytes).toString();
  }

  /// Check if a signature hash is already used in the current session.
  static Future<bool> isSignatureUsedInSession(String hash) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final signatures = prefs.getStringList(_sessionSignaturesKey) ?? [];
      return signatures.contains(hash);
    } catch (e) {
      return false;
    }
  }

  /// Add a signature hash to the session's used signatures.
  static Future<bool> addSignatureToSession(String hash) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final signatures = prefs.getStringList(_sessionSignaturesKey) ?? [];
      if (!signatures.contains(hash)) {
        signatures.add(hash);
        return await prefs.setStringList(_sessionSignaturesKey, signatures);
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Clear session signatures (call when starting a new session).
  static Future<bool> clearSessionSignatures() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.remove(_sessionSignaturesKey);
    } catch (e) {
      return false;
    }
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

