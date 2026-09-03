import 'dart:convert';

import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'auth_service.dart';

class ProjectService {
  ProjectService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<Map<String, dynamic>>> getProjects({bool ascending = true}) async {
    final data = await _request(
      method: 'GET',
      path: '/projects?sort=${ascending ? 'asc' : 'desc'}',
    );
    final projects = data['data'];
    if (projects is! List) return [];
    return projects
        .whereType<Map>()
        .map((project) => Map<String, dynamic>.from(project))
        .toList();
  }

  Future<List<Map<String, dynamic>>> getCompletedProjects({
    bool ascending = false,
  }) async {
    final data = await _request(
      method: 'GET',
      path: '/projects/completed?sort=${ascending ? 'asc' : 'desc'}',
    );
    final projects = data['data'];
    if (projects is! List) return [];
    return projects
        .whereType<Map>()
        .map((project) => Map<String, dynamic>.from(project))
        .toList();
  }

  Future<Map<String, dynamic>> createProject({
    required String name,
    String? description,
    DateTime? deadline,
    List<String> memberEmails = const [],
  }) async {
    final data = await _request(
      method: 'POST',
      path: '/projects',
      body: {
        'name': name,
        'description': description,
        if (deadline != null) 'end_date': _formatApiDate(deadline),
        if (memberEmails.isNotEmpty) 'member_emails': memberEmails,
      },
    );

    final responseData = data['data'];
    if (responseData is Map) {
      return Map<String, dynamic>.from(responseData);
    }
    return data;
  }

  Future<List<Map<String, dynamic>>> getProjectInvitations({
    String status = 'pending',
  }) async {
    final data = await _request(
      method: 'GET',
      path: '/projects/invitations?status=$status',
    );
    final invitations = data['data'];
    if (invitations is! List) return [];
    return invitations
        .whereType<Map>()
        .map((invitation) => Map<String, dynamic>.from(invitation))
        .toList();
  }

  Future<Map<String, dynamic>> getProjectDetail(String projectId) async {
    late final Map<String, dynamic> data;
    try {
      data = await _request(
        method: 'GET',
        path: '/project-detail/$projectId',
      );
    } on ApiException catch (err) {
      final message = err.toString();
      if (!message.contains('/api/project-detail') &&
          !message.contains('Không tìm thấy API dự án')) {
        rethrow;
      }

      final fallback = await _request(
        method: 'GET',
        path: '/projects/$projectId',
      );
      final fallbackData = fallback['data'];
      if (fallbackData is Map) {
        final totalTasks = NumberParser.toInt(fallbackData['totalTasks']);
        final completedTasks = NumberParser.toInt(
          fallbackData['completedTasks'],
        );
        return {
          'project': Map<String, dynamic>.from(fallbackData),
          'current_user_id': null,
          'members': const [],
          'tasks': const [],
          'stats': {
            'total_tasks': totalTasks,
            'completed_tasks': completedTasks,
            'incomplete_tasks': totalTasks - completedTasks,
            'member_count': NumberParser.toInt(fallbackData['members']),
          },
        };
      }
      data = fallback;
    }

    final responseData = data['data'];
    if (responseData is Map) {
      return Map<String, dynamic>.from(responseData);
    }
    return data;
  }

