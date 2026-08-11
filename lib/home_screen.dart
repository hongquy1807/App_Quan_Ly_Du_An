import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme_controller.dart';
import 'project_detail_screen.dart';
import 'services/home_service.dart';
import 'services/auth_service.dart';
import 'task_detail_screen.dart';
import 'utils/color_utils.dart';
import 'widgets/app_bottom_navigation.dart';

enum HomeLanguage { vietnamese, english, chinese }

class HomeScreen extends StatefulWidget {
  final bool showBottomNavigation;

  const HomeScreen({super.key, this.showBottomNavigation = true});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  HomeLanguage _language = HomeLanguage.vietnamese;

  final _homeService = HomeService();

  // notifications state
  List<Map<String, dynamic>> notifications = [];

  // state populated from API
  String userName = '';
  String avatarUrl = '';
  List<Map<String, dynamic>> projects = [];
  List<Map<String, dynamic>> _tasks = [];
  int unreadNotifications = 0;
  bool _loading = true;

  List<Map<String, dynamic>> get tasks => _tasks;

  @override
  void initState() {
    super.initState();
    _loadLanguage();
    _loadDashboard();
  }

  String _t(String vi, String en, String zh) {
    switch (_language) {
      case HomeLanguage.vietnamese:
        return vi;
      case HomeLanguage.english:
        return en;
      case HomeLanguage.chinese:
        return zh;
    }
  }

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final rawValue = prefs.getString('app_language');
    if (!mounted) return;
    setState(() {
      _language = HomeLanguage.values.firstWhere(
        (language) => language.name == rawValue,
        orElse: () => HomeLanguage.vietnamese,
      );
    });
  }

  String _displayProjectName(String name) {
    switch (name) {
      case 'App di động':
        return _t('App di động', 'Mobile app', '移动应用');
      case 'Website bán hàng':
        return _t('Website bán hàng', 'Sales website', '销售网站');
      case 'Dự án AI':
        return _t('Dự án AI', 'AI project', 'AI 项目');
      case 'Hệ thống CRM':
        return _t('Hệ thống CRM', 'CRM system', 'CRM 系统');
      default:
        return name;
    }
  }

  String _displayTaskTitle(String title) {
    switch (title) {
      case 'Thiết kế UI cho màn hình chính':
        return _t(
          'Thiết kế UI cho màn hình chính',
          'Design UI for the main screen',
          '设计主屏幕 UI',
        );
      case 'Xây dựng API đăng nhập':
        return _t('Xây dựng API đăng nhập', 'Build login API', '构建登录 API');
      case 'Tối ưu hiệu suất ứng dụng':
        return _t(
          'Tối ưu hiệu suất ứng dụng',
          'Optimize app performance',
          '优化应用性能',
        );
      default:
        return title;
    }
  }

  String _taskStatusText(String statusCode) {
    switch (statusCode) {
      case 'in_progress':
        return _t('Đang làm', 'In progress', '进行中');
      case 'todo':
        return _t('Chưa nhận', 'Not accepted', '未接受');
      case 'review':
        return _t('Chờ duyệt', 'Pending review', '待审核');
      default:
        return _t('Chưa nhận', 'Not accepted', '未接受');
    }
  }

  Color _taskStatusColor(String statusCode, bool isOverdue) {
    if (isOverdue) return const Color(0xFFEF4444);
    switch (statusCode) {
      case 'in_progress':
        return const Color(0xFF10B981);
      case 'review':
        return const Color(0xFF6366F1);
      case 'todo':
      default:
        return const Color(0xFFF59E0B);
    }
  }

  IconData _taskStatusIcon(String statusCode, bool isOverdue) {
    if (isOverdue) return Icons.warning_amber_rounded;
    switch (statusCode) {
      case 'in_progress':
        return Icons.hourglass_top_rounded;
      case 'review':
        return Icons.fact_check_rounded;
      case 'todo':
      default:
        return Icons.inbox_rounded;
    }
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _loading = true;
    });

    try {
      final data = await _homeService.getDashboard();

      final user = data['user'] as Map<String, dynamic>?;
      final stats = data['stats'] as Map<String, dynamic>?;
      final apiProjects = (data['projects'] as List<dynamic>?) ?? [];
      final apiTasks = (data['tasks'] as List<dynamic>?) ?? [];
      final apiNotifications = (data['notifications'] as List<dynamic>?) ?? [];

      setState(() {
        userName = user?['name']?.toString() ?? '';
        avatarUrl = '';
        unreadNotifications = (() {
          final val = stats?['unreadNotifications'];
          if (val is int) return val;
          if (val is String) return int.tryParse(val) ?? 0;
          return 0;
        })();

        projects = apiProjects.map<Map<String, dynamic>>((p) {
          final map = Map<String, dynamic>.from(p as Map);
          return {
            'id': map['id']?.toString() ?? '',
            'name': map['name'] ?? '',
            'description': map['description'] ?? '',
            'color': map['color'] ?? '#6366F1',
            'icon': Icons.folder_open_rounded,
            'members': map['members'] ?? 0,
            'totalTasks': map['totalTasks'] ?? map['total_tasks'] ?? 0,
            'completedTasks':
                map['completedTasks'] ?? map['completed_tasks'] ?? 0,
          };
        }).toList();

        _tasks = apiTasks.map<Map<String, dynamic>>((t) {
          final map = Map<String, dynamic>.from(t as Map);
          DateTime? due;
          try {
            due = map['due_date'] != null
                ? DateTime.parse(map['due_date'].toString())
                : null;
          } catch (_) {
            due = null;
          }

          return {
            'id': map['id']?.toString() ?? '',
            'project_id': map['project_id']?.toString() ?? '',
            'title': map['title'] ?? '',
            'dueDate': due ?? DateTime.now().add(const Duration(days: 7)),
            'projectName': map['projectName'] ?? map['project_name'] ?? '',
            'projectColor':
                map['projectColor'] ?? map['project_color'] ?? '#6366F1',
            'statusCode': map['status_code'] ?? map['status'] ?? 'todo',
            'status': map['status'] ?? 'todo',
            'isCompleted': map['isCompleted'] ?? map['is_completed'] ?? false,
          };
        }).toList();

        notifications = apiNotifications.map<Map<String, dynamic>>((n) {
          final map = Map<String, dynamic>.from(n as Map);
          return {
            'id': map['id']?.toString() ?? '',
            'type': map['type'] ?? 'general',
            'content': map['content'] ?? '',
            'data': map['data'],
            'read': map['read'] == true || map['read'] == 1,
            'created_at': map['created_at'] ?? '',
          };
        }).toList();

        _loading = false;
      });
    } on ApiException catch (err) {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(err.message)));
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              'Không thể tải dữ liệu trang chủ.',
              'Unable to load home data.',
              '无法加载首页数据。',
            ),
          ),
        ),
      );
    }
  }

  void _openProjectDetail(Map<String, dynamic> project) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProjectDetailScreen(project: project),
      ),
    );
  }

  void _openTaskDetail(Map<String, dynamic> task) {
    final projectId = task['project_id']?.toString() ?? '';
    final project = projects.firstWhere(
      (item) => item['id']?.toString() == projectId,
      orElse: () => {
        'id': projectId,
        'name': task['projectName']?.toString() ?? '',
        'description': '',
        'color': task['projectColor']?.toString() ?? '#6366F1',
        'icon': Icons.folder_open_rounded,
      },
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TaskDetailScreen(task: task, project: project),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final incompleteTasks = tasks.where((t) => !t['isCompleted']).toList();
    incompleteTasks.sort(
      (a, b) => (a['dueDate'] as DateTime).compareTo(b['dueDate'] as DateTime),
    );

    final theme = appThemeController;

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // ============ HEADER ============
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: theme.surfaceColor,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 20,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Avatar v?i gradient border
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: CircleAvatar(
                      radius: 25,
                      backgroundColor: const Color(0xFFE5E7EB),
                      child: Text(
                        userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF6366F1),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.wb_sunny,
                              size: 14,
                              color: Color(0xFFF59E0B),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _t(
                                'Chúc bạn làm việc hiệu quả!',
                                'Have a productive day!',
                                '祝你工作高效！',
                              ),
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF6B7280),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Icon th?ng b?o v?i badge
                  Stack(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: theme.backgroundColor,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.notifications_none),
                          color: theme.textColor,
                          onPressed: () {
                            Navigator.pushNamed(context, '/notifications');
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ),
                      if (unreadNotifications > 0)
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            height: 18,
                            decoration: const BoxDecoration(
                              color: Color(0xFFEF4444),
                              borderRadius: BorderRadius.all(
                                Radius.circular(9),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                unreadNotifications > 99
                                    ? '99+'
                                    : unreadNotifications.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // ============ N?I DUNG CH?NH ============
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _loadDashboard,
                      color: theme.primaryColor,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ----- TH?NG TIN NHANH -----
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFF6366F1),
                                  Color(0xFF8B5CF6),
                                  Color(0xFFA78BFA),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF6366F1,
                                  ).withValues(alpha: 0.3),
                                  spreadRadius: 2,
                                  blurRadius: 15,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildStatItem(
                                  icon: Icons.folder_open_rounded,
                                  value: projects.length.toString(),
                                  label: _t(
                                    'Dự án đã tham gia',
                                    'Joined projects',
                                    '已参与项目',
                                  ),
                                ),
                                Container(
                                  width: 1,
                                  height: 50,
                                  color: Colors.white.withValues(alpha: 0.2),
                                ),
                                _buildStatItem(
                                  icon: Icons.pending_actions_rounded,
                                  value: incompleteTasks.length.toString(),
                                  label: _t(
                                    'Task chưa hoàn thành',
                                    'Incomplete tasks',
                                    '未完成任务',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // ----- D? ?N C?A B?N -----
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    _t(
                                      'Dự án của bạn',
                                      'Your projects',
                                      '你的项目',
                                    ),
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: theme.textColor,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF6366F1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      projects.length.toString(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              TextButton(
                                onPressed: () =>
                                    Navigator.pushReplacementNamed(
                                  context,
                                  '/projects',
                                ),
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  _t('Xem tất cả →', 'View all →', '查看全部 →'),
                                  style: const TextStyle(
                                    color: Color(0xFF6366F1),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 164,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: projects.length,
                              itemBuilder: (context, index) {
                                final project = projects[index];
                                final projectColor = parseHexColor(
                                  project['color'],
                                );
                                final totalTasks = _toInt(
                                  project['totalTasks'],
                                );
                                final completedTasks = _toInt(
                                  project['completedTasks'],
                                );
                                final memberCount = _toInt(project['members']);

                                return InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () => _openProjectDetail(project),
                                  child: Container(
                                    width: 180,
                                    margin: const EdgeInsets.only(right: 12),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: theme.surfaceColor,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.grey.withValues(
                                            alpha: 0.08,
                                          ),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: projectColor.withValues(
                                                  alpha: 0.1,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: Icon(
                                                project['icon'],
                                                size: 18,
                                                color: projectColor,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                _displayProjectName(
                                                  project['name']?.toString() ??
                                                      '',
                                                ),
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 14,
                                                  color: theme.textColor,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 18),
                                        Text(
                                          project['description'],
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: theme.mutedTextColor,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            _buildProjectStatChip(
                                              Icons.task_alt_rounded,
                                              '$completedTasks/$totalTasks',
                                              projectColor,
                                            ),
                                            const SizedBox(width: 8),
                                            _buildProjectStatChip(
                                              Icons.people_rounded,
                                              memberCount.toString(),
                                              projectColor,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 24),

                          // ----- NHI?M V? C?A B?N -----
                          Row(
                            children: [
                              Text(
                                _t(
                                  'Nhiệm vụ của bạn',
                                  'Your tasks',
                                  '你的任务',
                                ),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: theme.textColor,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF59E0B),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  incompleteTasks.length.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (incompleteTasks.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(32),
                              decoration: BoxDecoration(
                                color: theme.surfaceColor,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withValues(alpha: 0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.check_circle_outline,
                                    size: 56,
                                    color: const Color(
                                      0xFF6B7280,
                                    ).withValues(alpha: 0.3),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _t(
                                      'Không có nhiệm vụ nào!',
                                      'No tasks found!',
                                      '暂无任务！',
                                    ),
                                    style: TextStyle(
                                      color: theme.mutedTextColor,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            Column(
                              children: incompleteTasks.map((task) {
                                final dueDate = task['dueDate'] as DateTime;
                                final isOverdue = dueDate.isBefore(
                                  DateTime.now(),
                                );
                                final statusCode =
                                    task['statusCode']?.toString() ?? 'todo';
                                final statusColor = _taskStatusColor(
                                  statusCode,
                                  isOverdue,
                                );
                                final statusLabel = isOverdue
                                    ? _t('Quá hạn', 'Overdue', '已逾期')
                                    : _taskStatusText(statusCode);
                                final projectColor = parseHexColor(
                                  task['projectColor'],
                                );

                                return InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: () => _openTaskDetail(task),
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: theme.surfaceColor,
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.grey.withValues(
                                            alpha: 0.06,
                                          ),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                      // Tr?ng th?i
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: statusColor.withValues(
                                            alpha: 0.1,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Icon(
                                          _taskStatusIcon(
                                            statusCode,
                                            isOverdue,
                                          ),
                                          color: statusColor,
                                          size: 22,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      // Th?ng tin
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _displayTaskTitle(
                                                task['title']?.toString() ?? '',
                                              ),
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: theme.textColor,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 6),

                                            // T?n d? ?n
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: projectColor.withValues(
                                                  alpha: 0.1,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                _displayProjectName(
                                                  task['projectName']
                                                          ?.toString() ??
                                                      '',
                                                ),
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w500,
                                                  color: projectColor,
                                                ),
                                              ),
                                            ),

                                            const SizedBox(height: 6),

                                            // Th?i gian
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.access_time_rounded,
                                                  size: 14,
                                                  color: theme.mutedTextColor,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '${dueDate.day.toString().padLeft(2, '0')}/${dueDate.month.toString().padLeft(2, '0')}',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: isOverdue
                                                        ? const Color(
                                                            0xFFEF4444,
                                                          )
                                                        : const Color(
                                                            0xFF6B7280,
                                                          ),
                                                    fontWeight: isOverdue
                                                        ? FontWeight.w600
                                                        : FontWeight.w400,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Badge
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: isOverdue
                                                ? [
                                                    const Color(0xFFEF4444),
                                                    const Color(0xFFDC2626),
                                                  ]
                                                : [
                                                    statusColor,
                                                    statusColor.withValues(
                                                      alpha: 0.82,
                                                    ),
                                                  ],
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: statusColor.withValues(
                                                alpha: 0.3,
                                              ),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Text(
                                          statusLabel,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          const SizedBox(height: 20),
                        ],
                      ),
                      ),
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: widget.showBottomNavigation
          ? const AppBottomNavigation(currentItem: AppBottomNavItem.home)
          : null,
    );
  }

  // ignore: unused_element
  Future<void> _showNotificationsPanel() async {
    try {
      // Fetch latest notifications from API
      final svc = _homeService;
      final resp = await svc.getNotifications(page: 1, limit: 20);
      final fetched = resp['data']?['notifications'] as List<dynamic>?;
      if (fetched != null) {
        setState(() {
          notifications = fetched.map<Map<String, dynamic>>((n) {
            final map = Map<String, dynamic>.from(n as Map);
            return {
              'id': map['id']?.toString() ?? '',
              'type': map['type'] ?? 'general',
              'content': map['content'] ?? '',
              'data': map['data'],
              'read': map['read'] == true || map['read'] == 1,
              'created_at': map['created_at'] ?? '',
            };
          }).toList();
        });
      }

      // Show a top-right aligned dialog panel
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (ctx) => Dialog(
          elevation: 0,
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.only(top: 60, right: 12, left: 12),
          child: Align(
            alignment: Alignment.topRight,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360, maxHeight: 420),
              child: Material(
                borderRadius: BorderRadius.circular(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(12),
                        ),
                        color: Color(0xFFF9FAFB),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _t('Thông báo', 'Notifications', '通知'),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            icon: const Icon(Icons.mark_email_read_rounded),
                            onPressed: () async {
                              await svc.markAllNotificationsRead();
                              setState(() {
                                for (var n in notifications) {
                                  n['read'] = true;
                                }
                                unreadNotifications = 0;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: notifications.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(20),
                              child: Text(
                                _t(
                                  'Không có thông báo.',
                                  'No notifications.',
                                  '暂无通知。',
                                ),
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              padding: const EdgeInsets.all(8),
                              itemCount: notifications.length,
                              separatorBuilder: (context, index) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final n = notifications[index];
                                return ListTile(
                                  tileColor: n['read']
                                      ? null
                                      : const Color(0xFFF5F3FF),
                                  title: Text(n['content'] ?? ''),
                                  subtitle: Text(
                                    n['created_at']?.toString() ?? '',
                                  ),
                                  onTap: () async {
                                    if (n['read'] == false) {
                                      try {
                                        await svc.markNotificationRead(
                                          int.parse(n['id'].toString()),
                                          true,
                                        );
                                        setState(() {
                                          n['read'] = true;
                                          if (unreadNotifications > 0) {
                                            unreadNotifications -= 1;
                                          }
                                        });
                                      } catch (_) {}
                                    }
                                  },
                                );
                              },
                            ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(_t('Đóng', 'Close', '关闭')),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    } on ApiException catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(err.message)));
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              'Không thể tải thông báo.',
              'Unable to load notifications.',
              '无法加载通知。',
            ),
          ),
        ),
      );
    }
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.9),
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildProjectStatChip(IconData icon, String value, Color color) {
    final theme = appThemeController;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              color: theme.textColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
