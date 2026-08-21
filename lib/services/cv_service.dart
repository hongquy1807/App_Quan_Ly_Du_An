import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'auth_service.dart';

class CvExportFile {
  const CvExportFile({required this.fileName, required this.bytes});

  final String fileName;
  final Uint8List bytes;
}

class CvService {
  CvService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<Map<String, dynamic>> getCv() async {
    final data = await _request(method: 'GET', path: '/cv');
    final responseData = data['data'];
    if (responseData is Map<String, dynamic>) return responseData;
    if (responseData is Map) return Map<String, dynamic>.from(responseData);
    throw const ApiException('Phản hồi API không hợp lệ.');
  }

  Future<Map<String, dynamic>> saveCv({
    required String title,
    required String objective,
    required String education,
    required String skills,
    required String softSkills,
    required String languages,
    required String projects,
    required String certificates,
  }) async {
    final data = await _request(
      method: 'PUT',
      path: '/cv',
      body: {
        'title': title,
        'objective': objective,
        'education': education,
        'skills': skills,
        'softSkills': softSkills,
        'languages': languages,
        'projects': projects,
        'certificates': certificates,
      },
    );
    final responseData = data['data'];
    if (responseData is Map<String, dynamic>) return responseData;
    if (responseData is Map) return Map<String, dynamic>.from(responseData);
    return data;
  }

  Future<CvExportFile> downloadCv(String type) async {
    final headers = await AuthService.authHeaders();
    try {
      final response = await _client
          .get(
            Uri.parse('${AuthService.baseUrl}/cv/export/$type'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final data = _decodeResponse(response.body);
        throw ApiException(data['message']?.toString() ?? 'Không thể xuất CV.');
      }

      final disposition = response.headers['content-disposition'] ?? '';
      final match = RegExp(r'filename="?([^";]+)').firstMatch(disposition);
      const fallback = 'CV.docx';
      return CvExportFile(
        fileName: match?.group(1) ?? fallback,
        bytes: response.bodyBytes,
      );
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException('Không thể kết nối API xuất CV.');
    }
  }

  Future<Map<String, dynamic>> _request({
    required String method,
    required String path,
    Map<String, dynamic>? body,
  }) async {
    final headers = await AuthService.authHeaders();
    try {
      late final http.Response response;
      final uri = Uri.parse('${AuthService.baseUrl}$path');
      if (method == 'GET') {
        response = await _client.get(uri, headers: headers).timeout(const Duration(seconds: 15));
      } else if (method == 'PUT') {
        response = await _client
            .put(
              uri,
              headers: {...headers, 'Content-Type': 'application/json'},
              body: jsonEncode(body ?? {}),
            )
            .timeout(const Duration(seconds: 15));
      } else {
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
      throw const ApiException('Không thể kết nối API CV.');
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
