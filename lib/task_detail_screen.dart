import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme_controller.dart';
import 'services/auth_service.dart';
import 'services/project_service.dart';
import 'utils/color_utils.dart';

enum TaskDetailLanguage { vietnamese, english, chinese }

class TaskDetailScreen extends StatefulWidget {
  final Map<String, dynamic> task;
  final Map<String, dynamic> project;
  final bool startEditing;

  const TaskDetailScreen({
    super.key,
    required this.task,
    required this.project,
    this.startEditing = false,
  });

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  final ProjectService _projectService = ProjectService();
  TaskDetailLanguage _language = TaskDetailLanguage.vietnamese;
  bool _isLoadingDetail = true;
  String? _detailError;
  late Map<String, dynamic> _task;
  late Map<String, dynamic> _project;
  bool _isPickingAttachment = false;

  final List<Map<String, dynamic>> _comments = [];

  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _editingCommentController =
      TextEditingController();
  final TextEditingController _editingTaskTitleController =
      TextEditingController();
  final TextEditingController _editingTaskDescriptionController =
      TextEditingController();
  bool _isSubmittingComment = false;
  bool _isEditingTask = false;
  bool _isSavingTask = false;
  String? _editingCommentId;
  late DateTime _editingTaskDueDate;
  late String _editingTaskStatusCode;
  late String _taskStatus;

  @override
  void initState() {
    super.initState();
    _task = Map<String, dynamic>.from(widget.task);
    _project = Map<String, dynamic>.from(widget.project);
    _loadLanguage();
    _taskStatus = _task['status']?.toString() ?? 'Chưa nhận';
    _editingTaskDueDate = _task['dueDate'] is DateTime
        ? _task['dueDate'] as DateTime
        : DateTime.now();
    _editingTaskStatusCode = _task['statusCode']?.toString() ??
        _statusCodeFromTaskStatus(_taskStatus);
    if (widget.startEditing) {
      _startEditTaskInline();
    }
    _loadTaskDetail();
  }

