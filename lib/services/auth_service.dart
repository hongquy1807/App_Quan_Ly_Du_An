import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiException implements Exception {
  final String message;

  const ApiException(this.message);

  @override
  String toString() => message;
}

class AuthService {
  AuthService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static String? _token;
  static bool _tokenLoaded = false;

  static Future<void> _ensureTokenLoaded() async {
    if (_tokenLoaded) return;
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    _tokenLoaded = true;
  }

  static Future<void> saveToken(String? token) async {
    final prefs = await SharedPreferences.getInstance();
    if (token == null || token.isEmpty) {
      await prefs.remove('auth_token');
      _token = null;
    } else {
      await prefs.setString('auth_token', token);
      _token = token;
    }
    _tokenLoaded = true;
  }

  static String get baseUrl {
    const configuredUrl = String.fromEnvironment('API_BASE_URL');
    if (configuredUrl.isNotEmpty) return configuredUrl;

    if (kIsWeb) return 'http://localhost:3000/api';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://192.168.1.29:3000/api';
    }
    return 'http://localhost:3000/api';
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final data = await _post('/auth/login', {
      'email': email,
      'password': password,
    });
    await saveToken(data['token']?.toString());
    return data;
  }

  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final data = await _post('/auth/register', {
      'name': name,
      'email': email,
      'password': password,
    });
    await saveToken(data['token']?.toString());
    return data;
  }

  Future<Map<String, dynamic>> forgotPassword({required String email}) {
    return _post('/auth/forgot-password', {'email': email});
  }

  Future<Map<String, dynamic>> resetPassword({
    required String token,
    required String newPassword,
  }) {
    return _post('/auth/reset-password', {
      'token': token,
      'new_password': newPassword,
    });
  }

  Future<Map<String, dynamic>> getHomeDashboard() async {
    return _get('/home/dashboard');
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl$path'),
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));

      final data = _decodeResponse(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(data['message']?.toString() ?? 'Yêu cầu thất bại.');
      }

      return data;
    } on ApiException {
      rethrow;
    } catch (err) {
      throw ApiException(
        'Không thể kết nối API. Kiểm tra backend đã chạy tại $baseUrl chưa.',
      );
    }
  }

  Future<Map<String, dynamic>> _patch(String path, Map<String, dynamic> body) async {
    await _ensureTokenLoaded();
    if (_token == null || _token!.isEmpty) {
      throw const ApiException('Bạn cần đăng nhập lại để thực hiện thao tác.');
    }

    try {
      final response = await _client
          .patch(
            Uri.parse('$baseUrl$path'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $_token',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));

      final data = _decodeResponse(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(data['message']?.toString() ?? 'Yêu cầu thất bại.');
      }

      return data;
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException(
        'Không thể kết nối API. Kiểm tra backend đã chạy tại $baseUrl chưa.',
      );
    }
  }

  // Notifications
  Future<Map<String, dynamic>> getNotifications({int page = 1, int limit = 20, String? read}) async {
    final query = StringBuffer('/notifications?page=$page&limit=$limit');
    if (read != null) query.write('&read=$read');
    return _get(query.toString());
  }

  Future<Map<String, dynamic>> getNotificationsUnreadCount() async {
    return _get('/notifications/unread-count');
  }

  Future<Map<String, dynamic>> markNotificationRead(int id, bool read) async {
    return _patch('/notifications/$id/read', {'read': read});
  }

  Future<Map<String, dynamic>> markAllNotificationsRead() async {
    return _patch('/notifications/mark-all-read', {});
  }

  Future<Map<String, dynamic>> _get(String path) async {
    await _ensureTokenLoaded();
    if (_token == null || _token!.isEmpty) {
      throw const ApiException('Bạn cần đăng nhập lại để xem trang chủ.');
    }

    try {
      final response = await _client
          .get(
            Uri.parse('$baseUrl$path'),
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $_token',
            },
          )
          .timeout(const Duration(seconds: 15));

      final data = _decodeResponse(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(data['message']?.toString() ?? 'Yêu cầu thất bại.');
      }

      return data;
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException(
        'Không thể kết nối API. Kiểm tra backend đã chạy tại $baseUrl chưa.',
      );
    }
  }

  Map<String, dynamic> _decodeResponse(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      return {'message': 'Phản hồi API không hợp lệ.'};
    } catch (_) {
      return {'message': 'Phản hồi API không hợp lệ.'};
    }
  }

  // Expose auth headers for other services
  static Future<Map<String, String>> authHeaders() async {
    await _ensureTokenLoaded();
    return {
      'Accept': 'application/json',
      if (_token != null && _token!.isNotEmpty) 'Authorization': 'Bearer $_token',
    };
  }

  // Expose token if needed
  static String? get token => _token;
}
