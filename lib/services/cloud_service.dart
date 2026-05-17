import 'dart:typed_data';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/session.dart';
import '../models/attendance_record.dart';

/// Service for Firebase Cloud integration
/// Handles authentication, Firestore CRUD, and Storage operations
class CloudService {
  static final CloudService _instance = CloudService._internal();
  factory CloudService() => _instance;
  CloudService._internal();

  bool _initialized = false;

  // Getters for Firebase instances
  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  FirebaseStorage get _storage => FirebaseStorage.instance;

  /// Current logged-in user
  User? get currentUser => _auth.currentUser;

  /// Check if a user is signed in
  bool get isSignedIn => currentUser != null;

  /// Initialize Firebase (call in main.dart before runApp)
  Future<void> initialize() async {
    if (_initialized) return;

    await Firebase.initializeApp();

    // Enable offline persistence for Firestore
    _firestore.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );

    _initialized = true;
    print('[CloudService] Firebase initialized successfully');
  }

  // ==================== AUTHENTICATION ====================

  /// Sign in with email and password
  Future<UserCredential> signIn(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      print('[CloudService] Signed in: ${credential.user?.uid}');
      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    }
  }

  /// Create a new lecturer account
  Future<UserCredential> signUp(
    String email,
    String password, {
    String? displayName,
    String? department,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update profile
      if (displayName != null) {
        await credential.user?.updateDisplayName(displayName);
      }

      // Create lecturer document in Firestore
      await _firestore.collection('lecturers').doc(credential.user?.uid).set({
        'uid': credential.user?.uid,
        'email': email,
        'displayName': displayName ?? '',
        'department': department ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      });

      print('[CloudService] Account created: ${credential.user?.uid}');
      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    }
  }

  /// Sign out current user
  Future<void> signOut() async {
    await _auth.signOut();
    print('[CloudService] Signed out');
  }

  /// Send password reset email
  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  /// Get current lecturer profile from Firestore
  Future<Map<String, dynamic>?> getLecturerProfile() async {
    final uid = currentUser?.uid;
    if (uid == null) return null;

    final doc = await _firestore.collection('lecturers').doc(uid).get();
    return doc.data();
  }

  // ==================== SESSION SYNC ====================

  /// Push a session to Firestore
  Future<void> syncSession(AttendanceSession session) async {
    final uid = currentUser?.uid;
    if (uid == null) throw Exception('Not signed in');

    final sessionRef = _firestore
        .collection('lecturers')
        .doc(uid)
        .collection('sessions')
        .doc(session.id);

    await sessionRef.set({
      'id': session.id,
      'courseName': session.courseName,
      'courseCode': session.courseCode,
      'lecturerId': session.lecturerId,
      'lecturerName': session.lecturerName,
      'sessionPin': session.sessionPin,
      'sessionToken': session.sessionToken,
      'sessionNumber': session.sessionNumber,
      'startTime': Timestamp.fromDate(session.startTime),
      'endTime': session.endTime != null
          ? Timestamp.fromDate(session.endTime!)
          : null,
      'durationMinutes': session.durationMinutes,
      'requiredConnectionMinutes': session.requiredConnectionMinutes,
      'gracePeriodMinutes': session.gracePeriodMinutes,
      'isActive': session.isActive,
      'totalAttendees': 0,
      'verifiedCount': 0,
      'createdAt': Timestamp.fromDate(session.createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    print('[CloudService] Session synced: ${session.id}');
  }

  /// Update session metadata (e.g., attendee counts)
  Future<void> updateSessionStats(
    String sessionId, {
    int? totalAttendees,
    int? verifiedCount,
    bool? isActive,
    DateTime? endTime,
  }) async {
    final uid = currentUser?.uid;
    if (uid == null) throw Exception('Not signed in');

    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (totalAttendees != null) updates['totalAttendees'] = totalAttendees;
    if (verifiedCount != null) updates['verifiedCount'] = verifiedCount;
    if (isActive != null) updates['isActive'] = isActive;
    if (endTime != null) updates['endTime'] = Timestamp.fromDate(endTime);

    await _firestore
        .collection('lecturers')
        .doc(uid)
        .collection('sessions')
        .doc(sessionId)
        .update(updates);
  }

  /// Push an attendance record to Firestore
  Future<void> syncAttendanceRecord(
    String sessionId,
    AttendanceRecord record,
  ) async {
    final uid = currentUser?.uid;
    if (uid == null) throw Exception('Not signed in');

    final recordRef = _firestore
        .collection('lecturers')
        .doc(uid)
        .collection('sessions')
        .doc(sessionId)
        .collection('records')
        .doc(record.id);

    final data = {
      'id': record.id,
      'sessionId': record.sessionId,
      'studentId': record.studentId,
      'matricule': record.matricule,
      'studentName': record.studentName,
      'email': record.email,
      'joinedAt': Timestamp.fromDate(record.joinedAt),
      'verifiedAt': record.verifiedAt != null
          ? Timestamp.fromDate(record.verifiedAt!)
          : null,
      'connectionDurationMinutes': record.connectionDurationMinutes,
      'isVerified': record.isVerified,
      'isManual': record.isManual,
      'deviceFingerprint': record.deviceFingerprint,
      'createdAt': Timestamp.fromDate(record.createdAt),
      'updatedAt': Timestamp.fromDate(record.updatedAt),
    };

    // Add location data if available
    if (record.location != null) {
      data['location'] = {
        'latitude': record.location!.latitude,
        'longitude': record.location!.longitude,
        'accuracy': record.location!.accuracy,
        'address': record.location!.address,
        'timestamp': record.location!.timestamp != null
            ? Timestamp.fromDate(record.location!.timestamp!)
            : null,
      };
    }

    await recordRef.set(data);
    print('[CloudService] Record synced: ${record.id}');
  }

  /// Delete a session and all its records from Firestore
  Future<void> deleteSession(String sessionId) async {
    final uid = currentUser?.uid;
    if (uid == null) throw Exception('Not signed in');

    // Delete all records first
    final recordsSnapshot = await _firestore
        .collection('lecturers')
        .doc(uid)
        .collection('sessions')
        .doc(sessionId)
        .collection('records')
        .get();

    final batch = _firestore.batch();
    for (final doc in recordsSnapshot.docs) {
      batch.delete(doc.reference);
    }

    // Delete session document
    final sessionRef = _firestore
        .collection('lecturers')
        .doc(uid)
        .collection('sessions')
        .doc(sessionId);
    batch.delete(sessionRef);

    await batch.commit();
    print('[CloudService] Session deleted: $sessionId');
  }

  // ==================== FETCH FROM CLOUD ====================

  /// Fetch all sessions for the current lecturer
  Future<List<Map<String, dynamic>>> fetchSessions() async {
    final uid = currentUser?.uid;
    if (uid == null) throw Exception('Not signed in');

    final snapshot = await _firestore
        .collection('lecturers')
        .doc(uid)
        .collection('sessions')
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      // Convert Timestamps to ISO strings for consistency
      _convertTimestamps(data);
      return data;
    }).toList();
  }

  /// Fetch attendance records for a specific session
  Future<List<Map<String, dynamic>>> fetchRecords(String sessionId) async {
    final uid = currentUser?.uid;
    if (uid == null) throw Exception('Not signed in');

    final snapshot = await _firestore
        .collection('lecturers')
        .doc(uid)
        .collection('sessions')
        .doc(sessionId)
        .collection('records')
        .orderBy('joinedAt')
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      _convertTimestamps(data);
      // Also convert nested location timestamps
      if (data['location'] != null) {
        _convertTimestamps(data['location'] as Map<String, dynamic>);
      }
      return data;
    }).toList();
  }

  /// Stream real-time session updates
  Stream<List<Map<String, dynamic>>> streamSessions() {
    final uid = currentUser?.uid;
    if (uid == null) throw Exception('Not signed in');

    return _firestore
        .collection('lecturers')
        .doc(uid)
        .collection('sessions')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              _convertTimestamps(data);
              return data;
            }).toList());
  }

  /// Stream real-time records for a session
  Stream<List<Map<String, dynamic>>> streamRecords(String sessionId) {
    final uid = currentUser?.uid;
    if (uid == null) throw Exception('Not signed in');

    return _firestore
        .collection('lecturers')
        .doc(uid)
        .collection('sessions')
        .doc(sessionId)
        .collection('records')
        .orderBy('joinedAt')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              _convertTimestamps(data);
              if (data['location'] != null) {
                _convertTimestamps(data['location'] as Map<String, dynamic>);
              }
              return data;
            }).toList());
  }

  // ==================== STORAGE (EXPORTS) ====================

  /// Upload a PDF or Excel file to Firebase Storage
  Future<String> uploadExport(
    Uint8List fileBytes,
    String filename, {
    String? sessionId,
  }) async {
    final uid = currentUser?.uid;
    if (uid == null) throw Exception('Not signed in');

    final path = 'lecturers/$uid/exports/$filename';
    final ref = _storage.ref().child(path);

    final metadata = SettableMetadata(
      contentType: filename.endsWith('.pdf') ? 'application/pdf' : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      customMetadata: {
        'sessionId': sessionId ?? '',
        'uploadedBy': uid,
        'uploadedAt': DateTime.now().toIso8601String(),
      },
    );

    final uploadTask = ref.putData(fileBytes, metadata);
    final snapshot = await uploadTask;
    final downloadUrl = await snapshot.ref.getDownloadURL();

    print('[CloudService] Export uploaded: $downloadUrl');
    return downloadUrl;
  }

  /// List all exports for the current lecturer
  Future<List<Map<String, dynamic>>> listExports() async {
    final uid = currentUser?.uid;
    if (uid == null) throw Exception('Not signed in');

    final listResult = await _storage
        .ref()
        .child('lecturers/$uid/exports')
        .listAll();

    final exports = <Map<String, dynamic>>[];
    for (final item in listResult.items) {
      final url = await item.getDownloadURL();
      final meta = await item.getMetadata();
      exports.add({
        'name': item.name,
        'url': url,
        'size': meta.size,
        'updated': meta.updated?.toIso8601String(),
      });
    }

    return exports;
  }

  /// Download an export file from Storage
  Future<Uint8List> downloadExport(String filename) async {
    final uid = currentUser?.uid;
    if (uid == null) throw Exception('Not signed in');

    final ref = _storage.ref().child('lecturers/$uid/exports/$filename');
    return await ref.getData() ?? Uint8List(0);
  }

  // ==================== SYNC QUEUE (OFFLINE SUPPORT) ====================

  /// Batch sync a complete session with all records to cloud
  /// Call this when ending a session or when coming back online
  Future<void> fullSessionSync(
    AttendanceSession session,
    List<AttendanceRecord> records,
  ) async {
    final uid = currentUser?.uid;
    if (uid == null) {
      print('[CloudService] Not signed in, skipping cloud sync');
      return;
    }

    try {
      // Sync session first
      await syncSession(session);

      // Batch write records
      final batch = _firestore.batch();
      final sessionRef = _firestore
          .collection('lecturers')
          .doc(uid)
          .collection('sessions')
          .doc(session.id);

      for (final record in records) {
        final recordRef = sessionRef.collection('records').doc(record.id);
        final data = _recordToFirestoreData(record);
        batch.set(recordRef, data);
      }

      // Update session stats
      final verifiedCount = records.where((r) => r.isVerified).length;
      batch.update(sessionRef, {
        'totalAttendees': records.length,
        'verifiedCount': verifiedCount,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      print('[CloudService] Full session sync completed: ${session.id} '
          '(${records.length} records)');
    } catch (e) {
      print('[CloudService] Full sync failed: $e');
      // Data remains in local storage; will retry on next sync
      rethrow;
    }
  }

  // ==================== HELPERS ====================

  /// Convert an AttendanceRecord to Firestore-compatible map
  Map<String, dynamic> _recordToFirestoreData(AttendanceRecord record) {
    final data = <String, dynamic>{
      'id': record.id,
      'sessionId': record.sessionId,
      'studentId': record.studentId,
      'matricule': record.matricule,
      'studentName': record.studentName,
      'email': record.email,
      'joinedAt': Timestamp.fromDate(record.joinedAt),
      'verifiedAt': record.verifiedAt != null
          ? Timestamp.fromDate(record.verifiedAt!)
          : null,
      'connectionDurationMinutes': record.connectionDurationMinutes,
      'isVerified': record.isVerified,
      'isManual': record.isManual,
      'deviceFingerprint': record.deviceFingerprint,
      'createdAt': Timestamp.fromDate(record.createdAt),
      'updatedAt': Timestamp.fromDate(record.updatedAt),
    };

    if (record.location != null) {
      data['location'] = {
        'latitude': record.location!.latitude,
        'longitude': record.location!.longitude,
        'accuracy': record.location!.accuracy,
        'address': record.location!.address,
        'timestamp': record.location!.timestamp != null
            ? Timestamp.fromDate(record.location!.timestamp!)
            : null,
      };
    }

    return data;
  }

  /// Convert Firestore Timestamps to ISO strings recursively
  void _convertTimestamps(Map<String, dynamic> data) {
    for (final key in data.keys.toList()) {
      final value = data[key];
      if (value is Timestamp) {
        data[key] = value.toDate().toIso8601String();
      } else if (value is Map<String, dynamic>) {
        _convertTimestamps(value);
      }
    }
  }

  /// Handle Firebase Auth errors with user-friendly messages
  Exception _handleAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return Exception('No account found with this email.');
      case 'wrong-password':
        return Exception('Incorrect password.');
      case 'email-already-in-use':
        return Exception('An account already exists with this email.');
      case 'weak-password':
        return Exception('Password is too weak. Use at least 6 characters.');
      case 'invalid-email':
        return Exception('Invalid email address.');
      case 'network-request-failed':
        return Exception('Network error. Check your internet connection.');
      default:
        return Exception('Authentication failed: ${e.message}');
    }
  }
}
