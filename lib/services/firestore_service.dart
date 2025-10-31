import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/mcq.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 🔹 Add MCQ (User-specific or general collection)
  Future<void> addMCQ(MCQ mcq) async {
    await _firestore
        .collection('mcqs')
        .doc(mcq.id?.toString()) // ID could be null, convert to string
        .set(mcq.toMap());
  }

  // 🔹 Update MCQ
  Future<void> updateMCQ(MCQ mcq) async {
    if (mcq.id == null) return; // ID required to update
    await _firestore
        .collection('mcqs')
        .doc(mcq.id.toString())
        .update(mcq.toMap());
  }

  // 🔹 Delete MCQ
  Future<void> deleteMCQ(int id) async {
    await _firestore.collection('mcqs').doc(id.toString()).delete();
  }

  // 🔹 Get all MCQs
  Future<List<MCQ>> getAllMCQs() async {
    final snapshot = await _firestore.collection('mcqs').get();
    return snapshot.docs.map((doc) => MCQ.fromMap(doc.data())).toList();
  }

  // 🔹 Get MCQs by course
  Future<List<MCQ>> getMCQsByCourse(String course) async {
    final snapshot = await _firestore
        .collection('mcqs')
        .where('course', isEqualTo: course)
        .get();
    return snapshot.docs.map((doc) => MCQ.fromMap(doc.data())).toList();
  }
}
