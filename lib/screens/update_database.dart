import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/mcq.dart';
import '../db/db_helper.dart';
import '../services/custom_snackbar.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/firebase_service.dart';

class UpdateDatabaseScreen extends StatefulWidget {
  const UpdateDatabaseScreen({super.key});

  @override
  State<UpdateDatabaseScreen> createState() => _UpdateDatabaseScreenState();
}

class _UpdateDatabaseScreenState extends State<UpdateDatabaseScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> questions = [];
  final DBHelper _dbHelper = DBHelper();

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  // ================= Load Questions =================
  Future<void> _loadQuestions() async {
    setState(() => _loading = true);
    try {
      await _dbHelper.syncFromFirestore();
      final data = await _dbHelper.getAllQuestionsMap();
      if (!mounted) return;
    } catch (e) {
      debugPrint("❌ Firestore sync failed: $e");
    } finally {
      if (mounted) setState(() => _loading = false);


  // 🔹 fallback: local DB load
  final data = await _dbHelper.getAllQuestionsMap();
  if (!mounted) return;
  setState(() => questions = data);
  }
  }

  // ================= Sync After any Change =================
  Future<void> _syncAfterChange() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await _dbHelper.syncToFirestore();   // Local → Firebase
      await _dbHelper.syncFromFirestore(); // Firebase → Local
      final updatedList = await _dbHelper.getAllQuestionsMap();  // Refresh UI from local DB
      if (!mounted) return;
      setState(() => questions = updatedList);
    } catch (e) {
      debugPrint('❌ Auto Sync failed: $e');
    }
  }


  // ================= Add Question =================
  Future<void> _openAddQuestionDialog() async {
    final courseCtrl = TextEditingController();
    final qCtrl = TextEditingController();
    final aCtrl = TextEditingController();
    final bCtrl = TextEditingController();
    final cCtrl = TextEditingController();
    final dCtrl = TextEditingController();
    final ansCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('➕ Add New Question'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              _buildTextField(courseCtrl, 'Course', Icons.book),
              _buildTextField(qCtrl, 'Question', Icons.help_outline),
              _buildTextField(aCtrl, 'Option A', Icons.looks_one),
              _buildTextField(bCtrl, 'Option B', Icons.looks_two),
              _buildTextField(cCtrl, 'Option C', Icons.looks_3),
              _buildTextField(dCtrl, 'Option D', Icons.looks_4),
              _buildTextField(ansCtrl, 'Correct Answer', Icons.check_circle_outline),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Add'),
            onPressed: () async {
              final course = courseCtrl.text.trim();
              final question = qCtrl.text.trim();
              final answer = ansCtrl.text.trim();

              if (course.isEmpty || question.isEmpty || answer.isEmpty) {
                CustomSnackbar.show(context, "⚠️ Course, Question, and Answer cannot be empty!", backgroundColor: Colors.redAccent);
                return;
              }

              final newMcq = MCQ(
                course: course,
                question: question,
                optionA: aCtrl.text.trim(),
                optionB: bCtrl.text.trim(),
                optionC: cCtrl.text.trim(),
                optionD: dCtrl.text.trim(),
                answer: answer,
              );
              debugPrint("Adding MCQ: ${newMcq.toMap()}");

              // 🔹 Duplicate check local DB
              final isDup = await _dbHelper.isDuplicate(newMcq);

              if (isDup) {
                CustomSnackbar.show(context, "⚠️ This Question Already Exists!", backgroundColor: Colors.redAccent);
                return;
              }

              // 🔹 Insert local DB (offline safe)
              final result = await _dbHelper.insertQuestion(newMcq, ignoreDuplicate: false, syncFirebase: false);

              // 🔹 Refresh UI from local DB
              final updatedList = await _dbHelper.getAllQuestionsMap();
              if (!mounted) return;
              setState(() => questions = updatedList);

              // 🔹 Close dialog
              Navigator.pop(context);

              // 🔹 Snackbar message
              if (result > 0) {
                CustomSnackbar.show(context, "✅ Question Added Successfully!", backgroundColor: Colors.green);
              } else if (result == -2) {
                CustomSnackbar.show(context, "⚠️ Missing required fields!", backgroundColor: Colors.redAccent);
              }

              // 🔹 Background Firebase sync (optional)
              _syncAfterChange();
            },
          ),
        ],
      ),
    );
  }


  // ================= CSV Import =================
  Future<void> _importCSV() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );
      if (result == null) return;

      final path = result.files.single.path!;
      final mcqs = await compute(_parseCSVFile, path); // Heavy parsing in isolate

      if (mcqs.isEmpty) {
        CustomSnackbar.show(context, "⚠️ No valid questions found in CSV.", backgroundColor: Colors.redAccent);
        return;
      }

      // 🔹 Get current max question number once
      final allMaps = await _dbHelper.getAllQuestionsMap();
      int maxQ = allMaps.isNotEmpty
          ? allMaps.map((q) => q['questionNumber'] ?? 0)
          .map((e) => e is int ? e : int.tryParse(e.toString()) ?? 0)
          .reduce((a, b) => a > b ? a : b)
          : 0;

      int addedCount = 0;
      int skippedCount = 0;

      for (final mcq in mcqs) {
        // 🔹 Duplicate check
        final isDup = await _dbHelper.isDuplicate(mcq);
        if (isDup) {
          skippedCount++;
          continue;
        }

        maxQ++;
        mcq.questionNumber = maxQ;

        final res = await _dbHelper.insertQuestion(mcq, ignoreDuplicate: false, syncFirebase: false);
        if (res > 0) addedCount++;
      }

      // 🔹 Refresh UI from local DB
      final updatedList = await _dbHelper.getAllQuestionsMap();
      if (!mounted) return;
      setState(() => questions = updatedList);

      // 🔹 Close dialog if any
      Navigator.pop(context);

      // 🔹 Snackbar message
      CustomSnackbar.show(
        context,
        "✅ CSV Imported. $addedCount new questions added, $skippedCount duplicates skipped.",
        backgroundColor: Colors.green,
      );

      // 🔹 Background Firebase sync (optional)
      _syncAfterChange();

    } catch (e) {
      CustomSnackbar.show(context, "⚠️ CSV Import Failed: $e", backgroundColor: Colors.redAccent);
    }
  }

                  // CSV parsing function
  static List<MCQ> _parseCSVFile(String path) {
    final file = File(path);
    final lines = file.readAsLinesSync(encoding: utf8);
    final List<MCQ> mcqs = [];

    for (var i = 1; i < lines.length; i++) {
      final parts = lines[i].split(',');
      if (parts.length < 7) continue;

      final course = parts[0].trim();
      final question = parts[1].trim();
      final answer = parts[6].trim();

      if (course.isEmpty || question.isEmpty || answer.isEmpty) continue;

      mcqs.add(MCQ(
        course: course,
        question: question,
        optionA: parts[2].trim(),
        optionB: parts[3].trim(),
        optionC: parts[4].trim(),
        optionD: parts[5].trim(),
        answer: answer,
      ));
    }

    return mcqs;
  }


  // ================= Edit/Delete =================
  Future<void> _editQuestionDialog(Map<String, dynamic> q) async {
    final courseCtrl = TextEditingController(text: q['course']);
    final qCtrl = TextEditingController(text: q['question']);
    final aCtrl = TextEditingController(text: q['option_A']);
    final bCtrl = TextEditingController(text: q['option_B']);
    final cCtrl = TextEditingController(text: q['option_C']);
    final dCtrl = TextEditingController(text: q['option_D']);
    final ansCtrl = TextEditingController(text: q['answer']);
    final qNumCtrl = TextEditingController(text: (q['questionNumber'] ?? '').toString());

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('✏️ Edit Question'),
        content: SingleChildScrollView(
          child: Column(children: [
            _buildTextField(courseCtrl, 'Course', Icons.book),
            _buildTextField(qCtrl, 'Question', Icons.help_outline),
            _buildTextField(aCtrl, 'Option A', Icons.looks_one),
            _buildTextField(bCtrl, 'Option B', Icons.looks_two),
            _buildTextField(cCtrl, 'Option C', Icons.looks_3),
            _buildTextField(dCtrl, 'Option D', Icons.looks_4),
            _buildTextField(ansCtrl, 'Correct Answer', Icons.check_circle_outline),
            _buildTextField(qNumCtrl, 'Question Number', Icons.numbers, readOnly: true),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton.icon(
            icon: const Icon(Icons.save),
            label: const Text('Save'),
            onPressed: () async {
              final course = courseCtrl.text.trim();
              final question = qCtrl.text.trim();
              final answer = ansCtrl.text.trim();

              if (course.isEmpty || question.isEmpty || answer.isEmpty) {
                CustomSnackbar.show(context, "⚠️ Course, Question, and Answer cannot be empty!", backgroundColor: Colors.redAccent);
                return;
              }

              final updatedMcq = MCQ(
                id: q['id'],
                course: course,
                question: question,
                optionA: aCtrl.text.trim(),
                optionB: bCtrl.text.trim(),
                optionC: cCtrl.text.trim(),
                optionD: dCtrl.text.trim(),
                answer: answer,
                questionNumber: int.tryParse(qNumCtrl.text.trim()) ?? q['questionNumber'],
              );

              // 🔹 Duplicate check local DB
              final isDup = await _dbHelper.isDuplicate(updatedMcq, excludeId: updatedMcq.id);
              if (isDup) {
                CustomSnackbar.show(context, "⚠️ This Question Already Exists!", backgroundColor: Colors.redAccent);
                return;
              }

              // 🔹 Update local DB (offline safe)
              final result = await _dbHelper.updateQuestion(updatedMcq, syncFirebase: false);

              // 🔹 Refresh UI from local DB
              final updatedList = await _dbHelper.getAllQuestionsMap();
              if (!mounted) return;
              setState(() => questions = updatedList);

              Navigator.pop(context);

              // 🔹 Snackbar
              if (result > 0) {
                CustomSnackbar.show(context, "✅ Question Updated Successfully!", backgroundColor: Colors.green);
              } else {
                CustomSnackbar.show(context, "⚠️ Failed to update question!", backgroundColor: Colors.orange);
              }

              // 🔹 Background Firebase sync
              _syncAfterChange();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _deleteQuestion(int id) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // 🔹 1️⃣ Delete from Local DB
      await _dbHelper.deleteQuestion(id);

      // 🔹 2️⃣ Re-sequence question numbers locally
      final allMaps = await _dbHelper.getAllQuestionsMap();
      int qNumber = 1;
      final updatedMcqs = <MCQ>[];
      for (final q in allMaps) {
        final mcq = MCQ.fromMap(q);
        mcq.questionNumber = qNumber;
        await _dbHelper.updateQuestion(mcq, syncFirebase: false);
        updatedMcqs.add(mcq);
        qNumber++;
      }

      // 🔹 3️⃣ Refresh UI immediately (Offline support)
      if (mounted) setState(() => questions = allMaps);

      // 🔹 4️⃣ Snackbar show instantly
      CustomSnackbar.show(
        context,
        "🗑️ Question deleted successfully (Local)",
        backgroundColor: Colors.orange,
      );

      // 🔹 5️⃣ Background Firebase delete + reindex (if online)
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity != ConnectivityResult.none) {
        try {
          // Delete question from Firestore
          await _dbHelper.deleteQuestionFromFirestore(id);
          debugPrint("✅ Synced deletion to Firebase");

          // Reindex remaining questions in Firestore to prevent duplicates
          await FirebaseService().reindexQuestions(user.uid, updatedMcqs);
          debugPrint("🔁 Firestore reindex successful (duplicate fix)");
        } catch (e) {
          debugPrint("⚠️ Firebase delete/reindex failed (offline maybe): $e");
        }
      } else {
        debugPrint("🌐 Offline mode: Firebase delete skipped");
      }
    } catch (e) {
      CustomSnackbar.show(
        context,
        "❌ Failed to delete question: $e",
        backgroundColor: Colors.redAccent,
      );
      debugPrint("❌ Delete failed: $e");
    }

    // 🔹 6️⃣ Optional: Sync after change when connection returns
    _syncAfterChange();
  }


  Widget _buildTextField(TextEditingController ctrl, String label, IconData icon,{bool readOnly = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: TextField(
        controller: ctrl,
        readOnly: readOnly,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.blue),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Update Database'), backgroundColor: Colors.indigo),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                ElevatedButton.icon(icon: const Icon(Icons.add_circle), label: const Text('Add Question'), onPressed: _openAddQuestionDialog),
                const SizedBox(width: 10),
                ElevatedButton.icon(icon: const Icon(Icons.upload_file), label: const Text('Import CSV'), onPressed: _importCSV),
              ]),
            ),
            const SizedBox(height: 20),
            const Text('📋 Saved Questions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const Divider(),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: 1200,
                  child: DataTable2(
                    headingRowColor: MaterialStateProperty.all(Colors.blue.shade100),
                    columnSpacing: 12,
                    horizontalMargin: 12,
                    minWidth: 1000,
                    columns: const [
                      DataColumn2(label: Text('No.'), size: ColumnSize.S),
                      DataColumn2(label: Text('Course'), size: ColumnSize.L),
                      DataColumn2(label: Text('Question'), size: ColumnSize.L),
                      DataColumn2(label: Text('A')),
                      DataColumn2(label: Text('B')),
                      DataColumn2(label: Text('C')),
                      DataColumn2(label: Text('D')),
                      DataColumn2(label: Text('Ans'), size: ColumnSize.S),
                      DataColumn2(label: Text('Q#'), size: ColumnSize.S),
                      DataColumn2(label: Text('Actions')),
                    ],
                    rows: List<DataRow>.generate(questions.length, (index) {
                      final q = questions[index];
                      return DataRow(cells: [
                        DataCell(Text((index + 1).toString())),
                        DataCell(Text(q['course']?.toString() ?? '')),
                        DataCell(Text(q['question']?.toString() ?? '')),
                        DataCell(Text(q['option_A']?.toString() ?? '')),
                        DataCell(Text(q['option_B']?.toString() ?? '')),
                        DataCell(Text(q['option_C']?.toString() ?? '')),
                        DataCell(Text(q['option_D']?.toString() ?? '')),
                        DataCell(Text(q['answer']?.toString() ?? '')),
                        DataCell(Text((q['questionNumber']?.toString() ?? ''))),
                        DataCell(Wrap(spacing: 5, children: [
                          IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _editQuestionDialog(q)),
                          IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteQuestion(q['id'])),
                        ])),
                      ]);
                    }),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
