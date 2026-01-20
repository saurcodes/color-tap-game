import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Save user score
  Future<void> saveScore({
    required String userId,
    required String userName,
    required int score,
    required int level,
  }) async {
    try {
      await _db.collection('scores').add({
        'userId': userId,
        'userName': userName,
        'score': score,
        'level': level,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error saving score: $e');
    }
  }

  // Get user's best score
  Future<int> getUserBestScore(String userId) async {
    try {
      final snapshot = await _db
          .collection('scores')
          .where('userId', isEqualTo: userId)
          .orderBy('score', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return 0;
      return snapshot.docs.first.data()['score'] as int;
    } catch (e) {
      print('Error getting user best score: $e');
      return 0;
    }
  }

  // Get top scores (leaderboard)
  Stream<List<Map<String, dynamic>>> getTopScores({int limit = 10}) {
    return _db
        .collection('scores')
        .orderBy('score', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {
                  'userName': doc.data()['userName'],
                  'score': doc.data()['score'],
                  'level': doc.data()['level'],
                })
            .toList());
  }
}
