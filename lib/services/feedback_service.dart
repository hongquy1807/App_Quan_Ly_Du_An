import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_service.dart';

class FeedbackService {
  FeedbackService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<Map<String, dynamic>> submitFeedback({
    required String title,
    required String content,
    List<Map<String, dynamic>> attachments = const [],
  }) async {
    try {
      final headers = await AuthService.authHeaders();
      final response = await _client
          .post(
            Uri.parse('${AuthService.baseUrl}/feedback'),
            headers: {...headers, 'Content-Type': 'application/json'},
            body: jsonEncode({
              'title': title,
              'content': content,
              'attachments': attachments,
            }),
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
      throw ApiException('Không thể kết nối API góp ý.');
    }
  }

  Future<Map<String, dynamic>> getFeedbacks({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final headers = await AuthService.authHeaders();
      final response = await _client
          .get(
            Uri.parse('${AuthService.baseUrl}/feedback?page=$page&limit=$limit'),
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
      throw ApiException('Không thể kết nối API góp ý.');
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
