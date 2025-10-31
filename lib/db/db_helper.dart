import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/mcq.dart';
import '../services/firebase_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DBHelper {
  static final DBHelper _instance = DBHelper._internal();
  factory DBHelper() => _instance;
  DBHelper._internal();

  static Database? _database;
  final FirebaseService firebaseService = FirebaseService();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'mcq_questions.db');
    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE questions ADD COLUMN questionNumber INTEGER;');
          await db.execute('UPDATE questions SET questionNumber = id;');
        }
      },
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE questions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        course TEXT NOT NULL,
        question TEXT NOT NULL,
        option_A TEXT,
        option_B TEXT,
        option_C TEXT,
        option_D TEXT,
        answer TEXT NOT NULL,
        userId TEXT,
        questionNumber INTEGER,
        isDeleted INTEGER DEFAULT 0
      )
    ''');
  }

  // ================= Check Duplicate =================
  Future<bool> isDuplicate(MCQ mcq, {int? excludeId}) async {
    final db = await database;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final course = mcq.course.trim().toLowerCase();
    final question = mcq.question.trim().toLowerCase();

    final existing = await db.query(
      'questions',
      where: excludeId != null
          ? 'LOWER(course) = ? AND LOWER(question) = ? AND userId = ? AND id != ?'
          : 'LOWER(course) = ? AND LOWER(question) = ? AND userId = ?',
      whereArgs: excludeId != null
          ? [course, question, user.uid, excludeId]
          : [course, question, user.uid],
    );

    return existing.isNotEmpty;
  }

  // ================= Insert Question =================
  Future<int> insertQuestion(MCQ mcq, {bool ignoreDuplicate = true, bool syncFirebase = true}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return -1;

    if (mcq.course.trim().isEmpty || mcq.question.trim().isEmpty || mcq.answer.trim().isEmpty) return -2;

    mcq.userId = user.uid;
    mcq.isDeleted = 0;

    final duplicate = await isDuplicate(mcq);
    if (duplicate) {
      return ignoreDuplicate ? 0 : -1;
    }

    final db = await database;

    // assign questionNumber
    if (mcq.questionNumber == null) {
      final maxNumber = await db.rawQuery(
        'SELECT MAX(questionNumber) as maxQ FROM questions WHERE userId = ?',
        [user.uid],
      );
      final maxQ = (maxNumber.first['maxQ'] ?? 0) as int? ?? 0;
      mcq.questionNumber = maxQ + 1;
    }

    final id = await db.insert('questions', mcq.toMap());
    mcq.questionNumber ??= id;
    await db.update('questions', {'questionNumber': mcq.questionNumber}, where: 'id = ?', whereArgs: [id]);

    if (syncFirebase) {
      try {
        await firebaseService.addOrUpdateQuestion(mcq, user.uid);
      } catch (e) {
        print("Firebase sync failed: $e");
      }
    }

    return id;
  }

  // ================= Update Question =================
  Future<int> updateQuestion(MCQ mcq, {bool syncFirebase = true}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 0;

    if (mcq.course.trim().isEmpty || mcq.question.trim().isEmpty || mcq.answer.trim().isEmpty) return -2;

    mcq.userId = user.uid;

    final duplicate = await isDuplicate(mcq, excludeId: mcq.id);
    if (duplicate) return -1;

    final db = await database;
    final result = await db.update('questions', mcq.toMap(), where: 'id = ? AND userId = ?', whereArgs: [mcq.id, user.uid]);

    if (syncFirebase) {
      try {
        await firebaseService.updateQuestion(mcq, user.uid);
      } catch (e) {
        print("Firebase update failed: $e");
      }
    }

    return result;
  }

  // ================= Delete Question =================
  Future<int> deleteQuestion(int id) async {
    final db = await database;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 0;

    // 🔹 Get the question
    final resultQuery = await db.query(
      'questions',
      where: 'id = ? AND userId = ?',
      whereArgs: [id, user.uid],
    );
    if (resultQuery.isEmpty) return 0;
    final mcq = MCQ.fromMap(resultQuery.first);

    // 🔹 Delete from local DB
    final result = await db.delete(
      'questions',
      where: 'id = ? AND userId = ?',
      whereArgs: [id, user.uid],
    );

    // 🔹 Renumber remaining questions
    final remaining = await db.query(
      'questions',
      where: 'userId = ?',
      whereArgs: [user.uid],
      orderBy: 'questionNumber ASC',
    );
    for (int i = 0; i < remaining.length; i++) {
      final q = MCQ.fromMap(remaining[i]);
      q.questionNumber = i + 1;
      await updateQuestion(q, syncFirebase: false);
    }

    // 🔹 Safe delete from Firestore
    await safeDeleteFromFirestore(mcq.id!);

    // 🔹 Reindex Firestore to fix duplicate problem
    if (user != null) {
      final updatedList = await getAllQuestions(); // get latest after renumber
      await firebaseService.reindexQuestions(user.uid, updatedList);
      print("🔁 Firestore reindex after delete completed");
    }

    return result;
  }

  // ================= Delete from Firestore =================
  Future<void> deleteQuestionFromFirestore(int id) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('questions')
          .where('id', isEqualTo: id)
          .get();

      for (var doc in querySnapshot.docs) {
        await doc.reference.delete();
      }

      print("✅ Question $id deleted from Firestore");
    } catch (e) {
      print("❌ Firebase delete failed: $e");
    }
  }

  // ================= Safe delete helper =================
  Future<void> safeDeleteFromFirestore(int id) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      final colRef = userRef.collection('questions');

      final query = await colRef.where('id', isEqualTo: id).get();

      if (query.docs.isEmpty) {
        print("⚠️ No Firestore doc found for id=$id (already deleted or never synced)");
        return;
      }

      for (var doc in query.docs) {
        await doc.reference.delete();
        print("✅ Deleted Firestore doc: ${doc.id}");
      }
    } catch (e) {
      print("❌ Error in safeDeleteFromFirestore: $e");
    }
  }

  // ================= Fetch All Questions =================
  Future<List<MCQ>> getAllQuestions() async {
    final db = await database;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];
    final result = await db.query(
      'questions',
      where: 'userId = ? AND isDeleted = 0',
      whereArgs: [user.uid],
      orderBy: 'questionNumber ASC',
    );
    return result.map((e) => MCQ.fromMap(e)).toList();
  }

  Future<List<Map<String, dynamic>>> getAllQuestionsMap() async {
    final db = await database;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];
    return await db.query(
      'questions',
      where: 'userId = ? AND isDeleted = 0',
      whereArgs: [user.uid],
      orderBy: 'questionNumber ASC',
    );
  }

  Future<List<MCQ>> getQuestionsByCourse(String course, {int? limit}) async {
    final db = await database;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    String query = 'SELECT * FROM questions WHERE course = ? AND userId = ? AND isDeleted = 0 ORDER BY questionNumber ASC';
    List<dynamic> args = [course, user.uid];

    if (limit != null) {
      query += ' LIMIT ?';
      args.add(limit);
    }

    final result = await db.rawQuery(query, args);
    return result.map((e) => MCQ.fromMap(e)).toList();
  }

  Future<List<Map<String, dynamic>>> getCourseWiseMCQCount() async {
    final db = await database;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    return await db.rawQuery('''
      SELECT course, COUNT(*) as count
      FROM questions
      WHERE userId = ? AND isDeleted = 0
      GROUP BY course
      ORDER BY course ASC
    ''', [user.uid]);
  }

  // ================= Sync Local → Firebase =================
  Future<void> syncToFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final allQuestions = await getAllQuestions();

    final firestoreQuestions = await firebaseService.fetchQuestions(user.uid);
    final existingKeys = <String>{};

    for (var q in firestoreQuestions) {
      final key = '${q.course.trim().toLowerCase()}_${q.question.trim().toLowerCase()}';
      existingKeys.add(key);
    }

    for (var mcq in allQuestions) {
      if (mcq.course.isEmpty || mcq.question.isEmpty || mcq.answer.isEmpty) continue;

      final key = '${mcq.course.trim().toLowerCase()}_${mcq.question.trim().toLowerCase()}';

      if (existingKeys.contains(key)) {
        print("⏭️ Skipped duplicate: ${mcq.question}");
        continue;
      }

      try {
        await firebaseService.addOrUpdateQuestion(mcq, user.uid);
        existingKeys.add(key);
      } catch (e) {
        print("❌ Sync failed for question id ${mcq.id}: $e");
      }
    }

    print("✅ All local questions synced to Firestore successfully (no duplicates).");
  }

  // ================= Sync Firebase → Local =================
  Future<void> syncFromFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final firestoreQuestions = await firebaseService.fetchQuestions(user.uid);
      for (var mcq in firestoreQuestions) {
        if (mcq.course.isEmpty || mcq.question.isEmpty || mcq.answer.isEmpty) continue;
        await insertQuestion(mcq, ignoreDuplicate: true, syncFirebase: false);
      }
      print("All Firestore questions synced to local database successfully.");
    } catch (e) {
      print("Failed to sync from Firestore: $e");
    }
  }
}
