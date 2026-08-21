import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'auth_service.dart';

class ProfileService {
  ProfileService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<Map<String, dynamic>> getProfile() async {
    try {
      final headers = await AuthService.authHeaders();
      final response = await _client
          .get(
            Uri.parse('${AuthService.baseUrl}/profile'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 15));

      final data = _decodeResponse(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(data['message']?.toString() ?? 'Yêu cầu thất bại.');
      }

      final profileData = data['data'];
      if (profileData is Map<String, dynamic>) return profileData;
      if (profileData is Map) return Map<String, dynamic>.from(profileData);

      throw const ApiException('Phản hồi API không hợp lệ.');
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException('Không thể kết nối API profile.');
    }
  }

  Future<Map<String, dynamic>> updateProfile({
    required String name,
    required String phone,
    required String birthday,
    required String address,
  }) async {
    try {
      final headers = await AuthService.authHeaders();
      final response = await _client
          .patch(
            Uri.parse('${AuthService.baseUrl}/profile'),
            headers: {...headers, 'Content-Type': 'application/json'},
            body: jsonEncode({
              'name': name.trim(),
              'phone': phone.trim(),
              'birthday': birthday.trim(),
              'address': address.trim(),
            }),
          )
          .timeout(const Duration(seconds: 15));

      final data = _decodeResponse(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(data['message']?.toString() ?? 'Yêu cầu thất bại.');
      }

      final profileData = data['data'];
      if (profileData is Map<String, dynamic>) return profileData;
      if (profileData is Map) return Map<String, dynamic>.from(profileData);

      throw const ApiException('Phản hồi API không hợp lệ.');
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException('Không thể cập nhật thông tin cá nhân.');
    }
  }

  String? buildAvatarUrl(String? avatarPath) {
    if (avatarPath == null || avatarPath.trim().isEmpty) return null;
    final avatar = avatarPath.trim();
    if (avatar.startsWith('http://') || avatar.startsWith('https://')) {
      return avatar;
    }

    final apiUri = Uri.parse(AuthService.baseUrl);
    final origin = '${apiUri.scheme}://${apiUri.authority}';
    return '$origin$avatar';
  }

  Future<String> uploadAvatar(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw const ApiException('Không tìm thấy ảnh đại diện đã chọn.');
      }

      final bytes = await file.readAsBytes();
      final fileName = file.uri.pathSegments.isNotEmpty
          ? file.uri.pathSegments.last
          : 'avatar.jpg';
      final headers = await AuthService.authHeaders();
      final response = await _client
          .patch(
            Uri.parse('${AuthService.baseUrl}/profile/avatar'),
            headers: {...headers, 'Content-Type': 'application/json'},
            body: jsonEncode({
              'fileName': fileName,
              'imageBase64': base64Encode(bytes),
            }),
          )
          .timeout(const Duration(seconds: 30));

      final data = _decodeResponse(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(data['message']?.toString() ?? 'Yêu cầu thất bại.');
      }

      final responseData = data['data'];
      if (responseData is Map) {
        final avatar = responseData['avatar']?.toString();
        if (avatar != null && avatar.isNotEmpty) return avatar;
      }

      throw const ApiException('Phản hồi API không hợp lệ.');
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException('Không thể cập nhật ảnh đại diện.');
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
