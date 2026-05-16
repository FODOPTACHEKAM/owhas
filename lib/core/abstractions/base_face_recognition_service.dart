/// Contract for in-session face descriptor management.
///
/// Implementations keep descriptors in memory only — no disk writes.
/// This is a privacy invariant that must never be broken.
abstract class BaseFaceRecognitionService {
  /// Remove all face descriptors associated with [sessionId].
  /// Called when a session ends.
  void clearSession(String sessionId);

  /// Remove the descriptor for a specific student within a session.
  /// Called when a student is manually removed from the attendance list.
  void removeFace(String sessionId, String matricule);
}
