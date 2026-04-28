import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/constants/app_constants.dart';
import '../core/network/api_client.dart';
import '../models/user_model.dart';

class AuthState {
  final UserModel? user;
  final String? token;
  final bool isLoading;
  final String? error;

  const AuthState({this.user, this.token, this.isLoading = false, this.error});
  bool get isAuthenticated => token != null && user != null;
  AuthState copyWith({UserModel? user, String? token, bool? isLoading, String? error}) =>
      AuthState(user: user ?? this.user, token: token ?? this.token,
                 isLoading: isLoading ?? this.isLoading, error: error);
}

class AuthNotifier extends StateNotifier<AuthState> {
  final _storage = const FlutterSecureStorage();

  // GoRouter listens to this — increments on every auth state change
  final routerListenable = ValueNotifier<int>(0);

  AuthNotifier() : super(const AuthState()) { _restoreSession(); }

  @override
  set state(AuthState value) {
    super.state = value;
    routerListenable.value++;
  }

  Future<void> _restoreSession() async {
    state = state.copyWith(isLoading: true);
    try {
      final token = await _storage.read(key: AppConstants.tokenKey);
      final userJson = await _storage.read(key: AppConstants.userKey);
      if (token != null && userJson != null) {
        final user = UserModel.fromJson(jsonDecode(userJson));
        state = AuthState(user: user, token: token);
      } else {
        state = const AuthState();
      }
    } catch (_) {
      state = const AuthState();
    }
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await ApiClient.instance.post('/auth/login', data: {'email': email, 'password': password});
      final token = res.data['token'] as String;
      final user = UserModel.fromJson(res.data['user']);
      await _storage.write(key: AppConstants.tokenKey, value: token);
      await _storage.write(key: AppConstants.userKey, value: jsonEncode(user.toJson()));
      state = AuthState(user: user, token: token);
      return true;
    } catch (e) {
      final msg = _extractError(e);
      state = AuthState(error: msg);
      return false;
    }
  }

  Future<bool> register(String name, String email, String password, String shopName) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await ApiClient.instance.post('/auth/register', data: {
        'name': name, 'email': email, 'password': password, 'shopName': shopName,
      });
      final token = res.data['token'] as String;
      final user = UserModel.fromJson(res.data['user']);
      await _storage.write(key: AppConstants.tokenKey, value: token);
      await _storage.write(key: AppConstants.userKey, value: jsonEncode(user.toJson()));
      state = AuthState(user: user, token: token);
      return true;
    } catch (e) {
      state = AuthState(error: _extractError(e));
      return false;
    }
  }

  Future<void> updateProfile({String? name, String? shopName, String? phone}) async {
    try {
      final res = await ApiClient.instance.put('/auth/profile', data: {
        'name':     name?.trim(),
        'shopName': shopName?.trim(),
        'phone':    ?phone,
      });
      final user = UserModel.fromJson(res.data['user']);
      await _storage.write(key: AppConstants.userKey, value: jsonEncode(user.toJson()));
      state = state.copyWith(user: user);
    } catch (e) {
      throw Exception(_extractError(e));
    }
  }

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

  Future<void> logout() async {
    await _storage.deleteAll();
    state = const AuthState();
  }

  String _extractError(Object e) {
    try {
      final dioErr = e as dynamic;
      return dioErr.response?.data?['message'] ?? e.toString();
    } catch (_) {
      return e.toString();
    }
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((_) => AuthNotifier());
