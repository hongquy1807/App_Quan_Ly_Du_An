import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_service.dart';

class NotificationService {
  NotificationService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<Map<String, dynamic>> getNotifications({
    int page = 1,
    int limit = 50,
    String? read,
  }) async {
    try {
      final query = StringBuffer('/notifications?page=$page&limit=$limit');
      if (read != null) query.write('&read=$read');

      final headers = await AuthService.authHeaders();
      final response = await _client
          .get(
            Uri.parse('${AuthService.baseUrl}$query'),
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

  Future<int> getUnreadCount() async {
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

      final responseData = data['data'];
      if (responseData is Map) {
        return int.tryParse(responseData['unread']?.toString() ?? '0') ?? 0;
      }
      return 0;
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException('Không thể kết nối API.');
    }
  }

  Future<void> markRead(int id, bool read) async {
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
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException('Không thể kết nối API.');
    }
  }

  Future<void> markAllRead() async {
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
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException('Không thể kết nối API.');
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
}
