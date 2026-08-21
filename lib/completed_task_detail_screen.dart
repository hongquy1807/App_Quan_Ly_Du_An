import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'app_theme_controller.dart';
import 'services/auth_service.dart';
import 'services/project_service.dart';

class CompletedTaskDetailScreen extends StatefulWidget {
  const CompletedTaskDetailScreen({
    super.key,
    required this.task,
    required this.project,
  });

  final Map<String, dynamic> task;
  final Map<String, dynamic> project;

  @override
  State<CompletedTaskDetailScreen> createState() =>
      _CompletedTaskDetailScreenState();
}

class _CompletedTaskDetailScreenState extends State<CompletedTaskDetailScreen> {
  final ProjectService _projectService = ProjectService();

  Map<String, dynamic> _task = {};
  Map<String, dynamic> _project = {};
  List<Map<String, dynamic>> _subtasks = [];
  List<Map<String, dynamic>> _attachments = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _task = Map<String, dynamic>.from(widget.task);
    _project = Map<String, dynamic>.from(widget.project);
    _loadTaskDetail();
  }

  Future<void> _loadTaskDetail() async {
    final taskId = _task['id']?.toString() ?? '';
    if (taskId.isEmpty) {
      setState(() {
        _error = 'Không tìm thấy nhiệm vụ.';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final detail = await _projectService.getTaskDetail(taskId);
      if (!mounted) return;
      final taskData = detail['task'];
      final projectData = detail['project'];
      final subtasksData = detail['subtasks'];
      final attachmentsData = detail['attachments'];

      setState(() {
        _task = taskData is Map
            ? _mapTask(Map<String, dynamic>.from(taskData))
            : _mapTask(_task);
        _project = projectData is Map
            ? Map<String, dynamic>.from(projectData)
            : _project;
        _subtasks = subtasksData is List
            ? subtasksData
                .whereType<Map>()
                .map((item) => _mapSubtask(Map<String, dynamic>.from(item)))
                .toList()
            : [];
        _attachments = attachmentsData is List
            ? attachmentsData
                .whereType<Map>()
                .map((item) => _mapAttachment(Map<String, dynamic>.from(item)))
                .toList()
            : [];
        _isLoading = false;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _error = err.toString();
        _isLoading = false;
      });
    }
  }

  Map<String, dynamic> _mapTask(Map<String, dynamic> task) {
    final statusCode = task['status_code']?.toString() ??
        task['statusCode']?.toString() ??
        '';
    return {
      ...task,
      'id': task['id']?.toString() ?? '',
      'title': task['title']?.toString() ?? '',
      'description': task['description']?.toString() ?? '',
      'assignee': task['assignee']?.toString() ??
          task['assignee_name']?.toString() ??
          'Cả team',
      'startDate': _parseDate(task['startDate'] ?? task['start_date']),
      'dueDate': _parseDate(task['dueDate'] ?? task['due_date']),
      'createdAt': _parseDate(task['createdAt'] ?? task['created_at']),
      'statusCode': statusCode,
      'isCompleted': task['isCompleted'] == true || statusCode == 'done',
    };
  }

  Map<String, dynamic> _mapSubtask(Map<String, dynamic> subtask) {
    return {
      'id': subtask['id']?.toString() ?? '',
      'title': subtask['title']?.toString() ?? '',
      'isCompleted': subtask['is_completed'] == true ||
          subtask['is_completed']?.toString() == '1' ||
          subtask['isCompleted'] == true,
    };
  }

  Map<String, dynamic> _mapAttachment(Map<String, dynamic> attachment) {
    final type = attachment['type']?.toString() ??
        attachment['file_type']?.toString() ??
        'document';
    return {
      'id': attachment['id']?.toString() ?? '',
      'name': attachment['name']?.toString() ??
          attachment['file_name']?.toString() ??
          'Tài liệu',
      'size': _formatFileSize(attachment['size'] ?? attachment['file_size']),
      'url': attachment['url'] ?? attachment['file_url'],
      'type': type,
    };
  }

  DateTime? _parseDate(dynamic value) {
    final text = value?.toString();
    if (text == null || text.isEmpty) return null;
    return DateTime.tryParse(text);
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '--/--/----';
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  String _formatFileSize(dynamic value) {
    final bytes = NumberParser.toInt(value);
    if (bytes <= 0) return '';
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '$bytes B';
  }

  String _statusText() {
    final statusCode = _task['statusCode']?.toString() ?? '';
    if (_task['isCompleted'] == true || statusCode == 'done') return 'Hoàn thành';
    if (statusCode == 'in_progress') return 'Đang làm';
    if (statusCode == 'review') return 'Chờ duyệt';
    return 'Chưa nhận';
  }

  Color _statusColor() {
    final statusCode = _task['statusCode']?.toString() ?? '';
    if (_task['isCompleted'] == true || statusCode == 'done') {
      return const Color(0xFF10B981);
    }
    if (statusCode == 'in_progress') return const Color(0xFF6366F1);
    if (statusCode == 'review') return const Color(0xFFF59E0B);
    return const Color(0xFF64748B);
  }

  IconData _attachmentIcon(String type) {
    final normalized = type.toLowerCase();
    if (normalized == 'image') return Icons.image_rounded;
    if (normalized == 'video') return Icons.videocam_rounded;
    return Icons.insert_drive_file_rounded;
  }

  Color _attachmentColor(String type) {
    final normalized = type.toLowerCase();
    if (normalized == 'image') return const Color(0xFF6366F1);
    if (normalized == 'video') return const Color(0xFFEC4899);
    return const Color(0xFFF59E0B);
  }

  String _fileUrl(Map<String, dynamic> file) {
    final rawUrl = file['url']?.toString().trim() ?? '';
    if (rawUrl.isEmpty) return '';
    if (rawUrl.startsWith('http://') || rawUrl.startsWith('https://')) {
      return rawUrl;
    }
    final base = AuthService.baseUrl.replaceFirst(RegExp(r'/api/?$'), '');
    final path = rawUrl.startsWith('/') ? rawUrl : '/$rawUrl';
    return '$base$path';
  }

  Future<void> _downloadAttachment(Map<String, dynamic> file) async {
    final url = _fileUrl(file);
    if (url.isEmpty) {
      _showMessage('Không có đường dẫn file.');
      return;
    }

    final uri = Uri.tryParse(url);
    if (uri == null) {
      _showMessage('Đường dẫn file không hợp lệ.');
      return;
    }

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 30));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException('Không thể tải file.');
      }

      final savedPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Lưu file',
        fileName: file['name']?.toString() ?? 'attachment',
        bytes: response.bodyBytes,
      );

      if (!mounted || savedPath == null) return;
      _showMessage('Đã tải file xuống.');
    } catch (err) {
      if (!mounted) return;
      _showMessage(err is ApiException ? err.message : 'Không thể tải file.');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = appThemeController;
    return Scaffold(
      backgroundColor: theme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(theme),
            Expanded(
              child: RefreshIndicator(
                color: theme.primaryColor,
                onRefresh: _loadTaskDetail,
                child: _buildBody(theme),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(AppThemeController theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            color: theme.textColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chi tiết nhiệm vụ',
                  style: TextStyle(
                    color: theme.mutedTextColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _task['title']?.toString() ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.textColor,
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(AppThemeController theme) {
    if (_isLoading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 180),
          Center(child: CircularProgressIndicator(color: theme.primaryColor)),
        ],
      );
    }

    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 150, 24, 24),
        children: [
          Icon(Icons.error_outline_rounded, size: 72, color: theme.primaryColor),
          const SizedBox(height: 16),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold),
          ),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
      children: [
        _buildInfoSection(theme),
        const SizedBox(height: 16),
        _buildDescriptionSection(theme),
        const SizedBox(height: 16),
        _buildSubtaskSection(theme),
        const SizedBox(height: 16),
        _buildAttachmentSection(theme),
      ],
    );
  }

  Widget _buildInfoSection(AppThemeController theme) {
    return _buildSection(
      title: 'Thông tin nhiệm vụ',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildInfoTile(
                  Icons.calendar_today_rounded,
                  'Ngày giao',
                  _formatDate(_task['createdAt'] as DateTime?),
                  theme.primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInfoTile(
                  Icons.access_time_rounded,
                  'Hạn chót',
                  _formatDate(_task['dueDate'] as DateTime?),
                  const Color(0xFF10B981),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoTile(
            Icons.person_rounded,
            'Người thực hiện',
            _task['assignee']?.toString() ?? 'Cả team',
            const Color(0xFF8B5CF6),
          ),
          const SizedBox(height: 12),
          _buildInfoTile(
            Icons.folder_rounded,
            'Thuộc dự án',
            _project['name']?.toString() ?? widget.project['name']?.toString() ?? '',
            theme.primaryColor,
          ),
          const SizedBox(height: 12),
          _buildInfoTile(
            Icons.verified_rounded,
            'Trạng thái',
            _statusText(),
            _statusColor(),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionSection(AppThemeController theme) {
    return _buildSection(
      title: 'Mô tả',
      child: Text(
        _task['description']?.toString().isNotEmpty == true
            ? _task['description'].toString()
            : 'Không có mô tả.',
        style: TextStyle(
          color: theme.mutedTextColor,
          fontSize: 14,
          height: 1.45,
        ),
      ),
    );
  }

  Widget _buildSubtaskSection(AppThemeController theme) {
    final completed = _subtasks.where((item) => item['isCompleted'] == true).length;
    return _buildSection(
      title: 'Nhiệm vụ con',
      trailing: '$completed/${_subtasks.length}',
      child: _subtasks.isEmpty
          ? Text('Không có nhiệm vụ con.', style: TextStyle(color: theme.mutedTextColor))
          : Column(
              children: _subtasks.map((subtask) {
                final done = subtask['isCompleted'] == true;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    done ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                    color: done ? const Color(0xFF10B981) : theme.mutedTextColor,
                  ),
                  title: Text(
                    subtask['title']?.toString() ?? '',
                    style: TextStyle(
                      color: done ? theme.mutedTextColor : theme.textColor,
                      decoration: done ? TextDecoration.lineThrough : null,
                    ),
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildAttachmentSection(AppThemeController theme) {
    return _buildSection(
      title: 'Tài liệu',
      trailing: '${_attachments.length} file',
      child: _attachments.isEmpty
          ? Text('Không có tài liệu.', style: TextStyle(color: theme.mutedTextColor))
          : Column(
              children: _attachments.map(_buildAttachmentItem).toList(),
            ),
    );
  }

  Widget _buildAttachmentItem(Map<String, dynamic> file) {
    final theme = appThemeController;
    final type = file['type']?.toString() ?? 'document';
    final color = _attachmentColor(type);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.backgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_attachmentIcon(type), color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file['name']?.toString() ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                if ((file['size']?.toString() ?? '').isNotEmpty)
                  Text(
                    file['size'].toString(),
                    style: TextStyle(color: theme.mutedTextColor, fontSize: 12),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _downloadAttachment(file),
            icon: Icon(Icons.download_rounded, color: theme.mutedTextColor),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required Widget child,
    String? trailing,
  }) {
    final theme = appThemeController;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.mutedTextColor.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: theme.textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (trailing != null)
                Text(
                  trailing,
                  style: TextStyle(
                    color: theme.primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildInfoTile(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    final theme = appThemeController;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(color: theme.mutedTextColor, fontSize: 12),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.textColor,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
