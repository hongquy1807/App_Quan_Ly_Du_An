import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_service.dart';

class ChatbotService {
  ChatbotService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<Map<String, dynamic>> ask(
    String question, {
    String language = 'vietnamese',
  }) async {
    try {
      final headers = await AuthService.authHeaders();
      final response = await _client
          .post(
            Uri.parse('${AuthService.baseUrl}/chatbot/ask'),
            headers: {...headers, 'Content-Type': 'application/json'},
            body: jsonEncode({
              'question': question,
              'language': language,
            }),
          )
          .timeout(const Duration(seconds: 45));

      final data = _decodeResponse(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(data['message']?.toString() ?? 'Yêu cầu thất bại.');
      }

      final responseData = data['data'];
      if (responseData is Map) {
        return Map<String, dynamic>.from(responseData);
      }
      return data;
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException('Không thể kết nối chatbot.');
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
