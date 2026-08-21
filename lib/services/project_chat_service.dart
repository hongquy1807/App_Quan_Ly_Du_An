import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_service.dart';

class ProjectChatService {
  ProjectChatService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<Map<String, dynamic>>> getProjects() async {
    final data = await _request(method: 'GET', path: '/project-chat/projects');
    final projects = data['data'];
    if (projects is! List) return [];
    return projects
        .whereType<Map>()
        .map((project) => Map<String, dynamic>.from(project))
        .toList();
  }

  Future<List<Map<String, dynamic>>> getFriends() async {
    final data = await _request(method: 'GET', path: '/project-chat/friends');
    final friends = data['data'];
    if (friends is! List) return [];
    return friends
        .whereType<Map>()
        .map((friend) => Map<String, dynamic>.from(friend))
        .toList();
  }

  Future<Map<String, dynamic>> getMessages(
    int projectId, {
    int limit = 50,
    int? beforeId,
  }) async {
    final query = StringBuffer('/project-chat/$projectId/messages?limit=$limit');
    if (beforeId != null) query.write('&before_id=$beforeId');

    final data = await _request(method: 'GET', path: query.toString());
    final responseData = data['data'];
    if (responseData is Map) return Map<String, dynamic>.from(responseData);
    return {'project': null, 'messages': <Map<String, dynamic>>[]};
  }

  Future<Map<String, dynamic>> getDirectMessages(
    int friendId, {
    int limit = 50,
  }) async {
    final data = await _request(
      method: 'GET',
      path: '/project-chat/direct/$friendId/messages?limit=$limit',
    );
    final responseData = data['data'];
    if (responseData is Map) return Map<String, dynamic>.from(responseData);
    return {'friend': null, 'messages': <Map<String, dynamic>>[]};
  }

  Future<Map<String, dynamic>> sendMessage({
    required int projectId,
    required String content,
    String messageType = 'text',
    String? fileUrl,
    String? fileName,
    int? fileSize,
  }) async {
    final data = await _request(
      method: 'POST',
      path: '/project-chat/$projectId/messages',
      body: {
        'content': content,
        'message_type': messageType,
        if (fileUrl != null && fileUrl.isNotEmpty) 'file_url': fileUrl,
        if (fileName != null && fileName.isNotEmpty) 'file_name': fileName,
        if (fileSize != null) 'file_size': fileSize,
      },
    );

    final message = data['data'];
    if (message is Map) return Map<String, dynamic>.from(message);
    return data;
  }

  Future<Map<String, dynamic>> sendDirectMessage({
    required int friendId,
    required String content,
    String? fileUrl,
    String? fileType,
  }) async {
    final data = await _request(
      method: 'POST',
      path: '/project-chat/direct/$friendId/messages',
      body: {
        'content': content,
        if (fileUrl != null && fileUrl.isNotEmpty) 'file_url': fileUrl,
        if (fileType != null && fileType.isNotEmpty) 'file_type': fileType,
      },
    );

    final message = data['data'];
    if (message is Map) return Map<String, dynamic>.from(message);
    return data;
  }

  Future<void> deleteMessage(int messageId) async {
    await _request(
      method: 'DELETE',
      path: '/project-chat/messages/$messageId',
    );
  }

  Future<Map<String, dynamic>> _request({
    required String method,
    required String path,
    Map<String, dynamic>? body,
  }) async {
    try {
      final headers = await AuthService.authHeaders();
      final uri = Uri.parse('${AuthService.baseUrl}$path');
      final requestHeaders = {
        ...headers,
        'Content-Type': 'application/json',
      };

      late final http.Response response;
      switch (method) {
        case 'GET':
          response = await _client
              .get(uri, headers: headers)
              .timeout(const Duration(seconds: 15));
          break;
        case 'POST':
          response = await _client
              .post(uri, headers: requestHeaders, body: jsonEncode(body ?? {}))
              .timeout(const Duration(seconds: 15));
          break;
        case 'DELETE':
          response = await _client
              .delete(uri, headers: headers)
              .timeout(const Duration(seconds: 15));
          break;
        default:
          throw const ApiException('Phương thức API không hợp lệ.');
      }

      final data = _decodeResponse(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(data['message']?.toString() ?? 'Yêu cầu thất bại.');
      }
      return data;
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException('Không thể kết nối API tin nhắn.');
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
