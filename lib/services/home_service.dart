import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_service.dart';

class HomeService {
  HomeService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<Map<String, dynamic>> getDashboard() async {
    try {
      final headers = await AuthService.authHeaders();
      final response = await _client
          .get(
            Uri.parse('${AuthService.baseUrl}/home/dashboard'),
            headers: {...headers, 'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 15));

      final data = _decodeResponse(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(data['message']?.toString() ?? 'Yêu cầu thất bại.');
      }

      if (data.containsKey('data') && data['data'] is Map<String, dynamic>) {
        return Map<String, dynamic>.from(data['data'] as Map);
      }

      return {'message': 'Phản hồi API không hợp lệ.'};
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException('Không thể kết nối API. Kiểm tra backend đã chạy chưa.');
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

  Future<Map<String, dynamic>> getNotifications({
    int page = 1,
    int limit = 20,
    String? read,
  }) async {
    try {
      final query = StringBuffer('/notifications?page=$page&limit=$limit');
      if (read != null) query.write('&read=$read');
      final headers = await AuthService.authHeaders();
      final response = await _client
          .get(
            Uri.parse('${AuthService.baseUrl}${query.toString()}'),
            headers: headers,
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
      throw ApiException('Không thể kết nối API.');
    }
  }

  Future<Map<String, dynamic>> getNotificationsUnreadCount() async {
    try {
      final headers = await AuthService.authHeaders();
      final response = await _client
          .get(
            Uri.parse('${AuthService.baseUrl}/notifications/unread-count'),
            headers: headers,
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
      throw ApiException('Không thể kết nối API.');
    }
  }

  Future<Map<String, dynamic>> markNotificationRead(int id, bool read) async {
    try {
      final headers = await AuthService.authHeaders();
      final response = await _client
          .patch(
            Uri.parse('${AuthService.baseUrl}/notifications/$id/read'),
            headers: {...headers, 'Content-Type': 'application/json'},
            body: jsonEncode({'read': read}),
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
      throw ApiException('Không thể kết nối API.');
    }
  }

  Future<Map<String, dynamic>> markAllNotificationsRead() async {
    try {
      final headers = await AuthService.authHeaders();
      final response = await _client
          .patch(
            Uri.parse('${AuthService.baseUrl}/notifications/mark-all-read'),
            headers: {...headers, 'Content-Type': 'application/json'},
            body: jsonEncode({}),
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
      throw ApiException('Không thể kết nối API.');
    }
  }
}
