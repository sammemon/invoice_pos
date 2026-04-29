import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/network/api_client.dart';
import '../models/user_model.dart';

// SharedPreferences keys
const _kToken   = 'auth_token';
const _kUser    = 'auth_user';

class AuthState {
  final UserModel? user;
  final String? token;
  final bool isLoading;
  final String? error;

  const AuthState({this.user, this.token, this.isLoading = false, this.error});
  bool get isAuthenticated => token != null && token!.isNotEmpty && user != null;

  AuthState copyWith({UserModel? user, String? token, bool? isLoading, String? error}) =>
      AuthState(user: user ?? this.user, token: token ?? this.token,
                isLoading: isLoading ?? this.isLoading, error: error);
}

class AuthNotifier extends StateNotifier<AuthState> {
  // GoRouter listens to this for redirects
  final routerListenable = ValueNotifier<int>(0);

  // Start loading — prevents router redirect before session is known
  AuthNotifier() : super(const AuthState(isLoading: true)) { _restoreSession(); }

  @override
  set state(AuthState value) {
    super.state = value;
    routerListenable.value++;
  }

  // ── Session restore on app start ─────────────────────────────
  Future<void> _restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token    = prefs.getString(_kToken);
      final userJson = prefs.getString(_kUser);
      if (token != null && userJson != null) {
        state = AuthState(user: UserModel.fromJson(jsonDecode(userJson)), token: token);
        return;
      }
    } catch (e) {
      debugPrint('Session restore error: $e');
    }
    state = const AuthState(); // not authenticated
  }

  // ── Login ────────────────────────────────────────────────────
  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await ApiClient.instance.post('/auth/login',
          data: {'email': email, 'password': password});
      final token = res.data['token'] as String;
      final user  = UserModel.fromJson(res.data['user']);
      await _saveSession(token, user);
      state = AuthState(user: user, token: token);
      return true;
    } catch (e) {
      state = AuthState(error: _extractError(e));
      return false;
    }
  }

  // ── Register ─────────────────────────────────────────────────
  Future<bool> register(String name, String email, String password, String shopName) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await ApiClient.instance.post('/auth/register', data: {
        'name': name, 'email': email, 'password': password, 'shopName': shopName,
      });
      final token = res.data['token'] as String;
      final user  = UserModel.fromJson(res.data['user']);
      await _saveSession(token, user);
      state = AuthState(user: user, token: token);
      return true;
    } catch (e) {
      state = AuthState(error: _extractError(e));
      return false;
    }
  }

  // ── Logout — clears state immediately, storage in background ─
  Future<void> logout() async {
    state = const AuthState(); // instant — triggers auth gate rebuild
    _clearSession();           // background — SharedPreferences clears fast
  }

  // ── Update profile ───────────────────────────────────────────
  Future<void> updateProfile({String? name, String? shopName, String? phone}) async {
    try {
      final res = await ApiClient.instance.put('/auth/profile', data: {
        'name': name?.trim(),
        'shopName': shopName?.trim(),
        'phone': ?phone,
      });
      final user = UserModel.fromJson(res.data['user']);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kUser, jsonEncode(user.toJson()));
      state = state.copyWith(user: user);
    } catch (e) {
      throw Exception(_extractError(e));
    }
  }

  // ── Change password ──────────────────────────────────────────
  Future<void> changePassword(String currentPassword, String newPassword) async {
    try {
      await ApiClient.instance.put('/auth/change-password', data: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      });
    } catch (e) {
      throw Exception(_extractError(e));
    }
  }

  // ── Helpers ──────────────────────────────────────────────────
  Future<void> _saveSession(String token, UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kToken, token);
    await prefs.setString(_kUser, jsonEncode(user.toJson()));
  }

  void _clearSession() {
    SharedPreferences.getInstance()
        .then((p) => p.remove(_kToken).then((_) => p.remove(_kUser)))
        .catchError((_) => false);
  }

  String _extractError(Object e) {
    try {
      return (e as dynamic).response?.data?['message'] ?? e.toString();
    } catch (_) {
      return e.toString();
    }
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
    (_) => AuthNotifier());
