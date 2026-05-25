import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class AuthApiException implements Exception {
  const AuthApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class LoginResult {
  const LoginResult({
    required this.accessToken,
    required this.userId,
    required this.email,
    required this.username,
  });

  final String accessToken;
  final String userId;
  final String email;
  final String username;
}

class AuthApi {
  AuthApi({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client(),
      _pb = PocketBase(_baseUrl);

  static final String _baseUrl = _resolveBaseUrl();
  static const String _sessionAccessTokenKey = 'auth.access_token';
  static const String _sessionUserIdKey = 'auth.user_id';
  static String? _accessToken;
  static String? _currentUserId;

  final http.Client _httpClient;
  final PocketBase _pb;

  static String get baseUrl => _baseUrl;
  static String? get accessToken => _accessToken;
  static String? get currentUserId => _currentUserId;

  static bool get isSignedIn {
    final String? token = _accessToken;
    return token != null && token.isNotEmpty;
  }

  static void applyLoginResult(LoginResult result) {
    _accessToken = result.accessToken.trim();
    _currentUserId = result.userId.trim();
  }

  static Future<void> persistLoginResult(LoginResult result) async {
    applyLoginResult(result);

    try {
      await _persistSession();
    } catch (error) {
      debugPrint('persistLoginResult failed: $error');
      // Keeps in-memory session even when local persistence fails.
    }
  }

  static Future<bool> tryRestoreSession() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String token = (prefs.getString(_sessionAccessTokenKey) ?? '')
          .trim();
      final String userId = (prefs.getString(_sessionUserIdKey) ?? '').trim();

      if (token.isEmpty) {
        clearSession();
        return false;
      }

      _accessToken = token;
      _currentUserId = userId.isNotEmpty
          ? userId
          : _extractUserIdFromToken(token);
      return true;
    } catch (error) {
      debugPrint('tryRestoreSession failed: $error');
      clearSession();
      return false;
    }
  }

  static Future<void> clearSessionAndStorage() async {
    clearSession();

    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sessionAccessTokenKey);
      await prefs.remove(_sessionUserIdKey);
    } catch (_) {
      // Session in memory is already cleared above.
    }
  }

  static void clearSession() {
    _accessToken = null;
    _currentUserId = null;
  }

  static Future<void> _persistSession() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String token = (_accessToken ?? '').trim();
    final String userId = (_currentUserId ?? '').trim();

    if (token.isEmpty) {
      await prefs.remove(_sessionAccessTokenKey);
      await prefs.remove(_sessionUserIdKey);
      return;
    }

    await prefs.setString(_sessionAccessTokenKey, token);
    if (userId.isEmpty) {
      await prefs.remove(_sessionUserIdKey);
    } else {
      await prefs.setString(_sessionUserIdKey, userId);
    }
  }

  static String? _extractUserIdFromToken(String token) {
    try {
      final List<String> parts = token.split('.');
      if (parts.length < 2) {
        return null;
      }

      final String normalized = base64Url.normalize(parts[1]);
      final String payload = utf8.decode(base64Url.decode(normalized));
      final dynamic decoded = jsonDecode(payload);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      final String id = (decoded['id'] ?? '').toString().trim();
      if (id.isEmpty) {
        return null;
      }

      return id;
    } catch (_) {
      return null;
    }
  }

  static String _resolveBaseUrl() {
    const configuredBaseUrl = String.fromEnvironment('API_BASE_URL');
    if (configuredBaseUrl.isNotEmpty) {
      return configuredBaseUrl;
    }

    if (kIsWeb) {
      return 'https://www.tori-capsule.me';
    }

    if (Platform.isAndroid) {
      return 'https://www.tori-capsule.me';
    }

    return 'https://www.tori-capsule.me';
  }

  Future<void> register({
    required String email,
    required String username,
    required String password,
    required String passwordConfirm,
  }) async {
    final response = await _httpClient.post(
      Uri.parse('$_baseUrl/users'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'username': username,
        'password': password,
        'passwordConfirm': passwordConfirm,
      }),
    );

    if (response.statusCode == 201) {
      return;
    }

    throw AuthApiException(_extractErrorMessage(response));
  }

  Future<void> requestVerification({required String email}) async {
    final response = await _httpClient.post(
      Uri.parse('$_baseUrl/users/request-verification'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );

    if (response.statusCode == 200) {
      return;
    }

    throw AuthApiException(_extractErrorMessage(response));
  }

  Future<LoginResult> login({
    required String email,
    required String password,
  }) async {
    final response = await _httpClient.post(
      Uri.parse('$_baseUrl/users/login'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode != 200) {
      throw AuthApiException(_extractErrorMessage(response));
    }

    final dynamic data = jsonDecode(response.body);
    if (data is! Map<String, dynamic>) {
      throw const AuthApiException('invalid response from server');
    }

    final dynamic tokenData = data['token'];
    final dynamic userData = data['user'];

    if (tokenData is! Map<String, dynamic> ||
        userData is! Map<String, dynamic>) {
      throw const AuthApiException('invalid response from server');
    }

    return LoginResult(
      accessToken: (tokenData['access_token'] ?? '').toString(),
      userId: (userData['id'] ?? '').toString(),
      email: (userData['email'] ?? '').toString(),
      username: (userData['username'] ?? userData['name'] ?? '').toString(),
    );
  }

  Future<Set<String>> listAvailableSocialProviders() async {
    try {
      final dynamic authMethods = await _pb
          .collection('users')
          .listAuthMethods();
      final Map<String, dynamic> authMethodsJson = _asJsonMap(authMethods);
      final Map<String, dynamic> oauth2 = _asJsonMap(authMethodsJson['oauth2']);
      final dynamic providersValue = oauth2['providers'];

      if (providersValue is! List) {
        return <String>{};
      }

      return providersValue
          .map((dynamic provider) {
            final Map<String, dynamic> providerJson = _asJsonMap(provider);
            return (providerJson['name'] ?? '').toString().trim().toLowerCase();
          })
          .where((String name) => name.isNotEmpty)
          .toSet();
    } catch (error) {
      throw AuthApiException(_extractPocketBaseMessage(error));
    }
  }

  Future<LoginResult> loginWithSocial({
    required String provider,
    Map<String, dynamic> createData = const {},
  }) async {
    final String normalizedProvider = provider.trim().toLowerCase();

    try {
      final dynamic authData = await _pb.collection('users').authWithOAuth2(
        normalizedProvider,
        (dynamic url) async {
          final Uri authUri = url is Uri ? url : Uri.parse(url.toString());
          final bool launched = await launchUrl(
            authUri,
            mode: LaunchMode.externalApplication,
          );

          if (!launched) {
            throw const AuthApiException('브라우저를 열 수 없습니다.');
          }
        },
        createData: createData,
      );

      final Map<String, dynamic> authJson = _asJsonMap(authData);
      final Map<String, dynamic> recordJson = _asJsonMap(authJson['record']);

      return LoginResult(
        accessToken: (authJson['token'] ?? '').toString(),
        userId: (recordJson['id'] ?? '').toString(),
        email: (recordJson['email'] ?? '').toString(),
        username: _resolveUsername(recordJson),
      );
    } catch (error) {
      throw AuthApiException(_extractPocketBaseMessage(error));
    }
  }

  String _extractErrorMessage(http.Response response) {
    try {
      final dynamic body = jsonDecode(response.body);
      if (body is Map<String, dynamic> && body['message'] != null) {
        return body['message'].toString();
      }
    } catch (_) {
      // Falls back to a generic message when response body is not JSON.
    }

    return 'request failed: ${response.statusCode}';
  }

  String _extractPocketBaseMessage(Object error) {
    if (error is AuthApiException) {
      return error.message;
    }

    try {
      final dynamic dynamicError = error;
      final dynamic response = dynamicError.response;
      if (response is Map && response['message'] != null) {
        return response['message'].toString();
      }
    } catch (_) {
      // Falls back to a generic message when the error shape is unknown.
    }

    final String message = error.toString().trim();
    if (message.isNotEmpty) {
      return message;
    }

    return 'social login failed';
  }

  Map<String, dynamic> _asJsonMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    try {
      final dynamic json = value.toJson();
      if (json is Map<String, dynamic>) {
        return json;
      }
      if (json is Map) {
        return Map<String, dynamic>.from(json);
      }
    } catch (_) {
      // Returns empty map below when the object cannot be serialized.
    }

    return <String, dynamic>{};
  }

  String _resolveUsername(Map<String, dynamic> recordJson) {
    final String username = (recordJson['username'] ?? '').toString().trim();
    if (username.isNotEmpty) {
      return username;
    }

    final String name = (recordJson['name'] ?? '').toString().trim();
    if (name.isNotEmpty) {
      return name;
    }

    final String email = (recordJson['email'] ?? '').toString().trim();
    if (!email.contains('@')) {
      return email;
    }

    return email.split('@').first;
  }
}
