import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TrialService {
  static final _db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get _trials =>
      _db.collection('trials');

  /// Can be called from anywhere:
  /// - TeamDetailScreen (owner -> player, with teamId & game)
  /// - Discover players (player -> player, no teamId, game optional)
  static Future<void> createTrial({
    required String targetUserUid,
    String? game, // <- now optional
    String? teamId,
    String? notes,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      throw Exception('Not logged in');
    }

    // don't allow trialing yourself
    if (currentUser.uid == targetUserUid) {
      throw Exception("You can't start a trial with yourself.");
    }

    final docRef = _trials.doc();

    await docRef.set({
      'id': docRef.id,
      'teamId': teamId,
      'ownerUid': currentUser.uid, // whoever created the trial
      'targetUid': targetUserUid, // player being trialed
      'game': game ?? '',
      'notes': notes ?? '',
      'status': 'pending', // pending | completed
      'result': null, // pass | fail | null
      'rating': null, // 1–5
      'feedback': '',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Trials where current user is the player
  static Stream<QuerySnapshot<Map<String, dynamic>>> trialsForPlayer(
    String uid,
  ) {
    return _trials
        .where('targetUid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Trials created by current user (owner/coach/player)
  static Stream<QuerySnapshot<Map<String, dynamic>>> trialsForOwner(
    String uid,
  ) {
    return _trials
        .where('ownerUid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Owner sets rating + pass/fail + feedback
  static Future<void> updateTrialResult({
    required String trialId,
    required int rating,
    required String result, // 'pass' or 'fail'
    String? feedback,
  }) async {
    await _trials.doc(trialId).update({
      'rating': rating,
      'result': result,
      'feedback': feedback ?? '',
      'status': 'completed',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
