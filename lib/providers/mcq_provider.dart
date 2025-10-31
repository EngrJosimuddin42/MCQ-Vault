import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/mcq.dart';
import '../db/db_helper.dart';

class MCQProvider extends ChangeNotifier {
  final DBHelper _dbHelper = DBHelper();

  List<MCQ> _mcqs = [];
  bool _isOnline = false;

  // নতুন টাইপ অনুযায়ী
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  List<MCQ> get mcqs => _mcqs;
  bool get isOnline => _isOnline;

  MCQProvider() {
    _init();
  }

  Future<void> _init() async {
    await _checkConnectivity();
    await loadMCQs();
    _listenConnectivity();

    // Auth state changes
    FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user != null) {
        await loadMCQs();
      } else {
        clearMCQs();
      }
    });
  }

  // Initial connectivity check
  Future<void> _checkConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    _isOnline = result != ConnectivityResult.none;
    notifyListeners();
  }

  // Connectivity listener
  void _listenConnectivity() {
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) async {
          // প্রথম result দিয়ে online/offline চেক
          final result = results.isNotEmpty ? results.first : ConnectivityResult.none;
          final nowOnline = result != ConnectivityResult.none;

          if (_isOnline != nowOnline) {
            _isOnline = nowOnline;
            notifyListeners();

            if (_isOnline) {
              // Delay to avoid rapid changes
              await Future.delayed(const Duration(milliseconds: 800));
              await _syncOnConnectivityChange();
            }
          }
        });
  }

  // Sync local <-> Firestore
  Future<void> _syncOnConnectivityChange() async {
    if (!_isOnline) return;

    try {
      await _dbHelper.syncToFirestore();    // Local → Firestore
      await _dbHelper.syncFromFirestore();  // Firestore → Local
      await loadMCQs();
    } catch (e) {
      if (kDebugMode) print('❌ Sync error: $e');
    }
  }

  // Load MCQs (local first, Firestore if empty)
  Future<void> loadMCQs() async {
    try {
      var localMCQs = await _dbHelper.getAllQuestions();

      if (localMCQs.isEmpty && _isOnline) {
        await _dbHelper.syncFromFirestore();
        localMCQs = await _dbHelper.getAllQuestions();
      }

      _mcqs = localMCQs;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('❌ Load MCQs error: $e');
    }
  }

  // Add MCQ
  Future<void> addMCQ(MCQ mcq) async {
    await _dbHelper.insertQuestion(mcq);
    _mcqs.add(mcq);
    notifyListeners();

    if (_isOnline) await _dbHelper.syncToFirestore();
  }

  // Update MCQ
  Future<void> updateMCQ(MCQ mcq) async {
    await _dbHelper.updateQuestion(mcq);
    final index = _mcqs.indexWhere((m) => m.id == mcq.id);
    if (index != -1) _mcqs[index] = mcq;
    notifyListeners();

    if (_isOnline) await _dbHelper.syncToFirestore();
  }

  // Delete MCQ
  Future<void> deleteMCQ(MCQ mcq) async {
    await _dbHelper.deleteQuestion(mcq.id!);
    _mcqs.removeWhere((m) => m.id == mcq.id);
    notifyListeners();

    if (_isOnline) await _dbHelper.syncToFirestore();
  }

  // Clear all MCQs locally
  Future<void> clearMCQs() async {
    _mcqs.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}
