import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme_controller.dart';
import 'services/project_service.dart';
import 'utils/color_utils.dart';
import 'task_detail_screen.dart'; // Import trang chi tiết task

enum ProjectDetailLanguage { vietnamese, english, chinese }

class ProjectDetailScreen extends StatefulWidget {
  final Map<String, dynamic> project;

  const ProjectDetailScreen({super.key, required this.project});

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  final ProjectService _projectService = ProjectService();

  // Biến sắp xếp
  bool _isAscending = true;
  ProjectDetailLanguage _language = ProjectDetailLanguage.vietnamese;
  bool _isLoadingDetail = true;
  String? _detailError;
  String? _currentUserId;
  Map<String, dynamic> _projectDetail = {};

  // Filter: 'all_tasks', 'in_progress', 'my_tasks', 'completed'
  String _currentFilter = 'all_tasks';

  List<Map<String, dynamic>> _allTasks = [];

  List<Map<String, dynamic>> _members = [];

  @override
  void initState() {
    super.initState();
    _loadLanguage();
    _loadProjectDetail();
  }

  String _t(String vi, String en, String zh) {
    switch (_language) {
      case ProjectDetailLanguage.vietnamese:
        return vi;
      case ProjectDetailLanguage.english:
        return en;
      case ProjectDetailLanguage.chinese:
        return zh;
    }
  }

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final rawValue = prefs.getString('app_language');
    if (!mounted) return;
    setState(() {
      _language = ProjectDetailLanguage.values.firstWhere(
        (language) => language.name == rawValue,
        orElse: () => ProjectDetailLanguage.vietnamese,
      );
    });
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
      case '6':
        return _t(
          'Viết unit test cho các module chính',
          'Write unit tests for core modules',
          '为核心模块编写单元测试',
        );
      case '7':
        return _t(
          'Triển khai ứng dụng lên môi trường production',
          'Deploy the app to production',
          '将应用部署到生产环境',
        );
      case '8':
        return _t(
          'Review code của các thành viên trong team',
          'Review code from team members',
          '审查团队成员的代码',
        );
      default:
        return task['description']?.toString() ?? '';
    }
  }

  String _statusText(String status, bool isCompleted, [String? statusCode]) {
    if (isCompleted) return _t('Hoàn thành', 'Completed', '已完成');
    switch (statusCode) {
      case 'in_progress':
        return _t('Đã nhận nhiệm vụ', 'Accepted task', '已接受任务');
      case 'review':
        return _t('Chờ duyệt', 'Pending review', '待审核');
      case 'todo':
        return _t('Chưa nhận', 'Not accepted', '未接受');
      case 'done':
        return _t('Hoàn thành', 'Completed', '已完成');
    }

    switch (status) {
      case 'Đang làm':
        return _t('Đã nhận nhiệm vụ', 'Accepted task', '已接受任务');
      case 'Chưa bắt đầu':
        return _t('Chưa nhận', 'Not accepted', '未接受');
      case 'Trễ hạn':
        return _t('Trễ hạn', 'Overdue', '已逾期');
      case 'Chờ duyệt':
        return _t('Chờ duyệt', 'Pending review', '待审核');
      default:
        return status;
    }
  }

  bool get _canManageTasks {
    final roleId = NumberParser.toInt(
      (_projectDetail.isNotEmpty ? _projectDetail : widget.project)['project_role_id'],
    );
    return roleId == 1 || roleId == 2;
  }

  Future<void> _loadProjectDetail() async {
    setState(() {
      _isLoadingDetail = true;
      _detailError = null;
    });

    try {
      final projectId = widget.project['id']?.toString() ?? '';
      final detail = await _projectService.getProjectDetail(projectId);
      final projectData = detail['project'];
      final membersData = detail['members'];
      final tasksData = detail['tasks'];

      if (!mounted) return;
      setState(() {
        _projectDetail = projectData is Map
            ? Map<String, dynamic>.from(projectData)
            : Map<String, dynamic>.from(widget.project);
        _currentUserId = detail['current_user_id']?.toString();
        _members = membersData is List
            ? membersData
                .whereType<Map>()
                .map((member) => Map<String, dynamic>.from(member))
                .toList()
            : [];
        _allTasks = tasksData is List
            ? tasksData
                .whereType<Map>()
                .map((task) => _mapApiTask(Map<String, dynamic>.from(task)))
                .toList()
            : [];
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
    final statusCode = task['status_code']?.toString() ?? '';
    final status = _statusText(
      task['status']?.toString() ?? '',
      false,
      statusCode,
    );
    final isCompleted =
        task['isCompleted'] == true ||
        statusCode == 'done';

    return {
      'id': task['id']?.toString() ?? '',
      'title': task['title']?.toString() ?? '',
      'description': task['description']?.toString() ?? '',
      'dueDate': dueDate,
      'assignee': task['assignee']?.toString() ?? 'Cả team',
      'assigneeId': task['assigneeId']?.toString() ??
          task['assignee_id']?.toString() ??
          '',
      'status': status,
      'statusCode': statusCode,
      'isCompleted': isCompleted,
      'subtasks': task['subtasks'] is List ? task['subtasks'] : const [],
      'attachments': task['attachments'] is List ? task['attachments'] : const [],
      'comments': task['comments'] is List ? task['comments'] : const [],
      'createdAt': _parseApiDate(task['createdAt'] ?? task['created_at']),
    };
  }

  DateTime _parseApiDate(dynamic value) {
    if (value is DateTime) return value;
    final text = value?.toString();
    if (text == null || text.isEmpty) return DateTime.now();
    return DateTime.tryParse(text) ?? DateTime.now();
  }

  // ignore: unused_element
  void _initTaskData() {
    final now = DateTime.now();
    _allTasks = [
      // Task của tôi (chưa hoàn thành)
      {
        'id': '1',
        'title': 'Thiết kế UI cho màn hình chính',
        'description':
            'Thiết kế giao diện người dùng cho màn hình chính của ứng dụng',
        'dueDate': now.add(const Duration(days: 2)),
        'assignee': 'Nguyễn Văn A',
        'assigneeId': '1',
        'priority': 'Cao',
        'status': 'Đang làm',
        'isCompleted': false,
        'createdAt': now.subtract(const Duration(days: 3)),
      },
      {
        'id': '2',
        'title': 'Xây dựng API đăng nhập',
        'description': 'Tạo API cho chức năng đăng nhập và đăng ký',
        'dueDate': now.add(const Duration(days: 5)),
        'assignee': 'Nguyễn Văn A',
        'assigneeId': '1',
        'priority': 'Trung bình',
        'status': 'Chưa bắt đầu',
        'isCompleted': false,
        'createdAt': now.subtract(const Duration(days: 1)),
      },
      {
        'id': '3',
        'title': 'Tối ưu hiệu suất ứng dụng',
        'description': 'Tối ưu hóa hiệu suất và giảm thời gian tải',
        'dueDate': now.subtract(const Duration(days: 1)),
        'assignee': 'Nguyễn Văn A',
        'assigneeId': '1',
        'priority': 'Cao',
        'status': 'Trễ hạn',
        'isCompleted': false,
        'createdAt': now.subtract(const Duration(days: 7)),
      },
      // Task của tôi (đã hoàn thành)
      {
        'id': '4',
        'title': 'Phân tích yêu cầu dự án',
        'description': 'Phân tích và document yêu cầu từ khách hàng',
        'dueDate': now.subtract(const Duration(days: 5)),
        'assignee': 'Nguyễn Văn A',
        'assigneeId': '1',
        'priority': 'Thấp',
        'status': 'Hoàn thành',
        'isCompleted': true,
        'createdAt': now.subtract(const Duration(days: 10)),
      },
      // Task của đồng đội (chưa hoàn thành)
      {
        'id': '5',
        'title': 'Thiết kế database',
        'description': 'Thiết kế cơ sở dữ liệu cho hệ thống',
        'dueDate': now.add(const Duration(days: 3)),
        'assignee': 'Trần Thị B',
        'assigneeId': '2',
        'priority': 'Cao',
        'status': 'Đang làm',
        'isCompleted': false,
        'createdAt': now.subtract(const Duration(days: 2)),
      },
      {
        'id': '6',
        'title': 'Viết unit test',
        'description': 'Viết unit test cho các module chính',
        'dueDate': now.add(const Duration(days: 7)),
        'assignee': 'Lê Văn C',
        'assigneeId': '3',
        'priority': 'Trung bình',
        'status': 'Chưa bắt đầu',
        'isCompleted': false,
        'createdAt': now.subtract(const Duration(days: 1)),
      },
      {
        'id': '7',
        'title': 'Deploy lên production',
        'description': 'Triển khai ứng dụng lên môi trường production',
        'dueDate': now.add(const Duration(days: 10)),
        'assignee': 'Phạm Thị D',
        'assigneeId': '4',
        'priority': 'Cao',
        'status': 'Chờ duyệt',
        'isCompleted': false,
        'createdAt': now.subtract(const Duration(days: 3)),
      },
      // Task của đồng đội (đã hoàn thành)
      {
        'id': '8',
        'title': 'Code review',
        'description': 'Review code của các thành viên trong team',
        'dueDate': now.subtract(const Duration(days: 2)),
        'assignee': 'Trần Thị B',
        'assigneeId': '2',
        'priority': 'Trung bình',
        'status': 'Hoàn thành',
        'isCompleted': true,
        'createdAt': now.subtract(const Duration(days: 8)),
      },
    ];
  }

  List<Map<String, dynamic>> _getFilteredTasks() {
    List<Map<String, dynamic>> filtered = [];

    switch (_currentFilter) {
      case 'my_tasks':
        // Tất cả task của tôi
        filtered = _allTasks
            .where((task) => task['assigneeId'] == _currentUserId)
            .toList();
        break;

      case 'in_progress':
        // Tất cả task đang được thực hiện
        filtered = _allTasks
            .where(
              (task) =>
                  task['statusCode'] == 'in_progress' && !task['isCompleted'],
            )
            .toList();
        break;

      case 'all_tasks':
        // Tất cả task của các thành viên ở mọi trạng thái
        filtered = List<Map<String, dynamic>>.from(_allTasks);
        break;

      case 'completed':
        // Tất cả task đã hoàn thành của mọi thành viên
        filtered = _allTasks
            .where((task) => task['isCompleted'])
            .toList();
        break;

      default:
        filtered = [];
    }

    // Luôn đưa nhiệm vụ đã hoàn thành xuống cuối danh sách.
    filtered.sort((a, b) {
      final aCompleted = a['isCompleted'] == true;
      final bCompleted = b['isCompleted'] == true;
      if (_currentFilter != 'completed' && aCompleted != bCompleted) {
        return aCompleted ? 1 : -1;
      }

      final nameA = a['title'].toLowerCase();
      final nameB = b['title'].toLowerCase();
      return _isAscending ? nameA.compareTo(nameB) : nameB.compareTo(nameA);
    });

    return filtered;
  }

  int _getTaskCount(String filter) {
    switch (filter) {
      case 'my_tasks':
        return _allTasks.where((t) => t['assigneeId'] == _currentUserId).length;
      case 'in_progress':
        return _allTasks
            .where((t) => t['statusCode'] == 'in_progress' && !t['isCompleted'])
            .length;
      case 'all_tasks':
        return _allTasks.length;
      case 'completed':
        return _allTasks.where((t) => t['isCompleted']).length;
      default:
        return 0;
    }
  }

  void _openCreateTask() {
    Navigator.pushNamed(
      context,
      '/create-task',
      arguments: {
        'project': _projectDetail.isNotEmpty ? _projectDetail : widget.project,
        'members': _members,
      },
    ).then((created) {
      if (created == true) {
        _loadProjectDetail();
      }
    });
  }

  Future<void> _openTaskDetail(
    Map<String, dynamic> task, {
    bool startEditing = false,
  }) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TaskDetailScreen(
          task: task,
          project: _projectDetail.isNotEmpty ? _projectDetail : widget.project,
          startEditing: startEditing,
        ),
      ),
    );
    if (mounted) {
      _loadProjectDetail();
    }
  }

  Future<void> _confirmDeleteTask(Map<String, dynamic> task) async {
    final theme = appThemeController;
    final taskId = task['id']?.toString() ?? '';
    if (taskId.isEmpty) return;

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: theme.surfaceColor,
        title: Text(
          _t('Xóa nhiệm vụ', 'Delete task', '删除任务'),
          style: TextStyle(color: theme.textColor, fontWeight: FontWeight.w700),
        ),
        content: Text(
          _t(
            'Bạn có chắc muốn xóa nhiệm vụ này không?',
            'Are you sure you want to delete this task?',
            '确定要删除此任务吗？',
          ),
          style: TextStyle(color: theme.mutedTextColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(_t('Hủy', 'Cancel', '取消')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              _t('Xóa', 'Delete', '删除'),
              style: const TextStyle(color: Color(0xFFEF4444)),
            ),
          ),
        ],
      ),
    );

    if (shouldDelete != true || !mounted) return;

    try {
      await _projectService.deleteTask(taskId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              'Đã xóa nhiệm vụ',
              'Task deleted',
              '任务已删除',
            ),
          ),
        ),
      );
      _loadProjectDetail();
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err.toString())),
      );
    }
  }

  void _handleTaskMenu(String action, Map<String, dynamic> task) {
    if (action == 'edit') {
      _openTaskDetail(task, startEditing: true);
      return;
    }
    if (action == 'delete') {
      _confirmDeleteTask(task);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = appThemeController;
    final project = _projectDetail.isNotEmpty ? _projectDetail : widget.project;
    final color = parseHexColor(project['color']);
    final filteredTasks = _getFilteredTasks();
    final incompleteTasks = _allTasks.where((t) => !t['isCompleted']).length;

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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back button và tên dự án
                  Row(
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
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 32,
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _projectName(project),
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: theme.textColor,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Thông tin nhanh
                  Row(
                    children: [
                      _buildQuickInfo(
                        icon: Icons.task_rounded,
                        label: _t(
                          'Nhiệm vụ chưa hoàn thành',
                          'Incomplete tasks',
                          '未完成任务',
                        ),
                        value: incompleteTasks.toString(),
                        color: color,
                      ),
                      const SizedBox(width: 12),
                      _buildQuickInfo(
                        icon: Icons.people_rounded,
                        label: _t('Thành viên', 'Members', '成员'),
                        value: _members.length.toString(),
                        color: color,
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            '/project-members',
                            arguments: {
                              'project': {
                                ...(_projectDetail.isNotEmpty
                                    ? _projectDetail
                                    : widget.project),
                                'current_user_id': _currentUserId,
                              },
                              'members': _members,
                            },
                          ).then((invited) {
                            if (invited == true) {
                              _loadProjectDetail();
                            }
                          });
                        },
                      ),
                      const SizedBox(width: 12),
                      _buildQuickInfo(
                        icon: Icons.add_task_rounded,
                        label: _t('Thêm nhiệm vụ', 'Add task', '添加任务'),
                        value: '+',
                        color: color,
                        onTap: _openCreateTask,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Filter và Sort
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  // Filter buttons
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip(
                            label: _t('Tất cả', 'All', '全部'),
                            value: 'all_tasks',
                            count: _getTaskCount('all_tasks'),
                            icon: Icons.list_rounded,
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            label: _t(
                              'Đang tiến hành',
                              'In progress',
                              '进行中',
                            ),
                            value: 'in_progress',
                            count: _getTaskCount('in_progress'),
                            icon: Icons.play_circle_rounded,
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            label: _t('Nhiệm vụ của tôi', 'My tasks', '我的任务'),
                            value: 'my_tasks',
                            count: _getTaskCount('my_tasks'),
                            icon: Icons.person_rounded,
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            label: _t('Hoàn thành', 'Completed', '已完成'),
                            value: 'completed',
                            count: _getTaskCount('completed'),
                            icon: Icons.check_circle_rounded,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Sort button
                  Container(
                    decoration: BoxDecoration(
                      color: theme.surfaceColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      onPressed: () {
                        setState(() {
                          _isAscending = !_isAscending;
                        });
                      },
                      icon: Icon(
                        _isAscending
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
                        color: const Color(0xFF6366F1),
                        size: 22,
                      ),
                      tooltip: _isAscending ? 'A → Z' : 'Z → A',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Danh sách task
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadProjectDetail,
                color: color,
                child: _isLoadingDetail
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(
                            height: MediaQuery.of(context).size.height * 0.4,
                            child: Center(
                              child: CircularProgressIndicator(color: color),
                            ),
                          ),
                        ],
                      )
                    : _detailError != null
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(
                            height: MediaQuery.of(context).size.height * 0.45,
                            child: _buildErrorState(color),
                          ),
                        ],
                      )
                    : filteredTasks.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(
                            height: MediaQuery.of(context).size.height * 0.45,
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.check_circle_outline_rounded,
                                    size: 80,
                                    color: theme.mutedTextColor.withValues(
                                      alpha: 0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _t(
                                      'Không có task nào',
                                      'No tasks found',
                                      '没有任务',
                                    ),
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: theme.mutedTextColor,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _currentFilter == 'my_tasks'
                                        ? _t(
                                            'Bạn chưa có task nào trong dự án này',
                                            'You do not have any tasks in this project',
                                            '你在此项目中还没有任务',
                                          )
                                        : _t(
                                            'Không có task nào phù hợp',
                                            'No matching tasks',
                                            '没有匹配的任务',
                                          ),
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: theme.mutedTextColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        itemCount: filteredTasks.length,
                        itemBuilder: (context, index) {
                          final task = filteredTasks[index];
                          return _buildTaskCard(task);
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickInfo({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    VoidCallback? onTap,
  }) {
    final theme = appThemeController;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.1)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 16, color: color),
                  const SizedBox(width: 4),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(fontSize: 10, color: theme.mutedTextColor),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(Color color) {
    final theme = appThemeController;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 70,
              color: const Color(0xFFEF4444).withValues(alpha: 0.8),
            ),
            const SizedBox(height: 16),
            Text(
              _detailError ?? _t('Không thể tải dự án', 'Unable to load project', '无法加载项目'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: theme.textColor,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadProjectDetail,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(_t('Thử lại', 'Retry', '重试')),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ignore: unused_element
  void _showAddTaskSheet(Color color) {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _ProjectActionSheet(
        title: _t('Thêm nhiệm vụ', 'Add task', '添加任务'),
        buttonText: _t('Tạo nhiệm vụ', 'Create task', '创建任务'),
        color: color,
        children: [
          _ActionTextField(
            controller: titleController,
            label: _t('Tên nhiệm vụ', 'Task name', '任务名称'),
            hintText: _t('Nhập tên nhiệm vụ', 'Enter task name', '请输入任务名称'),
          ),
          const SizedBox(height: 12),
          _ActionTextField(
            controller: descriptionController,
            label: _t('Mô tả', 'Description', '描述'),
            hintText: _t(
              'Nhập mô tả nhiệm vụ',
              'Enter task description',
              '请输入任务描述',
            ),
            maxLines: 3,
          ),
        ],
        onSubmit: () {
          Navigator.pop(sheetContext);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _t(
                  'Đã tạo nhiệm vụ mới',
                  'New task created',
                  '已创建新任务',
                ),
              ),
            ),
          );
        },
      ),
    ).whenComplete(() {
      titleController.dispose();
      descriptionController.dispose();
    });
  }

  Widget _buildFilterChip({
    required String label,
    required String value,
    required int count,
    required IconData icon,
  }) {
    final theme = appThemeController;
    final isSelected = _currentFilter == value;

    return FilterChip(
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _currentFilter = value;
        });
      },
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: isSelected ? Colors.white : theme.mutedTextColor,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isSelected ? Colors.white : theme.textColor,
            ),
          ),
          if (count > 0) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.2)
                    : const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : const Color(0xFF6B7280),
                ),
              ),
            ),
          ],
        ],
      ),
      backgroundColor: theme.surfaceColor,
      selectedColor: const Color(0xFF6366F1),
      checkmarkColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> task) {
    final theme = appThemeController;
    final dueDate = task['dueDate'] as DateTime;
    final isOverdue = dueDate.isBefore(DateTime.now()) && !task['isCompleted'];
    final isCompleted = task['isCompleted'];
    final isMyTask = task['assigneeId'] == _currentUserId;

    return GestureDetector(
      onTap: () => _openTaskDetail(task),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.surfaceColor,
          borderRadius: BorderRadius.circular(14),
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
              children: [
                // Status indicator
                Container(
                  width: 4,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? const Color(0xFF10B981)
                        : isOverdue
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF6366F1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                // Task info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _taskTitle(task),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isCompleted
                              ? theme.mutedTextColor
                              : theme.textColor,
                          decoration: isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _taskDescription(task),
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.mutedTextColor,
                          decoration: isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (_canManageTasks)
                  PopupMenuButton<String>(
                    color: theme.surfaceColor,
                    icon: Icon(
                      Icons.more_vert_rounded,
                      color: theme.mutedTextColor,
                      size: 22,
                    ),
                    onSelected: (value) => _handleTaskMenu(value, task),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            const Icon(
                              Icons.edit_rounded,
                              size: 18,
                              color: Color(0xFF6366F1),
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
                              Icons.delete_outline_rounded,
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
            const SizedBox(height: 10),
            // Bottom row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    // Assignee
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isMyTask
                            ? const Color(0xFF6366F1).withValues(alpha: 0.1)
                            : const Color(0xFF10B981).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isMyTask
                                ? Icons.person_rounded
                                : Icons.people_rounded,
                            size: 12,
                            color: isMyTask
                                ? const Color(0xFF6366F1)
                                : const Color(0xFF10B981),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isMyTask
                                ? _t('Tôi', 'Me', '我')
                                : task['assignee'],
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: isMyTask
                                  ? const Color(0xFF6366F1)
                                  : const Color(0xFF10B981),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Due date
                    Row(
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 14,
                          color: isOverdue
                              ? const Color(0xFFEF4444)
                              : const Color(0xFF6B7280),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${dueDate.day.toString().padLeft(2, '0')}/${dueDate.month.toString().padLeft(2, '0')}/${dueDate.year}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isOverdue
                                ? const Color(0xFFEF4444)
                                : const Color(0xFF6B7280),
                            fontWeight: isOverdue
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? const Color(0xFF10B981).withValues(alpha: 0.1)
                        : isOverdue
                        ? const Color(0xFFEF4444).withValues(alpha: 0.1)
                        : const Color(0xFF6366F1).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isCompleted
                          ? const Color(0xFF10B981).withValues(alpha: 0.2)
                          : isOverdue
                          ? const Color(0xFFEF4444).withValues(alpha: 0.2)
                          : const Color(0xFF6366F1).withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    isCompleted
                        ? '✅ ${_t('Hoàn thành', 'Completed', '已完成')}'
                        : isOverdue
                        ? '⏰ ${_t('Trễ hạn', 'Overdue', '已逾期')}'
                        : '🔄 ${_statusText(task['status'], isCompleted, task['statusCode'])}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isCompleted
                          ? const Color(0xFF10B981)
                          : isOverdue
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF6366F1),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectActionSheet extends StatelessWidget {
  final String title;
  final String buttonText;
  final Color color;
  final List<Widget> children;
  final VoidCallback onSubmit;

  const _ProjectActionSheet({
    required this.title,
    required this.buttonText,
    required this.color,
    required this.children,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: appThemeController.surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: appThemeController.textColor,
                ),
              ),
              const SizedBox(height: 16),
              ...children,
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: onSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    buttonText,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
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

class _ActionTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hintText;
  final int maxLines;

  const _ActionTextField({
    required this.controller,
    required this.label,
    required this.hintText,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        filled: true,
        fillColor: appThemeController.backgroundColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
        ),
      ),
    );
  }
}