  Future<ProjectReportFile> downloadCompletedProjectReport(
    String projectId,
  ) async {
    try {
      final headers = await AuthService.authHeaders();
      final uri = Uri.parse('${AuthService.baseUrl}/projects/$projectId/report');
      final response = await _client
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 30));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final data = _decodeResponse(response.body, response.statusCode);
        throw ApiException(
          data['message']?.toString() ?? 'Không thể xuất báo cáo.',
        );
      }

      return ProjectReportFile(
        fileName: _fileNameFromContentDisposition(
          response.headers['content-disposition'],
        ),
        bytes: response.bodyBytes,
      );
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException(
        'Không thể xuất báo cáo. Kiểm tra backend đã chạy chưa.',
      );
    }
  }

  Future<List<Map<String, dynamic>>> createTask({
    required String projectId,
    required String title,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    List<int> assigneeIds = const [],
    List<String> subtasks = const [],
    List<Map<String, dynamic>> attachments = const [],
  }) async {
    final data = await _request(
      method: 'POST',
      path: '/project-detail/$projectId/tasks',
      body: {
        'title': title,
        'description': description,
        if (startDate != null) 'start_date': _formatApiDate(startDate),
        if (endDate != null) 'end_date': _formatApiDate(endDate),
        'assignee_ids': assigneeIds,
        if (subtasks.isNotEmpty) 'subtasks': subtasks,
        if (attachments.isNotEmpty) 'attachments': attachments,
      },
    );

    final responseData = data['data'];
    if (responseData is Map && responseData['tasks'] is List) {
      return (responseData['tasks'] as List)
          .whereType<Map>()
          .map((task) => Map<String, dynamic>.from(task))
          .toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> getCreateTaskOptions(String projectId) async {
    final data = await _request(
      method: 'GET',
      path: '/project-detail/$projectId/task-options',
    );

    final responseData = data['data'];
    if (responseData is Map) {
      return Map<String, dynamic>.from(responseData);
    }
    return data;
  }

  Future<Map<String, dynamic>> getTimeline({
    required DateTime weekStart,
    String? projectId,
  }) async {
    final query = <String>[
      'week_start=${_formatApiDate(weekStart)}',
      if (projectId != null && projectId.isNotEmpty) 'project_id=$projectId',
    ].join('&');

    final data = await _request(
      method: 'GET',
      path: '/timeline?$query',
    );

    final responseData = data['data'];
    if (responseData is Map) {
      return Map<String, dynamic>.from(responseData);
    }
    return data;
  }

  Future<Map<String, dynamic>> sendProjectInvitation({
    required String projectId,
    required String email,
    int projectRoleId = 3,
  }) async {
    final data = await _request(
      method: 'POST',
      path: '/projects/$projectId/invitations',
      body: {
        'email': email,
        'project_role_id': projectRoleId,
      },
    );

    final responseData = data['data'];
    if (responseData is Map) {
      return Map<String, dynamic>.from(responseData);
    }
    return data;
  }

  Future<void> acceptProjectInvitation(String invitationId) async {
    await _request(
      method: 'PATCH',
      path: '/projects/invitations/$invitationId/accept',
    );
  }

  Future<void> declineProjectInvitation(String invitationId) async {
    await _request(
      method: 'PATCH',
      path: '/projects/invitations/$invitationId/decline',
    );
  }

  Future<List<Map<String, dynamic>>> getSentProjectInvitations({
    required String projectId,
    String status = 'pending',
  }) async {
    final data = await _request(
      method: 'GET',
      path: '/projects/$projectId/invitations/sent?status=$status',
    );

    final responseData = data['data'];
    if (responseData is List) {
      return responseData
          .whereType<Map>()
          .map((invitation) => Map<String, dynamic>.from(invitation))
          .toList();
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> deleteSentProjectInvitation({
    required String projectId,
    required String invitationId,
  }) async {
    final data = await _request(
      method: 'DELETE',
      path: '/projects/$projectId/invitations/$invitationId',
    );

    final responseData = data['data'];
    if (responseData is Map && responseData['invitations'] is List) {
      return (responseData['invitations'] as List)
          .whereType<Map>()
          .map((invitation) => Map<String, dynamic>.from(invitation))
          .toList();
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> updateProjectMemberRole({
    required String projectId,
    required String memberId,
    required int projectRoleId,
  }) async {
    final data = await _request(
      method: 'PATCH',
      path: '/project-detail/$projectId/members/$memberId/role',
      body: {'project_role_id': projectRoleId},
    );

    final responseData = data['data'];
    if (responseData is Map && responseData['members'] is List) {
      return (responseData['members'] as List)
          .whereType<Map>()
          .map((member) => Map<String, dynamic>.from(member))
          .toList();
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> deleteProjectMember({
    required String projectId,
    required String memberId,
  }) async {
    final data = await _request(
      method: 'DELETE',
      path: '/project-detail/$projectId/members/$memberId',
    );

    final responseData = data['data'];
    if (responseData is Map && responseData['members'] is List) {
      return (responseData['members'] as List)
          .whereType<Map>()
          .map((member) => Map<String, dynamic>.from(member))
          .toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> getTaskDetail(String taskId) async {
    final data = await _request(method: 'GET', path: '/task-detail/$taskId');
    final responseData = data['data'];
    if (responseData is Map) {
      return Map<String, dynamic>.from(responseData);
    }
    return data;
  }

  Future<Map<String, dynamic>> updateTaskStatus({
    required String taskId,
    required String status,
  }) async {
    final data = await _request(
      method: 'PATCH',
      path: '/task-detail/$taskId/status',
      body: {'status': status},
    );
    final responseData = data['data'];
    if (responseData is Map) {
      return Map<String, dynamic>.from(responseData);
    }
    return data;
  }

  Future<Map<String, dynamic>> updateTask({
    required String taskId,
    String? title,
    String? description,
    DateTime? dueDate,
    String? status,
    String? assigneeId,
    List<int>? assigneeIds,
  }) async {
    final data = await _request(
      method: 'PATCH',
      path: '/task-detail/$taskId',
      body: {
        if (title != null) 'title': title,
        if (description != null) 'description': description,
        if (dueDate != null) 'due_date': _formatApiDate(dueDate),
        if (status != null) 'status': status,
        if (assigneeIds != null) 'assignee_ids': assigneeIds,
        if (assigneeId != null) 'assignee_id': assigneeId,
      },
    );
    final responseData = data['data'];
    if (responseData is Map) {
      return Map<String, dynamic>.from(responseData);
    }
    return data;
  }

  Future<void> deleteTask(String taskId) async {
    await _request(method: 'DELETE', path: '/task-detail/$taskId');
  }

  Future<Map<String, dynamic>> createTaskSubtask({
    required String taskId,
    required String title,
  }) async {
    final data = await _request(
      method: 'POST',
      path: '/task-detail/$taskId/subtasks',
      body: {'title': title},
    );
    final responseData = data['data'];
    if (responseData is Map) {
      return Map<String, dynamic>.from(responseData);
    }
    return data;
  }

  Future<Map<String, dynamic>> updateTaskSubtask({
    required String taskId,
    required String subtaskId,
    bool? isCompleted,
    String? title,
  }) async {
    final data = await _request(
      method: 'PATCH',
      path: '/task-detail/$taskId/subtasks/$subtaskId',
      body: {
        if (isCompleted != null) 'is_completed': isCompleted,
        if (title != null) 'title': title,
      },
    );
    final responseData = data['data'];
    if (responseData is Map) {
      return Map<String, dynamic>.from(responseData);
    }
    return data;
  }

  Future<Map<String, dynamic>> createTaskAttachment({
    required String taskId,
    required String fileName,
    required String fileUrl,
    required String fileType,
    int? fileSize,
    String? mimeType,
  }) async {
    final data = await _request(
      method: 'POST',
      path: '/task-detail/$taskId/attachments',
      body: {
        'file_name': fileName,
        'file_url': fileUrl,
        'file_type': fileType,
        if (fileSize != null) 'file_size': fileSize,
        if (mimeType != null) 'mime_type': mimeType,
      },
    );
    final responseData = data['data'];
    if (responseData is Map) {
      return Map<String, dynamic>.from(responseData);
    }
    return data;
  }

  Future<void> deleteTaskAttachment({
    required String taskId,
    required String attachmentId,
  }) async {
    await _request(
      method: 'DELETE',
      path: '/task-detail/$taskId/attachments/$attachmentId',
    );
  }

  Future<Map<String, dynamic>> createTaskComment({
    required String taskId,
    required String content,
  }) async {
    final data = await _request(
      method: 'POST',
      path: '/task-detail/$taskId/comments',
      body: {'content': content},
    );
    final responseData = data['data'];
    if (responseData is Map) {
      return Map<String, dynamic>.from(responseData);
    }
    return data;
  }

  Future<Map<String, dynamic>> updateTaskComment({
    required String taskId,
    required String commentId,
    required String content,
  }) async {
    final data = await _request(
      method: 'PATCH',
      path: '/task-detail/$taskId/comments/$commentId',
      body: {'content': content},
    );
    final responseData = data['data'];
    if (responseData is Map) {
      return Map<String, dynamic>.from(responseData);
    }
    return data;
  }

  Future<void> deleteTaskComment({
    required String taskId,
    required String commentId,
  }) async {
    await _request(
      method: 'DELETE',
      path: '/task-detail/$taskId/comments/$commentId',
    );
  }

  Future<Map<String, dynamic>> updateProject({
    required String id,
    required String name,
    String? description,
    String? status,
  }) async {
    final data = await _request(
      method: 'PATCH',
      path: '/projects/$id',
      body: {
        'name': name,
        'description': description,
        if (status != null) 'status': status,
      },
    );

    final responseData = data['data'];
    if (responseData is Map) {
      return Map<String, dynamic>.from(responseData);
    }
    return data;
  }

  Future<void> deleteProject({
    required String id,
    required String password,
  }) async {
    await _request(
      method: 'DELETE',
      path: '/projects/$id',
      body: {'password': password},
    );
  }

  Future<Map<String, dynamic>> completeProject(String id) async {
    final data = await _request(
      method: 'PATCH',
      path: '/projects/$id/complete',
    );

    final responseData = data['data'];
    if (responseData is Map) {
      return Map<String, dynamic>.from(responseData);
    }
    return data;
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

      final response = switch (method) {
        'POST' => await _client
            .post(uri, headers: requestHeaders, body: jsonEncode(body ?? {}))
            .timeout(const Duration(seconds: 15)),
        'PATCH' => await _client
            .patch(uri, headers: requestHeaders, body: jsonEncode(body ?? {}))
            .timeout(const Duration(seconds: 15)),
        'DELETE' => await _client
            .delete(uri, headers: requestHeaders, body: jsonEncode(body ?? {}))
            .timeout(const Duration(seconds: 15)),
        _ => await _client
            .get(uri, headers: requestHeaders)
            .timeout(const Duration(seconds: 15)),
      };

      final data = _decodeResponse(response.body, response.statusCode);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(data['message']?.toString() ?? 'Yêu cầu thất bại.');
      }
      return data;
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException('Không thể kết nối API. Kiểm tra backend đã chạy chưa.');
    }
  }

  Map<String, dynamic> _decodeResponse(String body, int statusCode) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      return {'message': 'Phản hồi API không hợp lệ.'};
    } catch (_) {
      if (statusCode == 404) {
        return {
          'message':
              'Không tìm thấy API dự án. Hãy khởi động lại backend để nạp route mới.',
        };
      }
      return {'message': 'Phản hồi API không hợp lệ.'};
    }
  }

  String _formatApiDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  String _fileNameFromContentDisposition(String? value) {
    const fallback = 'bao-cao-du-an.docx';
    if (value == null || value.isEmpty) return fallback;
    final match = RegExp(r'filename="?([^";]+)"?').firstMatch(value);
    return match?.group(1) ?? fallback;
  }
}

class ProjectReportFile {
  const ProjectReportFile({required this.fileName, required this.bytes});

  final String fileName;
  final Uint8List bytes;
}

class NumberParser {
  static int toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
