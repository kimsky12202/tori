import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'auth_api.dart';
import 'capsule_notification_service.dart';

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  FirebaseMessaging? _messaging;
  final http.Client _httpClient = http.Client();

  bool _isInitialized = false;
  bool _isFirebaseReady = false;
  String? _currentToken;

  static bool get _supportsPushPlatform {
    if (kIsWeb) {
      return false;
    }

    return Platform.isAndroid || Platform.isIOS;
  }

  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    if (!_supportsPushPlatform) return;

    _isFirebaseReady = await _ensureFirebaseInitialized();
    if (!_isFirebaseReady) {
      debugPrint('PushNotificationService: Firebase is not configured.');
      return;
    }

    final messaging = FirebaseMessaging.instance;
    _messaging = messaging;

    await messaging.setAutoInitEnabled(true);
    await _requestPermission(messaging);
    await messaging.setForegroundNotificationPresentationOptions(
      alert: false,
      badge: true,
      sound: true,
    );

    messaging.onTokenRefresh.listen((String token) async {
      final normalized = token.trim();
      if (normalized.isEmpty) return;

      _currentToken = normalized;
      if (!AuthApi.isSignedIn) return;
      await _upsertToken(normalized);
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      final notification = message.notification;
      if (notification == null) return;

      final title = (notification.title ?? '').trim();
      final body = (notification.body ?? '').trim();
      if (title.isEmpty && body.isEmpty) return;

      await CapsuleNotificationService.showImmediateAlert(
        title: title.isEmpty ? '알림' : title,
        body: body,
        payload: message.data['capsule_id']?.toString(),
      );
    });
  }

  Future<void> syncTokenWithServer() async {
    if (!_isInitialized) {
      await initialize();
    }
    if (!_supportsPushPlatform || !_isFirebaseReady || !AuthApi.isSignedIn) {
      return;
    }

    final token = await _resolveToken();
    if (token == null) return;

    await _upsertToken(token);
  }

  Future<void> deactivateCurrentDeviceToken() async {
    if (!_supportsPushPlatform || !_isFirebaseReady || !AuthApi.isSignedIn) {
      return;
    }

    final token = await _resolveToken();
    if (token == null) return;

    final accessToken = AuthApi.accessToken;
    if (accessToken == null || accessToken.isEmpty) return;

    final response = await _httpClient.delete(
      Uri.parse('${AuthApi.baseUrl}/push-tokens'),
      headers: <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(<String, dynamic>{'fcm_token': token}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      debugPrint(
        'PushNotificationService: failed to deactivate token (${response.statusCode})',
      );
    }
  }

  Future<bool> _ensureFirebaseInitialized() async {
    if (Firebase.apps.isNotEmpty) {
      return true;
    }

    try {
      await Firebase.initializeApp();
      return true;
    } catch (error) {
      debugPrint(
        'PushNotificationService: Firebase.initializeApp failed: $error',
      );
      return false;
    }
  }

  Future<void> _requestPermission(FirebaseMessaging messaging) async {
    try {
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
    } catch (error) {
      debugPrint('PushNotificationService: permission request failed: $error');
    }
  }

  Future<String?> _resolveToken() async {
    if (_currentToken != null && _currentToken!.isNotEmpty) {
      return _currentToken;
    }

    try {
      final messaging = _messaging;
      if (messaging == null) return null;

      final token = (await messaging.getToken())?.trim();
      if (token == null || token.isEmpty) return null;

      _currentToken = token;
      return token;
    } catch (error) {
      debugPrint('PushNotificationService: getToken failed: $error');
      return null;
    }
  }

  Future<void> _upsertToken(String token) async {
    final accessToken = AuthApi.accessToken;
    if (accessToken == null || accessToken.isEmpty) {
      return;
    }

    final response = await _httpClient.post(
      Uri.parse('${AuthApi.baseUrl}/push-tokens'),
      headers: <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(<String, dynamic>{
        'fcm_token': token,
        'platform': _platformName,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      debugPrint(
        'PushNotificationService: failed to upsert token (${response.statusCode})',
      );
    }
  }

  String get _platformName {
    if (kIsWeb) {
      return 'web';
    }
    if (Platform.isAndroid) {
      return 'android';
    }
    if (Platform.isIOS) {
      return 'ios';
    }
    if (Platform.isMacOS) {
      return 'macos';
    }
    if (Platform.isWindows) {
      return 'windows';
    }
    if (Platform.isLinux) {
      return 'linux';
    }
    return 'unknown';
  }
}
