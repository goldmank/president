import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'game_settings.dart';

class GameSettingsService extends ChangeNotifier {
  GameSettingsService._();

  static final GameSettingsService instance = GameSettingsService._();

  static const String _guestStorageKey = 'guest_game_settings_v1';

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  SharedPreferences? _prefs;
  StreamSubscription<User?>? _authSubscription;
  GameSettings _currentSettings = const GameSettings();
  bool _initialized = false;

  GameSettings get currentSettings => _currentSettings;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    _prefs = await SharedPreferences.getInstance();
    _currentSettings = await _loadSettingsForCurrentUser();
    _authSubscription = _auth.authStateChanges().listen((User? _) async {
      _currentSettings = await _loadSettingsForCurrentUser();
      notifyListeners();
    });
    _initialized = true;
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> setDoubleDeck(bool value) async {
    _currentSettings = _currentSettings.copyWith(doubleDeck: value);
    await _persistCurrent();
    notifyListeners();
  }

  Future<void> setAiDifficulty(int value) async {
    _currentSettings = _currentSettings.copyWith(aiDifficulty: value);
    await _persistCurrent();
    notifyListeners();
  }

  Future<GameSettings> _loadSettingsForCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) {
      return _loadGuestSettings();
    }

    try {
      final snapshot = await _firestore.collection('users').doc(user.uid).get();
      final data = snapshot.data();
      final rawSettings = data?['gameSettings'];
      if (rawSettings is Map<String, dynamic>) {
        return GameSettings.fromJson(rawSettings);
      }
      if (rawSettings is Map) {
        return GameSettings.fromJson(rawSettings.cast<String, dynamic>());
      }
      return const GameSettings();
    } catch (_) {
      return const GameSettings();
    }
  }

  GameSettings _loadGuestSettings() {
    final raw = _prefs?.getString(_guestStorageKey);
    if (raw == null || raw.isEmpty) {
      return const GameSettings();
    }
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return GameSettings.fromJson(decoded);
    } catch (_) {
      return const GameSettings();
    }
  }

  Future<void> _persistCurrent() async {
    final user = _auth.currentUser;
    if (user == null) {
      await _prefs?.setString(
        _guestStorageKey,
        jsonEncode(_currentSettings.toJson()),
      );
      return;
    }

    await _firestore.collection('users').doc(user.uid).set(<String, dynamic>{
      'gameSettings': _currentSettings.toJson(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
