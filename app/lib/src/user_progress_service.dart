import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ranked_api.dart';
import 'user_progress.dart';

class UserProgressService extends ChangeNotifier {
  UserProgressService._();

  static final UserProgressService instance = UserProgressService._();

  static const String _guestStorageKey = 'guest_user_progress_v1';

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final RankedApi _rankedApi = RankedApi();

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
    await _persistCurrentCache();
    notifyListeners();
  }

  Future<void> resetDebugScore() async {
    _currentProgress = _currentProgress.copyWith(debugScoreBonus: 0);
    await _persistCurrentCache();
    notifyListeners();
  }

  Future<void> recordFinishedGame(String role, String resultId) async {
    final user = _auth.currentUser;
    if (user == null) {
      _currentProgress = _currentProgress.recordRole(role);
      await _persistCurrentCache();
      notifyListeners();
      return;
    }

    final displayName = (user.displayName?.trim().isNotEmpty ?? false)
        ? user.displayName!.trim()
        : 'Player';

    try {
      _currentProgress = await _rankedApi.reportFinishedGame(
        resultId: resultId,
        userId: user.uid,
        displayName: displayName,
        photoUrl: user.photoURL,
        role: role,
      );
      await _persistRegisteredCache(_currentProgress, user);
      notifyListeners();
    } catch (error) {
      debugPrint('[user_progress] report_finished_game_failed $error');
    }
  }

  Future<UserProgress> _loadProgressForCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) {
      return _loadGuestProgress();
    }

    try {
      final progress = await _rankedApi.getUserProgress(user.uid);
      await _persistRegisteredCache(progress, user);
      return progress;
    } catch (_) {
      return _loadRegisteredProgressCache(user.uid);
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

  Future<UserProgress> _loadRegisteredProgressCache(String userId) async {
    try {
      final snapshot = await _firestore.collection('users').doc(userId).get();
      final data = snapshot.data();
      if (data == null) {
        return const UserProgress();
      }
      return UserProgress.fromJson(data);
    } catch (_) {
      return const UserProgress();
    }
  }

  Future<void> _persistCurrentCache() async {
    final user = _auth.currentUser;
    if (user == null) {
      await _prefs?.setString(
        _guestStorageKey,
        jsonEncode(_currentProgress.toJson()),
      );
      return;
    }

    await _persistRegisteredCache(_currentProgress, user);
  }

  Future<void> _persistRegisteredCache(UserProgress progress, User user) async {
    await _firestore.collection('users').doc(user.uid).set(<String, dynamic>{
      ...progress.toJson(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
