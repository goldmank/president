import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'user_progress.dart';

class UserProgressService extends ChangeNotifier {
  UserProgressService._();

  static final UserProgressService instance = UserProgressService._();

  static const String _guestStorageKey = 'guest_user_progress_v1';

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  SharedPreferences? _prefs;
  StreamSubscription<User?>? _authSubscription;
  UserProgress _currentProgress = const UserProgress();
  bool _initialized = false;

  UserProgress get currentProgress => _currentProgress;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    _prefs = await SharedPreferences.getInstance();
    _currentProgress = await _loadProgressForCurrentUser();
    _authSubscription = _auth.authStateChanges().listen((User? _) async {
      _currentProgress = await _loadProgressForCurrentUser();
      notifyListeners();
    });
    _initialized = true;
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> addDebugScore(int amount) async {
    _currentProgress = _currentProgress.copyWith(
      debugScoreBonus: _currentProgress.debugScoreBonus + amount,
    );
    await _persistCurrent();
    notifyListeners();
  }

  Future<void> resetDebugScore() async {
    _currentProgress = _currentProgress.copyWith(debugScoreBonus: 0);
    await _persistCurrent();
    notifyListeners();
  }

  Future<void> recordFinishedGame(String role) async {
    _currentProgress = _currentProgress.recordRole(role);
    await _persistCurrent();
    notifyListeners();
  }

  Future<UserProgress> _loadProgressForCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) {
      return _loadGuestProgress();
    }

    try {
      final snapshot = await _firestore.collection('users').doc(user.uid).get();
      final data = snapshot.data();
      if (data == null) {
        return const UserProgress();
      }
      return UserProgress.fromJson(data);
    } catch (_) {
      return const UserProgress();
    }
  }

  UserProgress _loadGuestProgress() {
    final raw = _prefs?.getString(_guestStorageKey);
    if (raw == null || raw.isEmpty) {
      return const UserProgress();
    }
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return UserProgress.fromJson(decoded);
    } catch (_) {
      return const UserProgress();
    }
  }

  Future<void> _persistCurrent() async {
    final user = _auth.currentUser;
    if (user == null) {
      await _prefs?.setString(
        _guestStorageKey,
        jsonEncode(_currentProgress.toJson()),
      );
      return;
    }

    await _firestore.collection('users').doc(user.uid).set(<String, dynamic>{
      ..._currentProgress.toJson(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
