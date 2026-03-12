import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

typedef JsonMap = Map<String, dynamic>;
typedef TokenReader = String? Function();
typedef TokenWriter = Future<void> Function({
  required String accessToken,
  required String refreshToken,
});
typedef AuthFailureHandler = Future<void> Function();

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  TokenReader? _readAccessToken;
  TokenReader? _readRefreshToken;
  TokenWriter? _writeTokens;
  AuthFailureHandler? _handleAuthFailure;

  static String defaultBaseUrl() {
    const configured = String.fromEnvironment('API_BASE_URL');
    if (configured.isNotEmpty) {
      return configured;
    }

    if (kIsWeb) {
      return 'http://localhost:4000/api/v1';
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:4000/api/v1';
    }

    return 'http://localhost:4000/api/v1';
  }

  final String baseUrl = defaultBaseUrl();

  void configureAuth({
    required TokenReader readAccessToken,
    required TokenReader readRefreshToken,
    required TokenWriter writeTokens,
    required AuthFailureHandler onAuthFailure,
  }) {
    _readAccessToken = readAccessToken;
    _readRefreshToken = readRefreshToken;
    _writeTokens = writeTokens;
    _handleAuthFailure = onAuthFailure;
  }

  Future<JsonMap> login({
    required String email,
    required String password,
  }) {
    return _post(
      '/auth/login',
      body: {
        'email': email,
        'password': password,
      },
    );
  }

  Future<JsonMap> getDashboardSummary(String token) => _get('/dashboard/summary', token: token);

  Future<List<dynamic>> getRecentPayments(String token) => _getList('/dashboard/recent-payments', token: token);

  Future<List<dynamic>> getMembers(
    String token, {
    String? search,
    String? role,
    String? status,
  }) {
    return _getList(
      '/members',
      token: token,
      queryParameters: {
        if (search != null && search.isNotEmpty) 'search': search,
        if (role != null && role.isNotEmpty) 'role': role,
        if (status != null && status.isNotEmpty) 'status': status,
      },
    );
  }

  Future<JsonMap> getMember(String token, String memberId) => _get('/members/$memberId', token: token);

  Future<JsonMap> updateMember(String token, String memberId, JsonMap payload) => _patch('/members/$memberId', token: token, body: payload);

  Future<List<dynamic>> getMemberContributions(String token, String memberId) => _getList('/members/$memberId/contributions', token: token);

  Future<JsonMap> createMember(String token, JsonMap payload) => _post('/members', token: token, body: payload);

  Future<List<dynamic>> getPeriods(String token) => _getList('/periods', token: token);

  Future<JsonMap> getContributionSummary(String token, {String? period}) {
    return _get(
      '/contributions/summary',
      token: token,
      queryParameters: {
        if (period != null && period.isNotEmpty) 'period': period,
      },
    );
  }

  Future<List<dynamic>> getContributions(
    String token, {
    String? period,
    String? search,
    String? status,
  }) {
    return _getList(
      '/contributions',
      token: token,
      queryParameters: {
        if (period != null && period.isNotEmpty) 'period': period,
        if (search != null && search.isNotEmpty) 'search': search,
        if (status != null && status.isNotEmpty) 'status': status,
      },
    );
  }

  Future<JsonMap> recordPayment(String token, JsonMap payload) => _post('/contributions/payments', token: token, body: payload);

  Future<List<dynamic>> getUnpaidMembers(String token, {String? role}) {
    return _getList(
      '/members/unpaid',
      token: token,
      queryParameters: {
        if (role != null && role.isNotEmpty) 'role': role,
      },
    );
  }

  Future<List<dynamic>> getNotifications(
    String token, {
    String? status,
    String? search,
  }) {
    return _getList(
      '/notifications',
      token: token,
      queryParameters: {
        if (status != null && status.isNotEmpty) 'status': status,
        if (search != null && search.isNotEmpty) 'search': search,
      },
    );
  }

  Future<JsonMap> resendNotification(String token, String notificationId) {
    return _post('/notifications/$notificationId/resend', token: token);
  }

  Future<JsonMap> cancelNotification(String token, String notificationId) {
    return _post('/notifications/$notificationId/cancel', token: token);
  }

  Future<JsonMap> sendReminder({
    required String token,
    required List<String> memberIds,
    required String title,
    required String message,
    String channel = 'sms',
  }) {
    return _post(
      '/notifications/send',
      token: token,
      body: {
        'memberIds': memberIds,
        'channel': channel,
        'title': title,
        'message': message,
      },
    );
  }

  Future<JsonMap> getYearlyReport(String token, int year) {
    return _get('/reports/yearly', token: token, queryParameters: {'year': '$year'});
  }

  Future<JsonMap> getSettings(String token) => _get('/settings', token: token);

  Future<List<dynamic>> updateSettings(String token, JsonMap payload) => _patchList('/settings', token: token, body: payload);

  Future<List<dynamic>> getAdmins(String token) => _getList('/admins', token: token);

  Future<JsonMap> _get(
    String path, {
    String? token,
    Map<String, String>? queryParameters,
  }) async {
    final response = await _sendWithAuthRetry(
      () => _client.get(
        _buildUri(path, queryParameters),
        headers: _headers(_resolvedToken(token)),
      ),
    );
    final body = _decode(response);
    return _extractDataMap(response, body);
  }

  Future<List<dynamic>> _getList(
    String path, {
    String? token,
    Map<String, String>? queryParameters,
  }) async {
    final response = await _sendWithAuthRetry(
      () => _client.get(
        _buildUri(path, queryParameters),
        headers: _headers(_resolvedToken(token)),
      ),
    );
    final body = _decode(response);
    return _extractDataList(response, body);
  }

  Future<JsonMap> _post(
    String path, {
    String? token,
    Object? body,
  }) async {
    final response = await _sendWithAuthRetry(
      () => _client.post(
        _buildUri(path, null),
        headers: _headers(_resolvedToken(token)),
        body: body == null ? null : jsonEncode(body),
      ),
      allowRefresh: path != '/auth/login' && path != '/auth/refresh',
    );
    final decoded = _decode(response);
    return _extractDataMap(response, decoded);
  }

  Future<List<dynamic>> _patchList(
    String path, {
    String? token,
    Object? body,
  }) async {
    final response = await _sendWithAuthRetry(
      () => _client.patch(
        _buildUri(path, null),
        headers: _headers(_resolvedToken(token)),
        body: body == null ? null : jsonEncode(body),
      ),
    );
    final decoded = _decode(response);
    return _extractDataList(response, decoded);
  }

  Future<JsonMap> _patch(
    String path, {
    String? token,
    Object? body,
  }) async {
    final response = await _sendWithAuthRetry(
      () => _client.patch(
        _buildUri(path, null),
        headers: _headers(_resolvedToken(token)),
        body: body == null ? null : jsonEncode(body),
      ),
    );
    final decoded = _decode(response);
    return _extractDataMap(response, decoded);
  }

  Future<http.Response> _sendWithAuthRetry(
    Future<http.Response> Function() request, {
    bool allowRefresh = true,
  }) async {
    var response = await request();

    if (!allowRefresh || response.statusCode != 401) {
      return response;
    }

    final body = _tryDecode(response);
    final message = _extractErrorMessage(body);
    final shouldRefresh = message.toLowerCase().contains('jwt expired') || message.toLowerCase().contains('authentication required') || message.toLowerCase().contains('user is not authorized');

    if (!shouldRefresh) {
      return response;
    }

    final refreshed = await _refreshAccessToken();
    if (!refreshed) {
      await _handleAuthFailure?.call();
      return response;
    }

    response = await request();
    return response;
  }

  Future<bool> _refreshAccessToken() async {
    final refreshToken = _readRefreshToken?.call();
    if (refreshToken == null || refreshToken.isEmpty) {
      return false;
    }

    final response = await _client.post(
      _buildUri('/auth/refresh', null),
      headers: _headers(null),
      body: jsonEncode({'refreshToken': refreshToken}),
    );

    final decoded = _tryDecode(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return false;
    }

    final data = decoded is JsonMap ? decoded['data'] : null;
    if (data is! JsonMap) {
      return false;
    }

    final accessToken = data['accessToken'] as String?;
    final newRefreshToken = data['refreshToken'] as String?;
    if (accessToken == null || accessToken.isEmpty || newRefreshToken == null || newRefreshToken.isEmpty) {
      return false;
    }

    await _writeTokens?.call(
      accessToken: accessToken,
      refreshToken: newRefreshToken,
    );
    return true;
  }

  Uri _buildUri(String path, Map<String, String>? queryParameters) {
    final uri = Uri.parse('$baseUrl$path');
    return uri.replace(queryParameters: queryParameters == null || queryParameters.isEmpty ? null : queryParameters);
  }

  Map<String, String> _headers(String? token) {
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  String? _resolvedToken(String? token) {
    final configuredToken = _readAccessToken?.call();
    if (configuredToken != null && configuredToken.isNotEmpty) {
      return configuredToken;
    }
    return token;
  }

  dynamic _decode(http.Response response) {
    try {
      return jsonDecode(response.body);
    } catch (_) {
      throw ApiException('Invalid server response.', statusCode: response.statusCode);
    }
  }

  dynamic _tryDecode(http.Response response) {
    try {
      return jsonDecode(response.body);
    } catch (_) {
      return null;
    }
  }

  JsonMap _extractDataMap(http.Response response, dynamic body) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(_extractErrorMessage(body), statusCode: response.statusCode);
    }

    final data = body['data'];
    if (data is JsonMap) {
      return data;
    }

    throw ApiException('Unexpected data format.', statusCode: response.statusCode);
  }

  List<dynamic> _extractDataList(http.Response response, dynamic body) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(_extractErrorMessage(body), statusCode: response.statusCode);
    }

    final data = body['data'];
    if (data is List<dynamic>) {
      return data;
    }

    throw ApiException('Unexpected data format.', statusCode: response.statusCode);
  }

  String _extractErrorMessage(dynamic body) {
    final error = body is JsonMap ? body['error'] : null;
    if (error is JsonMap && error['message'] is String) {
      return error['message'] as String;
    }

    return 'Request failed.';
  }
}
