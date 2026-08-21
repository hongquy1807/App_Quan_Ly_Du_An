import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_service.dart';

class FriendService {
  FriendService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<Map<String, dynamic>> getFriends({
    String search = '',
    bool ascending = true,
  }) async {
    try {
      final headers = await AuthService.authHeaders();
      final uri = Uri.parse('${AuthService.baseUrl}/friends').replace(
        queryParameters: {
          if (search.trim().isNotEmpty) 'search': search.trim(),
          'sort': ascending ? 'asc' : 'desc',
        },
      );
      final response = await _client
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 15));

      final data = _decodeResponse(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(data['message']?.toString() ?? 'Yêu cầu thất bại.');
      }

      final responseData = data['data'];
      if (responseData is Map<String, dynamic>) return responseData;
      if (responseData is Map) return Map<String, dynamic>.from(responseData);

      throw const ApiException('Phản hồi API không hợp lệ.');
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException('Không thể kết nối API bạn bè.');
    }
  }

  Future<String> sendFriendRequest(String email) async {
    try {
      final headers = await AuthService.authHeaders();
      final response = await _client
          .post(
            Uri.parse('${AuthService.baseUrl}/friends/requests'),
            headers: {...headers, 'Content-Type': 'application/json'},
            body: jsonEncode({'email': email.trim()}),
          )
          .timeout(const Duration(seconds: 15));

      final data = _decodeResponse(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(data['message']?.toString() ?? 'Yêu cầu thất bại.');
      }

      return data['message']?.toString() ?? 'Đã gửi lời mời kết bạn.';
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException('Không thể gửi lời mời kết bạn.');
    }
  }

  Future<Map<String, dynamic>> getIncomingRequests() async {
    try {
      final headers = await AuthService.authHeaders();
      final response = await _client
          .get(
            Uri.parse('${AuthService.baseUrl}/friends/requests/incoming'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 15));

      final data = _decodeResponse(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(data['message']?.toString() ?? 'Yêu cầu thất bại.');
      }

      final responseData = data['data'];
      if (responseData is Map<String, dynamic>) return responseData;
      if (responseData is Map) return Map<String, dynamic>.from(responseData);

      throw const ApiException('Phản hồi API không hợp lệ.');
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException('Không thể tải lời mời kết bạn.');
    }
  }

  Future<String> acceptFriendRequest(dynamic id) async {
    return _respondFriendRequest(id, accept: true);
  }

  Future<String> rejectFriendRequest(dynamic id) async {
    return _respondFriendRequest(id, accept: false);
  }

  Future<String> _respondFriendRequest(dynamic id, {required bool accept}) async {
    try {
      final headers = await AuthService.authHeaders();
      final action = accept ? 'accept' : 'reject';
      final response = await _client
          .patch(
            Uri.parse('${AuthService.baseUrl}/friends/requests/$id/$action'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 15));

      final data = _decodeResponse(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(data['message']?.toString() ?? 'Yêu cầu thất bại.');
      }

      return data['message']?.toString() ??
          (accept ? 'Đã chấp nhận lời mời.' : 'Đã từ chối lời mời.');
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException('Không thể phản hồi lời mời kết bạn.');
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
