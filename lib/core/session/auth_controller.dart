import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../network/api_client.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden in main()');
});

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

final authControllerProvider = Provider<AuthController>((ref) {
  return AuthController(
    prefs: ref.read(sharedPreferencesProvider),
    apiClient: ref.read(apiClientProvider),
  );
});

class AuthUser {
  const AuthUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    required this.status,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as String? ?? '',
      fullName: json['fullName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? '',
      status: json['status'] as String? ?? '',
    );
  }

  final String id;
  final String fullName;
  final String email;
  final String role;
  final String status;

  Map<String, dynamic> toJson() => {
        'id': id,
        'fullName': fullName,
        'email': email,
        'role': role,
        'status': status,
      };
}

class AuthController extends ChangeNotifier {
  AuthController({
    required SharedPreferences prefs,
    required ApiClient apiClient,
  })  : _prefs = prefs,
        _apiClient = apiClient {
    _token = _prefs.getString(_tokenKey);
    _refreshToken = _prefs.getString(_refreshTokenKey);
    final userJson = _prefs.getString(_userKey);
    if (userJson != null && userJson.isNotEmpty) {
      _user = AuthUser.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
    }

    _apiClient.configureAuth(
      readAccessToken: () => _token,
      readRefreshToken: () => _refreshToken,
      writeTokens: ({
        required String accessToken,
        required String refreshToken,
      }) async {
        _token = accessToken;
        _refreshToken = refreshToken;
        await _prefs.setString(_tokenKey, accessToken);
        await _prefs.setString(_refreshTokenKey, refreshToken);
        notifyListeners();
      },
      onAuthFailure: () async {
        await logout(notify: true);
      },
    );
  }

  static const _tokenKey = 'mvcs_auth_token';
  static const _refreshTokenKey = 'mvcs_refresh_token';
  static const _userKey = 'mvcs_auth_user';

  final SharedPreferences _prefs;
  final ApiClient _apiClient;

  bool _isLoading = false;
  String? _token;
  String? _refreshToken;
  AuthUser? _user;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  bool get isAuthenticated => _token != null && _token!.isNotEmpty;
  String? get token => _token;
  String? get refreshToken => _refreshToken;
  AuthUser? get user => _user;
  String? get errorMessage => _errorMessage;

  Future<void> login({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final data = await _apiClient.login(email: email, password: password);
      final userData = data['user'] as Map<String, dynamic>? ?? <String, dynamic>{};

      _token = data['accessToken'] as String?;
      _refreshToken = data['refreshToken'] as String?;
      _user = AuthUser.fromJson(userData);

      await _prefs.setString(_tokenKey, _token ?? '');
      await _prefs.setString(_refreshTokenKey, _refreshToken ?? '');
      await _prefs.setString(_userKey, jsonEncode(_user?.toJson() ?? <String, dynamic>{}));
    } on ApiException catch (error) {
      _errorMessage = error.message;
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout({bool notify = true}) async {
    _token = null;
    _refreshToken = null;
    _user = null;
    _errorMessage = null;

    await _prefs.remove(_tokenKey);
    await _prefs.remove(_refreshTokenKey);
    await _prefs.remove(_userKey);
    if (notify) {
      notifyListeners();
    }
  }
}