  String _t(String vi, String en, String zh) {
    switch (_language) {
      case TaskDetailLanguage.vietnamese:
        return vi;
      case TaskDetailLanguage.english:
        return en;
      case TaskDetailLanguage.chinese:
        return zh;
    }
  }

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final rawValue = prefs.getString('app_language');
    if (!mounted) return;
    setState(() {
      _language = TaskDetailLanguage.values.firstWhere(
        (language) => language.name == rawValue,
        orElse: () => TaskDetailLanguage.vietnamese,
      );
    });
  }

  Future<void> _loadTaskDetail() async {
    final taskId = _task['id']?.toString() ?? '';
    if (taskId.isEmpty) {
      setState(() {
        _isLoadingDetail = false;
        _detailError = 'Không tìm thấy ID nhiệm vụ.';
      });
      return;
    }

    setState(() {
      _isLoadingDetail = true;
      _detailError = null;
    });

    try {
      final detail = await _projectService.getTaskDetail(taskId);
      final taskData = detail['task'];
      final projectData = detail['project'];
      final subtasksData = detail['subtasks'];
      final attachmentsData = detail['attachments'];
      final commentsData = detail['comments'];

      if (!mounted) return;
      setState(() {
        if (taskData is Map) {
          _task = _mapApiTask(Map<String, dynamic>.from(taskData));
        }
        if (projectData is Map) {
          _project = {
            ..._project,
            ...Map<String, dynamic>.from(projectData),
          };
        }
        _taskStatus = _task['status']?.toString() ?? _taskStatus;
        if (_isEditingTask) {
          _fillTaskEditControllers();
        }
        _subtasks
          ..clear()
          ..addAll(
            subtasksData is List
                ? subtasksData
                    .whereType<Map>()
                    .map((item) => _mapApiSubtask(Map<String, dynamic>.from(item)))
                : const [],
          );
        _attachments
          ..clear()
          ..addAll(
            attachmentsData is List
                ? attachmentsData
                    .whereType<Map>()
                    .map((item) => _mapApiAttachment(Map<String, dynamic>.from(item)))
                : const [],
          );
        _comments
          ..clear()
          ..addAll(
            commentsData is List
                ? commentsData
                    .whereType<Map>()
                    .map((item) => _mapApiComment(Map<String, dynamic>.from(item)))
                : const [],
          );
        _isLoadingDetail = false;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _detailError = err.toString();
        _isLoadingDetail = false;
      });
    }
  }

  Map<String, dynamic> _mapApiTask(Map<String, dynamic> task) {
    final dueDate = _parseApiDate(task['dueDate'] ?? task['due_date']);
    final createdAt = _parseApiDate(task['createdAt'] ?? task['created_at']);
    final statusCode = task['status_code']?.toString() ??
        task['statusCode']?.toString() ??
        _statusCodeFromTaskStatus(task['status']?.toString() ?? '');
    final status = _labelFromStatusCode(statusCode);
    return {
      ..._task,
      ...task,
      'id': task['id']?.toString() ?? _task['id']?.toString() ?? '',
      'title': task['title']?.toString() ?? '',
      'description': task['description']?.toString() ?? '',
      'assignee': task['assignee']?.toString() ?? 'Cả team',
      'dueDate': dueDate,
      'createdAt': createdAt,
      'status': status,
      'statusCode': statusCode,
      'isCompleted': task['isCompleted'] == true || statusCode == 'done',
    };
  }

  Map<String, dynamic> _mapApiSubtask(Map<String, dynamic> subtask) {
    final completed = subtask['isCompleted'] == true || subtask['is_completed'] == true;
    return {
      'id': subtask['id']?.toString() ?? '',
      'title': subtask['title']?.toString() ?? '',
      'isCompleted': completed,
    };
  }

  Map<String, dynamic> _mapApiAttachment(Map<String, dynamic> attachment) {
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
      'icon': _attachmentIcon(type),
      'color': _attachmentColor(type),
    };
  }

  Map<String, dynamic> _mapApiComment(Map<String, dynamic> comment) {
    return {
      'id': comment['id']?.toString() ?? '',
      'user': comment['user']?.toString() ??
          comment['user_name']?.toString() ??
          'Thành viên',
      'avatar': comment['avatar']?.toString() ?? '',
      'content': comment['content']?.toString() ?? '',
      'time': _parseApiDate(comment['time'] ?? comment['created_at']),
      'isMine': comment['isMine'] == true,
    };
  }

  DateTime _parseApiDate(dynamic value) {
    if (value is DateTime) return value;
    final text = value?.toString();
    if (text == null || text.isEmpty) return DateTime.now();
    return DateTime.tryParse(text) ?? DateTime.now();
  }

  String _formatFileSize(dynamic value) {
    final bytes = NumberParser.toInt(value);
    if (bytes <= 0) return '';
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '$bytes B';
  }

  IconData _attachmentIcon(String type) {
    switch (type) {
      case 'image':
        return Icons.image_rounded;
      case 'video':
        return Icons.videocam_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  Color _attachmentColor(String type) {
    switch (type) {
      case 'image':
        return const Color(0xFF6366F1);
      case 'video':
        return const Color(0xFFEC4899);
      default:
        return const Color(0xFF10B981);
    }
  }

  String _taskTitle(Map<String, dynamic> task) {
    switch (task['id']?.toString()) {
      case '1':
        return _t(
          'Thiết kế UI cho màn hình chính',
          'Design UI for the main screen',
          '设计主屏幕 UI',
        );
      case '2':
        return _t('Xây dựng API đăng nhập', 'Build login API', '构建登录 API');
      case '3':
        return _t(
          'Tối ưu hiệu suất ứng dụng',
          'Optimize app performance',
          '优化应用性能',
        );
      case '4':
        return _t(
          'Phân tích yêu cầu dự án',
          'Analyze project requirements',
          '分析项目需求',
        );
      case '5':
        return _t('Thiết kế database', 'Design database', '设计数据库');
      case '6':
        return _t('Viết unit test', 'Write unit tests', '编写单元测试');
      case '7':
        return _t(
          'Deploy lên production',
          'Deploy to production',
          '部署到生产环境',
        );
      case '8':
        return _t('Code review', 'Code review', '代码审查');
      default:
        return task['title']?.toString() ?? '';
    }
  }

  String _taskDescription(Map<String, dynamic> task) {
    switch (task['id']?.toString()) {
      case '1':
        return _t(
          'Thiết kế giao diện người dùng cho màn hình chính của ứng dụng',
          'Design the user interface for the app main screen',
          '为应用主屏幕设计用户界面',
        );
      case '2':
        return _t(
          'Tạo API cho chức năng đăng nhập và đăng ký',
          'Create APIs for sign-in and sign-up',
          '创建登录和注册功能的 API',
        );
      case '3':
        return _t(
          'Tối ưu hóa hiệu suất và giảm thời gian tải',
          'Optimize performance and reduce loading time',
          '优化性能并减少加载时间',
        );
      case '4':
        return _t(
          'Phân tích và document yêu cầu từ khách hàng',
          'Analyze and document customer requirements',
          '分析并记录客户需求',
        );
      case '5':
        return _t(
          'Thiết kế cơ sở dữ liệu cho hệ thống',
          'Design the database for the system',
          '为系统设计数据库',
        );
      default:
        return task['description']?.toString() ??
            _t(
              'Chưa có mô tả cho nhiệm vụ này.',
              'No description for this task yet.',
              '此任务暂无描述。',
            );
    }
  }

  String _projectName(Map<String, dynamic> project) {
    switch (project['id']?.toString()) {
      case '1':
        return _t('App di động', 'Mobile app', '移动应用');
      case '2':
        return _t('Website bán hàng', 'Sales website', '销售网站');
      case '3':
        return _t('Dự án AI', 'AI project', 'AI 项目');
      case '4':
        return _t('Hệ thống CRM', 'CRM system', 'CRM 系统');
      default:
        return project['name']?.toString() ?? '';
    }
  }

  String _subtaskTitle(Map<String, dynamic> subtask) {
    return subtask['title']?.toString() ?? '';
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'Chưa nhận':
      case 'Chưa bắt đầu':
        return _t('Chưa nhận', 'Not accepted', '未接收');
      case 'Đã nhận nhiệm vụ':
      case 'Đang làm':
        return _t('Đã nhận nhiệm vụ', 'Accepted task', '已接收任务');
      case 'Hoàn thành':
        return _t('Hoàn thành', 'Completed', '已完成');
      default:
        return status;
    }
  }

  String _statusCodeFromTaskStatus(String status) {
    switch (status) {
      case 'in_progress':
      case 'Đã nhận nhiệm vụ':
      case 'Đang làm':
        return 'in_progress';
      case 'done':
      case 'Hoàn thành':
        return 'done';
      case 'review':
        return 'review';
      case 'todo':
      case 'Chưa nhận':
      case 'Chưa bắt đầu':
      default:
        return 'todo';
    }
  }

  String _labelFromStatusCode(String statusCode) {
    switch (statusCode) {
      case 'in_progress':
        return _t('Đã nhận nhiệm vụ', 'Accepted task', '已接收任务');
      case 'done':
        return _t('Hoàn thành', 'Completed', '已完成');
      case 'review':
        return _t('Chờ duyệt', 'Pending review', '待审核');
      case 'todo':
      default:
        return _t('Chưa nhận', 'Not accepted', '未接收');
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  void _fillTaskEditControllers() {
    _editingTaskTitleController.text = _task['title']?.toString() ?? '';
    _editingTaskDescriptionController.text =
        _task['description']?.toString() ?? '';
    _editingTaskDueDate = _task['dueDate'] is DateTime
        ? _task['dueDate'] as DateTime
        : DateTime.now();
    _editingTaskStatusCode = _task['statusCode']?.toString() ??
        _statusCodeFromTaskStatus(_task['status']?.toString() ?? '');
  }

  void _startEditTaskInline() {
    _fillTaskEditControllers();
    _isEditingTask = true;
  }

  void _toggleEditTaskInline() {
    setState(() {
      if (_isEditingTask) {
        _isEditingTask = false;
      } else {
        _startEditTaskInline();
      }
    });
  }

  void _cancelEditTaskInline() {
    setState(() {
      _isEditingTask = false;
      _isSavingTask = false;
    });
  }

  Future<void> _submitEditTaskInline() async {
    final title = _editingTaskTitleController.text.trim();
    if (title.isEmpty || _isSavingTask) return;

    setState(() {
      _isSavingTask = true;
    });

    try {
      final detail = await _updateTaskApi(
        taskId: _task['id'].toString(),
        title: title,
        description: _editingTaskDescriptionController.text.trim(),
        dueDate: _editingTaskDueDate,
        status: _editingTaskStatusCode,
      );
      final taskData = detail['task'];
      if (!mounted || taskData is! Map) return;
      setState(() {
        _task = _mapApiTask(Map<String, dynamic>.from(taskData));
        _taskStatus = _task['status']?.toString() ?? _taskStatus;
        _isEditingTask = false;
        _isSavingTask = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t('Đã cập nhật nhiệm vụ', 'Task updated', '任务已更新'),
          ),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _isSavingTask = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err.toString()),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  Future<Map<String, dynamic>> _updateTaskApi({
    required String taskId,
    String? title,
    String? description,
    DateTime? dueDate,
    String? status,
  }) async {
    final data = await _commentRequest(
      method: 'PATCH',
      path: '/task-detail/$taskId',
      body: {
        if (title != null) 'title': title,
        if (description != null) 'description': description,
        if (dueDate != null) 'due_date': _formatApiDate(dueDate),
        if (status != null) 'status': status,
      },
    );
    final responseData = data['data'];
    if (responseData is Map) {
      return Map<String, dynamic>.from(responseData);
    }
    return data;
  }

  String _formatApiDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  String _commentContent(Map<String, dynamic> comment) {
    return comment['content']?.toString() ?? '';
  }

  final List<Map<String, dynamic>> _attachments = [];
  final List<Map<String, dynamic>> _subtasks = [];

  @override
  void dispose() {
    _commentController.dispose();
    _editingCommentController.dispose();
    _editingTaskTitleController.dispose();
    _editingTaskDescriptionController.dispose();
    super.dispose();
  }

  Future<void> _handleAddComment() async {
    if (_commentController.text.trim().isEmpty) return;

    setState(() {
      _isSubmittingComment = true;
    });

    try {
      final comment = await _projectService.createTaskComment(
        taskId: _task['id'].toString(),
        content: _commentController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _comments.insert(0, _mapApiComment(comment));
        _commentController.clear();
        _isSubmittingComment = false;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _isSubmittingComment = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err.toString()),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  Future<void> _handleToggleSubtask(String id) async {
    final index = _subtasks.indexWhere((st) => st['id'] == id);
    if (index == -1) return;
    final currentValue = _subtasks[index]['isCompleted'] == true;
    setState(() {
      _subtasks[index]['isCompleted'] = !currentValue;
    });

    try {
      await _projectService.updateTaskSubtask(
        taskId: _task['id'].toString(),
        subtaskId: id,
        isCompleted: !currentValue,
      );
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _subtasks[index]['isCompleted'] = currentValue;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err.toString()),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = appThemeController;
    final task = _task;
    final project = _project;
    final projectColor = parseHexColor(project['color']);

    return Scaffold(
      backgroundColor: appThemeController.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: theme.surfaceColor,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.backgroundColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 20,
                        color: theme.textColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _t('Chi tiết nhiệm vụ', 'Task details', '任务详情'),
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.mutedTextColor,
                          ),
                        ),
                        Text(
                          _taskTitle(task),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: theme.textColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _toggleEditTaskInline,
                    icon: Icon(
                      _isEditingTask
                          ? Icons.close_rounded
                          : Icons.edit_rounded,
                    ),
                    color: theme.textColor,
                    tooltip: _t('Sửa nhiệm vụ', 'Edit task', '编辑任务'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Nội dung chính
            Expanded(
              child: _isLoadingDetail
                  ? Center(child: CircularProgressIndicator(color: projectColor))
                  : _detailError != null
                      ? _buildErrorState(projectColor)
                      : SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Thông tin cơ bản
                    _buildInfoSection(projectColor),
                    const SizedBox(height: 16),

                    // Subtasks
                    _buildSubtaskSection(),
                    const SizedBox(height: 16),

                    // Tài liệu của người nhận
                    _buildMyAttachmentSection(),
                    const SizedBox(height: 16),

                    // Comments
                    _buildCommentSection(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(Color projectColor) {
    final theme = appThemeController;
    final task = _task;
    final dueDate = task['dueDate'] as DateTime;
    final createdAt = task['createdAt'] as DateTime;
    final isOverdue = dueDate.isBefore(DateTime.now()) && !task['isCompleted'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            _t('Thông tin nhiệm vụ', 'Task information', '任务信息'),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: theme.textColor,
            ),
          ),
          const SizedBox(height: 16),
          if (_isEditingTask) ...[
            _buildInlineTaskEditor(projectColor),
            const SizedBox(height: 16),
          ],

          // Grid thông tin
          Row(
            children: [
              Expanded(
                child: _buildInfoItem(
                  icon: Icons.calendar_today_rounded,
                  label: _t('Ngày giao', 'Assigned date', '分配日期'),
                  value:
                      '${createdAt.day.toString().padLeft(2, '0')}/${createdAt.month.toString().padLeft(2, '0')}/${createdAt.year}',
                  color: const Color(0xFF6366F1),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInfoItem(
                  icon: Icons.access_time_rounded,
                  label: _t('Hạn chót', 'Deadline', '截止日期'),
                  value:
                      '${dueDate.day.toString().padLeft(2, '0')}/${dueDate.month.toString().padLeft(2, '0')}/${dueDate.year}',
                  color: isOverdue
                      ? const Color(0xFFEF4444)
                      : const Color(0xFF10B981),
                  isOverdue: isOverdue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _buildInfoItem(
                  icon: Icons.person_rounded,
                  label: _t('Người thực hiện', 'Assignee', '负责人'),
                  value: task['assignee'],
                  color: const Color(0xFF8B5CF6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Dự án
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: projectColor.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: projectColor.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 30,
                  decoration: BoxDecoration(
                    color: projectColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _t('Thuộc dự án', 'Project', '所属项目'),
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.mutedTextColor,
                        ),
                      ),
                      Text(
                        _projectName(_project),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: projectColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: projectColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.folder_rounded,
                    size: 20,
                    color: projectColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Mô tả
          Text(
            _t('Mô tả', 'Description', '描述'),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: theme.textColor,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.backgroundColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _taskDescription(task),
              style: TextStyle(
                fontSize: 14,
                color: theme.mutedTextColor,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildTaskAttachmentSection(),
          const SizedBox(height: 16),
          Text(
            _t('Trạng thái', 'Status', '状态'),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: theme.textColor,
            ),
          ),
          const SizedBox(height: 8),
          _buildStatusSelector(),
        ],
      ),
    );
  }

  Widget _buildInlineTaskEditor(Color projectColor) {
    final theme = appThemeController;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.backgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: projectColor.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        children: [
          TextField(
            controller: _editingTaskTitleController,
            autofocus: true,
            style: TextStyle(color: theme.textColor, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              labelText: _t('Tên nhiệm vụ', 'Task name', '任务名称'),
              labelStyle: TextStyle(color: theme.mutedTextColor),
              filled: true,
              fillColor: theme.surfaceColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: theme.mutedTextColor.withValues(alpha: 0.18),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: theme.mutedTextColor.withValues(alpha: 0.18),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: projectColor, width: 1.4),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _editingTaskDescriptionController,
            minLines: 2,
            maxLines: 4,
            style: TextStyle(color: theme.textColor),
            decoration: InputDecoration(
              labelText: _t('Mô tả', 'Description', '描述'),
              labelStyle: TextStyle(color: theme.mutedTextColor),
              filled: true,
              fillColor: theme.surfaceColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: theme.mutedTextColor.withValues(alpha: 0.18),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: theme.mutedTextColor.withValues(alpha: 0.18),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: projectColor, width: 1.4),
              ),
            ),
          ),
          const SizedBox(height: 10),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _isSavingTask
                ? null
                : () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _editingTaskDueDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                      builder: (context, child) => Theme(
                        data: appThemeController.themeData,
                        child: child!,
                      ),
                    );
                    if (picked == null || !mounted) return;
                    setState(() {
                      _editingTaskDueDate = picked;
                    });
                  },
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: _t('Hạn chót', 'Deadline', '截止日期'),
                labelStyle: TextStyle(color: theme.mutedTextColor),
                filled: true,
                fillColor: theme.surfaceColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: theme.mutedTextColor.withValues(alpha: 0.18),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: theme.mutedTextColor.withValues(alpha: 0.18),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today_rounded, color: projectColor, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    _formatDate(_editingTaskDueDate),
                    style: TextStyle(
                      color: theme.textColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _editingTaskStatusCode,
            dropdownColor: theme.surfaceColor,
            decoration: InputDecoration(
              labelText: _t('Trạng thái', 'Status', '状态'),
              labelStyle: TextStyle(color: theme.mutedTextColor),
              filled: true,
              fillColor: theme.surfaceColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: theme.mutedTextColor.withValues(alpha: 0.18),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: theme.mutedTextColor.withValues(alpha: 0.18),
                ),
              ),
            ),
            items: const ['todo', 'in_progress', 'review', 'done']
                .map(
                  (statusCode) => DropdownMenuItem(
                    value: statusCode,
                    child: Text(
                      _labelFromStatusCode(statusCode),
                      style: TextStyle(color: theme.textColor),
                    ),
                  ),
                )
                .toList(),
            onChanged: _isSavingTask
                ? null
                : (value) {
                    if (value == null) return;
                    setState(() {
                      _editingTaskStatusCode = value;
                    });
                  },
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _isSavingTask ? null : _cancelEditTaskInline,
                child: Text(_t('Hủy', 'Cancel', '取消')),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _isSavingTask ? null : _submitEditTaskInline,
                style: ElevatedButton.styleFrom(
                  backgroundColor: projectColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
                child: _isSavingTask
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(_t('Lưu', 'Save', '保存')),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(Color projectColor) {
    final theme = appThemeController;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 72,
              color: const Color(0xFFEF4444).withValues(alpha: 0.85),
            ),
            const SizedBox(height: 14),
            Text(
              _detailError ?? _t('Không thể tải nhiệm vụ', 'Unable to load task', '无法加载任务'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: theme.textColor,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadTaskDetail,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(_t('Thử lại', 'Retry', '重试')),
              style: ElevatedButton.styleFrom(
                backgroundColor: projectColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusSelector() {
    return Column(
      children: [
        _buildStatusOption('Chưa nhận', Icons.inbox_rounded),
        const SizedBox(height: 8),
        _buildStatusOption('Đã nhận nhiệm vụ', Icons.assignment_ind_rounded),
        const SizedBox(height: 8),
        _buildStatusOption('Hoàn thành', Icons.check_circle_rounded),
      ],
    );
  }

  Widget _buildStatusOption(String status, IconData icon) {
    final theme = appThemeController;
    final isSelected = _taskStatus == status ||
        (status == 'Đã nhận nhiệm vụ' && _taskStatus == 'Đang làm') ||
        (status == 'Chưa nhận' && _taskStatus == 'Chưa bắt đầu');
    final color = status == 'Hoàn thành'
        ? const Color(0xFF10B981)
        : status == 'Đã nhận nhiệm vụ'
        ? const Color(0xFF6366F1)
        : const Color(0xFF6B7280);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final previousStatus = _taskStatus;
        final previousCompleted = _task['isCompleted'] == true;
        setState(() {
          _taskStatus = status;
          _task['status'] = status;
          _task['isCompleted'] = status == 'Hoàn thành';
        });

        try {
          final detail = await _projectService.updateTaskStatus(
            taskId: _task['id'].toString(),
            status: status,
          );
          final taskData = detail['task'];
          if (!mounted || taskData is! Map) return;
          setState(() {
            _task = _mapApiTask(Map<String, dynamic>.from(taskData));
            _taskStatus = _task['status']?.toString() ?? status;
          });
        } catch (err) {
          if (!mounted) return;
          setState(() {
            _taskStatus = previousStatus;
            _task['status'] = previousStatus;
            _task['isCompleted'] = previousCompleted;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(err.toString()),
              backgroundColor: const Color(0xFFEF4444),
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.1)
              : theme.backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? color.withValues(alpha: 0.35)
                : theme.mutedTextColor.withValues(alpha: 0.18),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _statusLabel(status),
                style: TextStyle(
                  color: isSelected ? color : theme.textColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (isSelected) Icon(Icons.check_rounded, color: color, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    bool isOverdue = false,
  }) {
    final theme = appThemeController;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(fontSize: 11, color: theme.mutedTextColor),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isOverdue ? const Color(0xFFEF4444) : theme.textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubtaskSection() {
    final theme = appThemeController;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '📋 ${_t('Nhiệm vụ con', 'Subtasks', '子任务')}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: theme.textColor,
                ),
              ),
              Text(
                '${_subtasks.where((st) => st['isCompleted']).length}/${_subtasks.length}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6366F1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._subtasks.map((subtask) {
            return _buildSubtaskItem(subtask);
          }),
          // Nút thêm subtask
          GestureDetector(
            onTap: () {
              _showAddSubtaskDialog();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: theme.backgroundColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_rounded,
                    size: 20,
                    color: theme.mutedTextColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _t('Thêm subtask', 'Add subtask', '添加子任务'),
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.mutedTextColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubtaskItem(Map<String, dynamic> subtask) {
    final theme = appThemeController;
    return CheckboxListTile(
      value: subtask['isCompleted'],
      onChanged: (value) {
        _handleToggleSubtask(subtask['id']);
      },
      title: Text(
        _subtaskTitle(subtask),
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: subtask['isCompleted']
              ? theme.mutedTextColor
              : theme.textColor,
          decoration: subtask['isCompleted']
              ? TextDecoration.lineThrough
              : null,
        ),
      ),
      controlAffinity: ListTileControlAffinity.leading,
      activeColor: const Color(0xFF6366F1),
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }

  Widget _buildTaskAttachmentSection() {
    final theme = appThemeController;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _t('Tài liệu đính kèm', 'Task attachments', '任务附件'),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: theme.textColor,
              ),
            ),
            Text(
              '${_attachments.length} file',
              style: TextStyle(fontSize: 13, color: theme.mutedTextColor),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ..._attachments.map((file) => _buildAttachmentItem(file)),
      ],
    );
  }

  Widget _buildMyAttachmentSection() {
    final theme = appThemeController;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _t('Tài liệu của bạn', 'Your documents', '你的资料'),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: theme.textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildUploadTypeButton(
                  icon: Icons.image_rounded,
                  label: _t('Ảnh', 'Image', '图片'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildUploadTypeButton(
                  icon: Icons.videocam_rounded,
                  label: 'Video',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildUploadTypeButton(
                  icon: Icons.insert_drive_file_rounded,
                  label: _t('Tài liệu', 'Document', '文档'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_attachments.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                _t(
                  'Chua co tai lieu nao',
                  'No documents yet',
                  'No documents yet',
                ),
                style: TextStyle(color: theme.mutedTextColor, fontSize: 13),
              ),
            )
          else
            ..._attachments.map((file) => _buildAttachmentItem(file)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: _handleCompleteTask,
              icon: const Icon(Icons.check_circle_rounded),
              label: Text(_t('Hoàn thành', 'Complete', '完成')),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadTypeButton({
    required IconData icon,
    required String label,
  }) {
    final theme = appThemeController;
    final fileType = icon == Icons.image_rounded
        ? 'image'
        : icon == Icons.videocam_rounded
        ? 'video'
        : 'document';
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: _isPickingAttachment
          ? null
          : () => _pickAndCreateAttachment(fileType: fileType),
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          color: theme.backgroundColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: theme.mutedTextColor.withValues(alpha: 0.18)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _isPickingAttachment
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(icon, color: const Color(0xFF6366F1)),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: theme.textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndCreateAttachment({required String fileType}) async {
    if (_isPickingAttachment) return;

    setState(() {
      _isPickingAttachment = true;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: _pickerType(fileType),
        allowMultiple: false,
        withData: true,
      );
      if (result == null || result.files.isEmpty) {
        if (mounted) {
          setState(() {
            _isPickingAttachment = false;
          });
        }
        return;
      }

      final file = result.files.single;
      final fileBase64 = await _readPickedFileBase64(file);
      final attachment = await _createTaskAttachmentApi(
        taskId: _task['id'].toString(),
        fileName: file.name,
        fileUrl: '',
        fileType: fileType,
        fileSize: file.size,
        fileBase64: fileBase64,
      );

      if (!mounted) return;
      setState(() {
        _attachments.insert(0, _mapApiAttachment(attachment));
        _isPickingAttachment = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t('Da them tai lieu', 'Document added', 'Document added'),
          ),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _isPickingAttachment = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err.toString()),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  FileType _pickerType(String fileType) {
    switch (fileType) {
      case 'image':
        return FileType.image;
      case 'video':
        return FileType.video;
      default:
        return FileType.any;
    }
  }

  Future<String> _readPickedFileBase64(PlatformFile file) async {
    final bytes = file.bytes;
    if (bytes != null && bytes.isNotEmpty) {
      return base64Encode(bytes);
    }

    final path = file.path;
    if (path == null || path.isEmpty) {
      throw ApiException(
        _t(
          'Không thể đọc file đã chọn.',
          'Unable to read the selected file.',
          '无法读取所选文件。',
        ),
      );
    }

    return base64Encode(await File(path).readAsBytes());
  }

  Future<void> _handleCompleteTask() async {
    final previousStatus = _taskStatus;
    final previousCompleted = _task['isCompleted'] == true;
    setState(() {
      _taskStatus = 'Hoàn thành';
      _task['status'] = 'Hoàn thành';
      _task['isCompleted'] = true;
    });

    try {
      await _projectService.updateTaskStatus(
        taskId: _task['id'].toString(),
        status: 'Hoàn thành',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              'Nhiệm vụ đã được đánh dấu hoàn thành',
              'Task marked as completed',
              '任务已标记为完成',
            ),
          ),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _taskStatus = previousStatus;
        _task['status'] = previousStatus;
        _task['isCompleted'] = previousCompleted;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err.toString()),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  Widget _buildAttachmentItem(Map<String, dynamic> file) {
    final theme = appThemeController;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: file['color'].withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: file['color'].withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: file['color'].withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(file['icon'], size: 20, color: file['color']),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file['name'],
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: theme.textColor,
                  ),
                ),
                Text(
                  file['size'],
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.mutedTextColor,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert_rounded,
              color: theme.mutedTextColor,
              size: 20,
            ),
            color: theme.surfaceColor,
            onSelected: (value) {
              if (value == 'download') {
                _showAttachmentLocation(file);
              } else if (value == 'delete') {
                _deleteAttachment(file['id'].toString());
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'download',
                child: Row(
                  children: [
                    Icon(
                      Icons.download_rounded,
                      size: 18,
                      color: theme.textColor,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _t('Tai xuong', 'Download', 'Download'),
                      style: TextStyle(color: theme.textColor),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    const Icon(
                      Icons.delete_rounded,
                      size: 18,
                      color: Color(0xFFEF4444),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _t('Xoa', 'Delete', 'Delete'),
                      style: const TextStyle(color: Color(0xFFEF4444)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>> _createTaskAttachmentApi({
    required String taskId,
    required String fileName,
    required String fileUrl,
    required String fileType,
    required int fileSize,
    required String fileBase64,
  }) async {
    final data = await _commentRequest(
      method: 'POST',
      path: '/task-detail/$taskId/attachments',
      body: {
        'file_name': fileName,
        if (fileUrl.isNotEmpty) 'file_url': fileUrl,
        'file_base64': fileBase64,
        'file_type': fileType,
        'file_size': fileSize,
      },
    );
    final responseData = data['data'];
    if (responseData is Map) {
      return Map<String, dynamic>.from(responseData);
    }
    return data;
  }

  Future<void> _deleteTaskAttachmentApi({
    required String taskId,
    required String attachmentId,
  }) async {
    await _commentRequest(
      method: 'DELETE',
      path: '/task-detail/$taskId/attachments/$attachmentId',
    );
  }

  Future<void> _deleteAttachment(String attachmentId) async {
    final index = _attachments.indexWhere(
      (attachment) => attachment['id']?.toString() == attachmentId,
    );
    if (index == -1) return;
    final removedAttachment = Map<String, dynamic>.from(_attachments[index]);

    setState(() {
      _attachments.removeAt(index);
    });

    try {
      await _deleteTaskAttachmentApi(
        taskId: _task['id'].toString(),
        attachmentId: attachmentId,
      );
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _attachments.insert(index, removedAttachment);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err.toString()),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  void _showAttachmentLocation(Map<String, dynamic> file) {
    final location = file['url']?.toString() ?? '';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          location.isEmpty
              ? _t('Khong co duong dan file', 'No file path', 'No file path')
              : location,
        ),
        backgroundColor: const Color(0xFF6366F1),
      ),
    );
  }

  Widget _buildCommentSection() {
    final theme = appThemeController;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '💬 ${_t('Bình luận', 'Comments', '评论')}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: theme.textColor,
                ),
              ),
              Text(
                _t(
                  '${_comments.length} bình luận',
                  '${_comments.length} comments',
                  '${_comments.length} 条评论',
                ),
                style: TextStyle(fontSize: 14, color: theme.mutedTextColor),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Input comment
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFF6366F1),
                child: const Text(
                  'A',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.backgroundColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: theme.mutedTextColor.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _commentController,
                          decoration: InputDecoration(
                            hintText: _t(
                              'Viết bình luận...',
                              'Write a comment...',
                              '写评论...',
                            ),
                            hintStyle: TextStyle(color: theme.mutedTextColor),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                          ),
                          style: TextStyle(
                            fontSize: 14,
                            color: theme.textColor,
                          ),
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _handleAddComment(),
                        ),
                      ),
                      IconButton(
                        onPressed: _isSubmittingComment
                            ? null
                            : _handleAddComment,
                        icon: _isSubmittingComment
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.send_rounded,
                                color: Color(0xFF6366F1),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_comments.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                _t(
                  'Chưa có bình luận nào',
                  'No comments yet',
                  '暂无评论',
                ),
                style: TextStyle(color: theme.mutedTextColor, fontSize: 13),
              ),
            )
          else
            ..._comments.map((comment) {
              return _buildCommentItem(comment);
            }),
        ],
      ),
    );
  }

  Widget _buildCommentItem(Map<String, dynamic> comment) {
    final theme = appThemeController;
    final commentId = comment['id']?.toString() ?? '';
    final isEditing = _editingCommentId == commentId;
    final time = comment['time'] as DateTime;
    final diff = DateTime.now().difference(time);
    String timeText;
    if (diff.inMinutes < 1) {
      timeText = _t('Vừa xong', 'Just now', '刚刚');
    } else if (diff.inHours < 1) {
      timeText = _t(
        '${diff.inMinutes} phút trước',
        '${diff.inMinutes} min ago',
        '${diff.inMinutes} 分钟前',
      );
    } else if (diff.inDays < 1) {
      timeText = _t(
        '${diff.inHours} giờ trước',
        '${diff.inHours} h ago',
        '${diff.inHours} 小时前',
      );
    } else {
      timeText = _t(
        '${diff.inDays} ngày trước',
        '${diff.inDays} days ago',
        '${diff.inDays} 天前',
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: comment['isMine']
            ? const Color(0xFF6366F1).withValues(alpha: 0.05)
            : theme.backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: comment['isMine']
              ? const Color(0xFF6366F1).withValues(alpha: 0.1)
              : theme.mutedTextColor.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: comment['isMine']
                    ? const Color(0xFF6366F1)
                    : const Color(0xFF8B5CF6),
                child: Text(
                  comment['user'][0],
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      comment['user'],
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: theme.textColor,
                      ),
                    ),
                    Text(
                      timeText,
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.mutedTextColor,
                      ),
                    ),
                  ],
                ),
              ),
              if (comment['isMine'])
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert_rounded,
                    size: 20,
                    color: theme.mutedTextColor,
                  ),
                  color: theme.surfaceColor,
                  onSelected: (value) {
                    if (value == 'edit') {
                      _startEditComment(comment);
                    } else if (value == 'delete') {
                      _deleteComment(commentId);
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(
                            Icons.edit_rounded,
                            size: 18,
                            color: theme.textColor,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _t('Sửa', 'Edit', '编辑'),
                            style: TextStyle(color: theme.textColor),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          const Icon(
                            Icons.delete_rounded,
                            size: 18,
                            color: Color(0xFFEF4444),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _t('Xóa', 'Delete', '删除'),
                            style: const TextStyle(color: Color(0xFFEF4444)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (isEditing)
            _buildInlineCommentEditor(commentId)
          else
            Text(
              _commentContent(comment),
              style: TextStyle(
                fontSize: 14,
                color: theme.mutedTextColor,
                height: 1.4,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInlineCommentEditor(String commentId) {
    final theme = appThemeController;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        TextField(
          controller: _editingCommentController,
          autofocus: true,
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: _t(
              'Nhập nội dung bình luận',
              'Enter comment content',
              '输入评论内容',
            ),
            hintStyle: TextStyle(color: theme.mutedTextColor),
            filled: true,
            fillColor: theme.backgroundColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: theme.mutedTextColor.withValues(alpha: 0.18),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: theme.mutedTextColor.withValues(alpha: 0.18),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFF6366F1),
                width: 1.4,
              ),
            ),
            contentPadding: const EdgeInsets.all(12),
          ),
          style: TextStyle(color: theme.textColor, fontSize: 14),
          textInputAction: TextInputAction.newline,
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: _cancelEditComment,
              child: Text(_t('Hủy', 'Cancel', '取消')),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () => _submitEditComment(commentId),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
              ),
              child: Text(_t('Lưu', 'Save', '保存')),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _createSubtask(String title) async {
    try {
      final subtask = await _projectService.createTaskSubtask(
        taskId: _task['id'].toString(),
        title: title,
      );
      if (!mounted) return;
      setState(() {
        _subtasks.add(_mapApiSubtask(subtask));
      });
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err.toString()),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  Future<void> _deleteComment(String commentId) async {
    final index = _comments.indexWhere((comment) => comment['id'] == commentId);
    if (index == -1) return;
    final removedComment = Map<String, dynamic>.from(_comments[index]);

    setState(() {
      _comments.removeAt(index);
    });

    try {
      await _deleteTaskCommentApi(
        taskId: _task['id'].toString(),
        commentId: commentId,
      );
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _comments.insert(index, removedComment);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err.toString()),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  Future<void> _updateComment({
    required String commentId,
    required String content,
  }) async {
    final index = _comments.indexWhere((comment) => comment['id'] == commentId);
    if (index == -1) return;
    final oldComment = Map<String, dynamic>.from(_comments[index]);

    setState(() {
      _comments[index] = {
        ..._comments[index],
        'content': content,
      };
    });

    try {
      final updatedComment = await _updateTaskCommentApi(
        taskId: _task['id'].toString(),
        commentId: commentId,
        content: content,
      );
      if (!mounted) return;
      setState(() {
        _comments[index] = _mapApiComment(updatedComment);
        _editingCommentId = null;
        _editingCommentController.clear();
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _comments[index] = oldComment;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err.toString()),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  void _startEditComment(Map<String, dynamic> comment) {
    setState(() {
      _editingCommentId = comment['id']?.toString();
      _editingCommentController.text = comment['content']?.toString() ?? '';
    });
  }

  void _cancelEditComment() {
    setState(() {
      _editingCommentId = null;
      _editingCommentController.clear();
    });
  }

  Future<void> _submitEditComment(String commentId) async {
    final content = _editingCommentController.text.trim();
    if (content.isEmpty) return;
    await _updateComment(commentId: commentId, content: content);
  }

  Future<Map<String, dynamic>> _updateTaskCommentApi({
    required String taskId,
    required String commentId,
    required String content,
  }) async {
    final data = await _commentRequest(
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

  Future<void> _deleteTaskCommentApi({
    required String taskId,
    required String commentId,
  }) async {
    await _commentRequest(
      method: 'DELETE',
      path: '/task-detail/$taskId/comments/$commentId',
    );
  }

  Future<Map<String, dynamic>> _commentRequest({
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
        'POST' => await http
            .post(uri, headers: requestHeaders, body: jsonEncode(body ?? {}))
            .timeout(const Duration(seconds: 45)),
        'PATCH' => await http
            .patch(uri, headers: requestHeaders, body: jsonEncode(body ?? {}))
            .timeout(const Duration(seconds: 15)),
        'DELETE' => await http
            .delete(uri, headers: requestHeaders, body: jsonEncode(body ?? {}))
            .timeout(const Duration(seconds: 15)),
        _ => await http
            .get(uri, headers: requestHeaders)
            .timeout(const Duration(seconds: 15)),
      };

      final decoded = jsonDecode(response.body);
      final data = decoded is Map<String, dynamic>
          ? decoded
          : {'message': 'Phản hồi API không hợp lệ.'};
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

  void _showAddSubtaskDialog() {
    final TextEditingController controller = TextEditingController();
    final theme = appThemeController;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        decoration: BoxDecoration(
          color: theme.surfaceColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _t('Thêm subtask mới', 'Add new subtask', '添加新子任务'),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: theme.textColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _t('Nhập tên subtask', 'Enter subtask name', '输入子任务名称'),
                style: TextStyle(fontSize: 14, color: theme.mutedTextColor),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: _t(
                    'Nhập tên subtask...',
                    'Enter subtask name...',
                    '输入子任务名称...',
                  ),
                  hintStyle: TextStyle(color: theme.mutedTextColor),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  filled: true,
                  fillColor: theme.backgroundColor,
                ),
                style: TextStyle(color: theme.textColor),
                onSubmitted: (_) async {
                  if (controller.text.trim().isNotEmpty) {
                    final title = controller.text.trim();
                    Navigator.pop(context);
                    await _createSubtask(title);
                  }
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    if (controller.text.trim().isNotEmpty) {
                      final title = controller.text.trim();
                      Navigator.pop(context);
                      await _createSubtask(title);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    _t('Thêm subtask', 'Add subtask', '添加子任务'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
