import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

import '../main.dart';
import 'auth_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();
  static const AndroidNotificationChannel _androidChannel =
      AndroidNotificationChannel(
        'quanlyduan_default',
        'Thông báo Quản lý dự án',
        description: 'Thông báo nhiệm vụ, tin nhắn và lời mời',
        importance: Importance.high,
      );

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _localNotificationsReady = false;
  Future<void>? _initializing;

  Future<void> initialize() => _ensureInitialized();

  Future<void> registerCurrentDevice() async {
    if (kIsWeb) return;

    try {
      await _ensureInitialized();
      if (!_initialized) {
        debugPrint('Push notification: Firebase is not ready, skip token');
        return;
      }
      final messaging = FirebaseMessaging.instance;
      final token = await messaging.getToken();

      if (token == null || token.isEmpty) {
        debugPrint('Push notification: FCM token is empty');
        return;
      }

      debugPrint('Push notification: FCM token ${token.substring(0, 12)}...');
      await _sendTokenToBackend(token);
    } catch (err) {
      debugPrint('Unable to get FCM token: $err');
    }
  }

  Future<void> _ensureInitialized() {
    if (_initialized || kIsWeb) return Future.value();
    return _initializing ??= _initializeFirebase();
  }

  Future<void> _initializeFirebase() async {
    try {
      await Firebase.initializeApp();
      debugPrint('Push notification: Firebase initialized');

      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      await _initializeLocalNotifications();

      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);

      messaging.onTokenRefresh.listen((token) {
        _sendTokenToBackend(token);
      });

      FirebaseMessaging.onMessage.listen(_showForegroundNotification);
      FirebaseMessaging.onMessageOpenedApp.listen(_openNotificationScreen);
      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) _openNotificationScreen(initialMessage);

      _initialized = true;
    } catch (err) {
      debugPrint('Push notification init skipped: $err');
    } finally {
      _initializing = null;
    }
  }

  Future<void> _initializeLocalNotifications() async {
    if (_localNotificationsReady || !Platform.isAndroid) return;

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const initializationSettings = InitializationSettings(
      android: androidSettings,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (_) => _openNotificationScreenFromTap(),
    );

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(_androidChannel);
    await androidPlugin?.requestNotificationsPermission();

    _localNotificationsReady = true;
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    if (!_localNotificationsReady || !Platform.isAndroid) return;

    final notification = message.notification;
    final title =
        notification?.title ??
        message.data['title']?.toString() ??
        'Quản lý dự án';
    final body =
        notification?.body ??
        message.data['body']?.toString() ??
        'Bạn có thông báo mới.';

    await _localNotifications.show(
      message.hashCode,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  Future<void> _sendTokenToBackend(String token) async {
    try {
      final headers = await AuthService.authHeaders();
      if (!headers.containsKey('Authorization')) {
        debugPrint(
          'Push notification: skip token register because user is not logged in',
        );
        return;
      }

      final response = await http
          .post(
            Uri.parse('${AuthService.baseUrl}/notifications/push-token'),
            headers: {...headers, 'Content-Type': 'application/json'},
            body: jsonEncode({
              'token': token,
              'platform': Platform.operatingSystem,
            }),
          )
          .timeout(const Duration(seconds: 12));
      debugPrint(
        'Push notification: backend register status ${response.statusCode}',
      );
    } catch (err) {
      debugPrint('Unable to register push token: $err');
    }
  }

  void _openNotificationScreen(RemoteMessage message) {
    _openNotificationScreenFromTap();
  }

  void _openNotificationScreenFromTap() {
    final navigator = rootNavigatorKey.currentState;
    if (navigator == null) return;
    navigator.pushNamed('/notifications');
  }
}
