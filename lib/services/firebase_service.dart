import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/mcq.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Helper: Get stable docId based on questionNumber (preferred) or fallback to id
  String? _getDocId(MCQ mcq) {
    if (mcq.questionNumber != null) return mcq.questionNumber.toString();
    return mcq.id?.toString();
  }

  /// Add or Update Question in Firestore (safe: prevents duplicates)
  Future<void> addOrUpdateQuestion(MCQ mcq, String userId) async {
    if (mcq.course.trim().isEmpty || mcq.question.trim().isEmpty || mcq.answer.trim().isEmpty) {
      print("Skipping invalid MCQ: ${mcq.toMap()}");
      return;
    }

    final docId = _getDocId(mcq);
    if (docId == null) return;

    try {
      final data = mcq.toMap();
      data['isDeleted'] = mcq.isDeleted ?? 0;

      // ✅ merge:true ensures update without creating duplicate
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('questions')
          .doc(docId)
          .set(data, SetOptions(merge: true));

      print("✅ Firebase add/update successful: ${mcq.question}");
    } catch (e) {
      print("❌ Firebase addOrUpdateQuestion error: $e");
    }
  }

  /// Update Question
  Future<void> updateQuestion(MCQ mcq, String userId) async {
    final docId = _getDocId(mcq);
    if (docId == null) return;

    try {
      final data = mcq.toMap();
      data['isDeleted'] = mcq.isDeleted ?? 0;

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('questions')
          .doc(docId)
          .update(data);

      print("✅ Firebase update successful: ${mcq.question}");
    } catch (e) {
      print("❌ Firebase updateQuestion error: $e");
    }
  }

  /// Safe Delete Question (soft delete + remove duplicates + reindex)
  Future<void> deleteQuestion(MCQ mcq, String userId) async {
    final docId = _getDocId(mcq);
    if (docId == null) return;

    try {
      final colRef = _firestore.collection('users').doc(userId).collection('questions');

      // 🔹 Soft delete main doc
      final docRef = colRef.doc(docId);
      final docSnap = await docRef.get();
      if (docSnap.exists) {
        await docRef.update({'isDeleted': 1});
        print("🗑️ Soft deleted: ${mcq.question}");
      }

      // 🔹 Remove duplicate docs (if any)
      final dupQuery = await colRef.where('questionNumber', isEqualTo: mcq.questionNumber).get();
      if (dupQuery.docs.length > 1) {
        for (var i = 1; i < dupQuery.docs.length; i++) {
          await dupQuery.docs[i].reference.delete();
          print("🧹 Removed duplicate doc: ${dupQuery.docs[i].id}");
        }
      }

      // 🔹 Reindex remaining questions sequentially
      final snapshot = await colRef.where('isDeleted', isEqualTo: 0).orderBy('questionNumber').get();
      for (int i = 0; i < snapshot.docs.length; i++) {
        final doc = snapshot.docs[i];
        await doc.reference.update({'questionNumber': i + 1});
      }

      print("🔁 Firestore reindex completed after delete");
    } catch (e) {
      print("❌ Firebase deleteQuestion error: $e");
    }
  }

  /// Fetch all questions (isDeleted = 0)
  Future<List<MCQ>> fetchQuestions(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('questions')
          .where('isDeleted', isEqualTo: 0)
          .orderBy('questionNumber')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        if ((data['question'] ?? '').toString().trim().isEmpty ||
            (data['course'] ?? '').toString().trim().isEmpty ||
            (data['answer'] ?? '').toString().trim().isEmpty) return null;

        return MCQ.fromMap(data);
      }).whereType<MCQ>().toList();
    } catch (e) {
      print("❌ Firebase fetchQuestions error: $e");
      return [];
    }
  }

  /// Reindex questions after manual changes (update questionNumber sequentially)
  Future<void> reindexQuestions(String userId, List<MCQ> updatedQuestions) async {
    try {
      final batch = _firestore.batch();
      final colRef = _firestore.collection('users').doc(userId).collection('questions');

      for (final mcq in updatedQuestions) {
        final docId = _getDocId(mcq);
        if (docId == null) continue;
        batch.set(colRef.doc(docId), mcq.toMap(), SetOptions(merge: true));
      }

      await batch.commit();
      print("🔁 Firestore reindex successful (${updatedQuestions.length} updated)");
    } catch (e) {
      print("❌ Firebase reindexQuestions error: $e");
    }
  }
}
