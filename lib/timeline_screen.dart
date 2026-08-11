import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme_controller.dart';
import 'services/project_service.dart';
import 'task_detail_screen.dart';
import 'widgets/app_bottom_navigation.dart';
import 'utils/color_utils.dart';

enum TimelineLanguage { vietnamese, english, chinese }

class TimelineScreen extends StatefulWidget {
  final bool showBottomNavigation;

  const TimelineScreen({super.key, this.showBottomNavigation = true});

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  final ProjectService _projectService = ProjectService();
  String? _selectedProjectId;
  DateTime _startOfWeek = DateTime.now();
  String _selectedMode = 'overview';
  DateTime _selectedDate = DateTime.now();
  TimelineLanguage _language = TimelineLanguage.vietnamese;
  bool _isLoadingTimeline = true;
  String? _timelineError;

  bool get _isPinkTheme => appThemeController.mode == AppThemeMode.pink;

  Color get _timelineSurface =>
      _isPinkTheme ? const Color(0xFFFFFBFD) : appThemeController.surfaceColor;

  Color get _timelineSoft =>
      _isPinkTheme ? const Color(0xFFFFE4F1) : appThemeController.surfaceColor;

  Color get _timelineBorder =>
      _isPinkTheme ? const Color(0xFFF9A8D4) : Colors.grey.shade200;

  Color get _timelineText =>
      _isPinkTheme ? const Color(0xFF831843) : appThemeController.textColor;

  Color get _timelineMuted =>
      _isPinkTheme ? const Color(0xFF9D174D) : appThemeController.mutedTextColor;

  final List<Map<String, dynamic>> _projects = [];

  final List<Map<String, dynamic>> _allTasks = [];
  List<Map<String, dynamic>> _filteredTasks = [];
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadLanguage();
    final now = DateTime.now();
    _startOfWeek = DateTime(now.year, now.month, now.day - now.weekday + 1);
    _selectedDate = DateTime(now.year, now.month, now.day);
    _loadTimeline();
  }

  String _t(String vi, String en, String zh) {
    switch (_language) {
      case TimelineLanguage.vietnamese:
        return vi;
      case TimelineLanguage.english:
        return en;
      case TimelineLanguage.chinese:
        return zh;
    }
  }

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final rawValue = prefs.getString('app_language');
    if (!mounted) return;
    setState(() {
      _language = TimelineLanguage.values.firstWhere(
        (language) => language.name == rawValue,
        orElse: () => TimelineLanguage.vietnamese,
      );
    });
  }

  Future<void> _loadTimeline() async {
    setState(() {
      _isLoadingTimeline = true;
      _timelineError = null;
    });

    try {
      final data = await _projectService.getTimeline(
        weekStart: _startOfWeek,
        projectId: _selectedProjectId,
      );
      final projects = data['projects'];
      final tasks = data['tasks'];
      final currentUserId = data['current_user_id']?.toString();

      if (!mounted) return;
      final apiProjects = projects is List
          ? projects
              .whereType<Map>()
              .map((project) => Map<String, dynamic>.from(project))
              .toList()
          : <Map<String, dynamic>>[];
      final apiTasks = tasks is List
          ? tasks
              .whereType<Map>()
              .map((task) => _mapApiTask(Map<String, dynamic>.from(task)))
              .toList()
          : <Map<String, dynamic>>[];
      setState(() {
        _projects
          ..clear()
          ..addAll(apiProjects);
        _allTasks
          ..clear()
          ..addAll(apiTasks);
        _currentUserId = currentUserId;
        _isLoadingTimeline = false;
      });
      _filterTasks();
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _timelineError = err.toString();
        _isLoadingTimeline = false;
        _filteredTasks = [];
      });
    }
  }

  Map<String, dynamic> _mapApiTask(Map<String, dynamic> task) {
    final start = _parseApiDate(task['startDate'] ?? task['start_date']) ??
        _parseApiDate(task['created_at']) ??
        DateTime.now();
    final end = _parseApiDate(task['endDate'] ?? task['end_date']) ??
        _parseApiDate(task['due_date']) ??
        start;

    return {
      ...task,
      'id': task['id']?.toString() ?? '',
      'title': task['title']?.toString() ?? '',
      'projectId':
          task['projectId']?.toString() ?? task['project_id']?.toString() ?? '',
      'projectName': task['projectName']?.toString() ??
          task['project_name']?.toString() ??
          '',
      'assigneeId':
          task['assigneeId']?.toString() ?? task['assignee_id']?.toString() ?? '',
      'assignee_id': task['assignee_id'],
      'startDate': DateTime(start.year, start.month, start.day),
      'endDate': DateTime(end.year, end.month, end.day),
      'color': task['color']?.toString() ??
          task['projectColor']?.toString() ??
          '#6366F1',
      'progress': NumberParser.toInt(task['progress']).clamp(0, 100),
    };
  }

  DateTime? _parseApiDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    return DateTime.tryParse(text);
  }

  void _filterTasks() {
    final weekEnd = _startOfWeek.add(const Duration(days: 6));

    setState(() {
      _filteredTasks =
          _allTasks.where((task) {
            final start = task['startDate'] as DateTime;
            final end = task['endDate'] as DateTime;
            final isInSelectedProject =
                _selectedProjectId == null ||
                task['projectId'] == _selectedProjectId;
            final isInWeek =
                (start.isBefore(weekEnd.add(const Duration(days: 1))) &&
                end.isAfter(_startOfWeek.subtract(const Duration(days: 1))));
            final isAssignedToCurrentUser =
                _currentUserId == null ||
                _currentUserId!.isEmpty ||
                task['assigneeId']?.toString().isEmpty == true ||
                task['assigneeId']?.toString() == _currentUserId;

            return isAssignedToCurrentUser && isInSelectedProject && isInWeek;
          }).toList()..sort(
            (a, b) => (a['startDate'] as DateTime).compareTo(
              b['startDate'] as DateTime,
            ),
          );
    });
  }

  void _changeWeek(int direction) {
    setState(() {
      _startOfWeek = _startOfWeek.add(Duration(days: direction * 7));
      _selectedDate = _selectedDate.add(Duration(days: direction * 7));
    });
    _loadTimeline();
  }

  void _goToToday() {
    final now = DateTime.now();
    setState(() {
      _startOfWeek = DateTime(now.year, now.month, now.day - now.weekday + 1);
      _selectedDate = DateTime(now.year, now.month, now.day);
    });
    _loadTimeline();
  }

  Future<void> _openTaskDetail(Map<String, dynamic> task) async {
    final project = {
      'id': task['projectId']?.toString() ?? '',
      'name': task['projectName']?.toString() ?? '',
      'description': '',
      'color': task['color']?.toString() ?? '#6366F1',
    };

    final detailTask = {
      ...task,
      'project_id': task['projectId']?.toString() ?? '',
      'projectName': task['projectName']?.toString() ?? '',
      'projectColor': task['color']?.toString() ?? '#6366F1',
      'dueDate': task['endDate'],
      'description': task['description']?.toString() ?? '',
    };

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TaskDetailScreen(
          task: detailTask,
          project: project,
        ),
      ),
    );

    if (mounted) {
      _loadTimeline();
    }
  }

  String _formatDate(DateTime date) => DateFormat('dd/MM').format(date);

  Color _deadlineColor(DateTime deadline) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final deadlineDay = DateTime(deadline.year, deadline.month, deadline.day);
    final daysLeft = deadlineDay.difference(today).inDays;

    if (daysLeft <= 3) return const Color(0xFFEF4444);
    if (daysLeft <= 5) return const Color(0xFFF59E0B);
    return const Color(0xFF10B981);
  }

  String _weekdayShort(DateTime date) {
    final weekdays = [
      _t('T2', 'Mon', '周一'),
      _t('T3', 'Tue', '周二'),
      _t('T4', 'Wed', '周三'),
      _t('T5', 'Thu', '周四'),
      _t('T6', 'Fri', '周五'),
      _t('T7', 'Sat', '周六'),
      _t('CN', 'Sun', '周日'),
    ];
    return weekdays[date.weekday - 1];
  }

  String _weekdayFull(DateTime date) {
    final weekdays = [
      _t('Thứ Hai', 'Monday', '星期一'),
      _t('Thứ Ba', 'Tuesday', '星期二'),
      _t('Thứ Tư', 'Wednesday', '星期三'),
      _t('Thứ Năm', 'Thursday', '星期四'),
      _t('Thứ Sáu', 'Friday', '星期五'),
      _t('Thứ Bảy', 'Saturday', '星期六'),
      _t('Chủ Nhật', 'Sunday', '星期日'),
    ];
    return weekdays[date.weekday - 1];
  }

  String _projectName(String name) {
    switch (name) {
      case 'App di động':
        return _t('App di động', 'Mobile app', '移动应用');
      case 'Website bán hàng':
        return _t('Website bán hàng', 'Sales website', '销售网站');
      case 'Dự án AI':
        return _t('Dự án AI', 'AI project', 'AI 项目');
      default:
        return name;
    }
  }

  String _taskTitle(String title) {
    switch (title) {
      case 'Fix giao diện trang chủ':
        return _t('Fix giao diện trang chủ', 'Fix home UI', '修复首页界面');
      case 'Xây dựng API đăng nhập':
        return _t('Xây dựng API đăng nhập', 'Build login API', '构建登录 API');
      case 'Thiết kế database':
        return _t('Thiết kế database', 'Design database', '设计数据库');
      case 'Tối ưu hiệu suất':
        return _t('Tối ưu hiệu suất', 'Optimize performance', '优化性能');
      case 'Training model AI':
        return _t('Training model AI', 'Train AI model', '训练 AI 模型');
      case 'Viết tài liệu dự án':
        return _t('Viết tài liệu dự án', 'Write project documentation', '编写项目文档');
      case 'Deploy lên production':
        return _t('Deploy lên production', 'Deploy to production', '部署到生产环境');
      default:
        return title;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = appThemeController;
    final weekDays = List.generate(
      7,
      (index) => _startOfWeek.add(Duration(days: index)),
    );
    final weekEnd = _startOfWeek.add(const Duration(days: 6));

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            _buildModeTabs(),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoadingTimeline
                  ? RefreshIndicator(
                      onRefresh: _loadTimeline,
                      color: theme.primaryColor,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(
                            height: MediaQuery.of(context).size.height * 0.45,
                            child: _buildLoadingState(),
                          ),
                        ],
                      ),
                    )
                  : _timelineError != null
                      ? RefreshIndicator(
                          onRefresh: _loadTimeline,
                          color: theme.primaryColor,
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(
                                height:
                                    MediaQuery.of(context).size.height * 0.55,
                                child: _buildErrorState(),
                              ),
                            ],
                          ),
                        )
                      : _selectedMode == 'overview'
                          ? _buildOverviewContent(weekDays, weekEnd)
                          : _buildDetailContent(),
            ),
          ],
        ),
      ),
      bottomNavigationBar:
          widget.showBottomNavigation ? _buildBottomNavigationBar() : null,
    );
  }

  Widget _buildHeader() {
    final theme = appThemeController;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: _timelineSurface,
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
        children: [
          Row(
            children: [ 
              Icon(Icons.timeline_rounded, color: theme.primaryColor, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _t('Lịch', 'Timeline', '日程'),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _timelineText,
                      ),
                    ),
                    Text(
                      _t(
                        'Quản lý thời gian và nhiệm vụ',
                        'Manage time and tasks',
                        '管理时间和任务',
                      ),
                      style: TextStyle(
                        fontSize: 12,
                        color: _timelineMuted,
                      ),
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

  Widget _buildModeTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: _timelineSoft,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            _buildModeTab(
              'overview',
              _t('Tổng quan', 'Overview', '总览'),
              Icons.timeline_rounded,
            ),
            _buildModeTab(
              'detail',
              _t('Chi tiết', 'Details', '详情'),
              Icons.list_alt_rounded,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeTab(String value, String label, IconData icon) {
    final theme = appThemeController;
    final selected = _selectedMode == value;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          setState(() {
            _selectedMode = value;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: selected ? theme.primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 17,
                color: selected ? Colors.white : _timelineMuted,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : _timelineText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewContent(List<DateTime> weekDays, DateTime weekEnd) {
    return Column(
      children: [
        _buildOverviewControls(weekEnd),
        const SizedBox(height: 16),
        Expanded(
          child: _buildGanttChart(weekDays),
        ),
      ],
    );
  }

  Widget _buildOverviewControls(DateTime weekEnd, {bool padded = true}) {
    final theme = appThemeController;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: padded ? 20 : 0),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: _timelineSurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => _changeWeek(-1),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: _goToToday,
                    child: Center(
                      child: Text(
                        '${_formatDate(_startOfWeek)} - ${_formatDate(weekEnd)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: theme.primaryColor,
                        ),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _changeWeek(1),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: _timelineSurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedProjectId,
                hint: Text(
                  _t('Tất cả dự án', 'All projects', '所有项目'),
                  style: TextStyle(color: _timelineMuted),
                ),
                isExpanded: true,
                dropdownColor: _timelineSurface,
                style: TextStyle(color: _timelineText),
                iconEnabledColor: _timelineMuted,
                items: [
                  DropdownMenuItem<String>(
                    value: null,
                    child: Text(_t('Tất cả dự án', 'All projects', '所有项目')),
                  ),
                  ..._projects.map((project) {
                    final color = parseHexColor(project['color']);
                    return DropdownMenuItem<String>(
                      value: project['id'],
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_projectName(project['name'])),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedProjectId = value;
                  });
                  _loadTimeline();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailContent() {
    final weekEnd = _startOfWeek.add(const Duration(days: 6));
    final weekDays = List.generate(
      7,
      (index) => _startOfWeek.add(Duration(days: index)),
    );
    final selectedDay = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    final tasksInSelectedDay = _filteredTasks.where((task) {
      final start = task['startDate'] as DateTime;
      final end = task['endDate'] as DateTime;
      final startDay = DateTime(start.year, start.month, start.day);
      final endDay = DateTime(end.year, end.month, end.day);
      return !selectedDay.isBefore(startDay) && !selectedDay.isAfter(endDay);
    }).toList();

    return RefreshIndicator(
      onRefresh: _loadTimeline,
      color: appThemeController.primaryColor,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          _buildDetailControls(weekEnd, weekDays),
          const SizedBox(height: 16),
          Text(
            '${_weekdayFull(selectedDay)} - ${DateFormat('dd/MM/yyyy').format(selectedDay)}',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _timelineText,
            ),
          ),
          const SizedBox(height: 12),
          if (tasksInSelectedDay.isEmpty)
            _buildDetailEmptyState()
          else
            ...tasksInSelectedDay.map(_buildDetailTaskCard),
        ],
      ),
    );
  }

  Widget _buildDetailControls(DateTime weekEnd, List<DateTime> weekDays) {
    return Column(
      children: [
        _buildOverviewControls(weekEnd, padded: false),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: _timelineSurface,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: weekDays.map((day) => _buildSelectableDay(day)).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectableDay(DateTime day) {
    final theme = appThemeController;
    final selected = DateFormat('dd/MM/yyyy').format(day) ==
        DateFormat('dd/MM/yyyy').format(_selectedDate);
    final isWeekend = day.weekday == 6 || day.weekday == 7;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          setState(() {
            _selectedDate = DateTime(day.year, day.month, day.day);
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? theme.primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Text(
                _weekdayShort(day),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? Colors.white
                      : isWeekend
                          ? const Color(0xFFEF4444)
                          : _timelineMuted,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                day.day.toString(),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: selected ? Colors.white : _timelineText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailTaskCard(Map<String, dynamic> task) {
    final color = _deadlineColor(task['endDate'] as DateTime);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _openTaskDetail(task),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _timelineSurface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 68,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _taskTitle(task['title']),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _timelineText,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Icon(Icons.folder_rounded, size: 16, color: color),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          _projectName(task['projectName']),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: _timelineMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 16,
                        color: _timelineMuted,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${_t('Hạn chót', 'Deadline', '截止日期')}: ${DateFormat('dd/MM/yyyy').format(task['endDate'] as DateTime)}',
                        style: TextStyle(
                          fontSize: 13,
                          color: _timelineMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailEmptyState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _timelineSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(
          _t(
            'Ngày này chưa có nhiệm vụ nào',
            'No tasks for this day',
            '这一天暂无任务',
          ),
          style: TextStyle(color: _timelineMuted),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    final theme = appThemeController;
    return Center(
      child: CircularProgressIndicator(color: theme.primaryColor),
    );
  }

  Widget _buildErrorState() {
    final theme = appThemeController;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.wifi_off_rounded,
              size: 64,
              color: _timelineMuted.withValues(alpha: 0.45),
            ),
            const SizedBox(height: 12),
            Text(
              _t('Không thể tải lịch', 'Cannot load timeline', '无法加载日程'),
              style: TextStyle(
                color: _timelineText,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _timelineError ?? '',
              textAlign: TextAlign.center,
              style: TextStyle(color: _timelineMuted, fontSize: 13),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadTimeline,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                foregroundColor: Colors.white,
              ),
              child: Text(_t('Thử lại', 'Retry', '重试')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGanttChart(List<DateTime> weekDays) {
    final theme = appThemeController;
    const dayWidth = 92.0;
    const chartWidth = dayWidth * 7;

    return RefreshIndicator(
      onRefresh: _loadTimeline,
      color: theme.primaryColor,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: SizedBox(
            width: chartWidth,
            child: Column(
              children: [
                _buildWeekHeader(weekDays, dayWidth),
                const SizedBox(height: 8),
                if (_filteredTasks.isEmpty)
                  _buildOverviewEmptyRow(dayWidth)
                else
                  ..._filteredTasks.map((task) {
                    final start = task['startDate'] as DateTime;
                    final end = task['endDate'] as DateTime;
                    final color = _deadlineColor(end);
                    final weekStart = weekDays.first;
                    final weekEnd = weekDays.last;
                    final visibleStart =
                        start.isBefore(weekStart) ? weekStart : start;
                    final visibleEnd = end.isAfter(weekEnd) ? weekEnd : end;
                    final startIndex = visibleStart.difference(weekStart).inDays;
                    final endIndex = visibleEnd.difference(weekStart).inDays;

                    final leftOffset = startIndex * dayWidth;
                    final width = ((endIndex - startIndex + 1) * dayWidth)
                        .clamp(dayWidth, dayWidth * 7)
                        .toDouble();
                    final projectName = _projectName(task['projectName']);

                    return Container(
                      height: 70,
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: _timelineSurface,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withValues(alpha: 0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          Row(
                            children: List.generate(7, (index) {
                              final day = weekDays[index];
                              final isWeekend =
                                  day.weekday == 6 || day.weekday == 7;
                              return SizedBox(
                                width: dayWidth,
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: Border(
                                      right: BorderSide(
                                        color: appThemeController.isDark
                                            ? Colors.white.withValues(alpha: 0.08)
                                            : _timelineBorder,
                                        width: 0.5,
                                      ),
                                    ),
                                    color: isWeekend
                                        ? (appThemeController.isDark
                                            ? theme.backgroundColor.withValues(
                                                alpha: 0.55,
                                              )
                                            : _timelineSoft.withValues(
                                                alpha: 0.55,
                                              ))
                                        : null,
                                  ),
                                ),
                              );
                            }),
                          ),
                          Positioned(
                            left: leftOffset + 6,
                            top: 9,
                            width: width - 12,
                            child: Container(
                              height: 52,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    _taskTitle(task['title']),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  if (projectName.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      projectName,
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.9),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewEmptyRow(double dayWidth) {
    final theme = appThemeController;
    return Container(
      height: 92,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _timelineSurface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          Row(
            children: List.generate(7, (index) {
              final isWeekend = index >= 5;
              return SizedBox(
                width: dayWidth,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(
                      right: BorderSide(
                        color: appThemeController.isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : _timelineBorder,
                        width: 0.5,
                      ),
                    ),
                    color: isWeekend
                        ? (appThemeController.isDark
                            ? theme.backgroundColor.withValues(alpha: 0.55)
                            : _timelineSoft.withValues(alpha: 0.55))
                        : null,
                  ),
                ),
              );
            }),
          ),
          Center(
            child: Text(
              _t(
                'Không có công việc trong tuần này',
                'No work scheduled this week',
                '本周没有工作安排',
              ),
              style: TextStyle(color: _timelineMuted, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekHeader(List<DateTime> weekDays, double dayWidth) {
    final theme = appThemeController;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: _timelineSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: List.generate(7, (index) {
          final date = weekDays[index];
          final isToday =
              DateFormat('dd/MM/yyyy').format(date) ==
              DateFormat('dd/MM/yyyy').format(DateTime.now());
          final isWeekend = date.weekday == 6 || date.weekday == 7;

          return SizedBox(
            width: dayWidth,
            child: Column(
              children: [
                Text(
                  _weekdayShort(date),
                  style: TextStyle(
                    fontSize: 12,
                    color: isWeekend
                        ? (_isPinkTheme
                              ? const Color(0xFFBE185D)
                              : const Color(0xFFEF4444))
                        : _timelineMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isToday ? theme.primaryColor : null,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      date.day.toString(),
                      style: TextStyle(
                        color: isToday ? Colors.white : _timelineText,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return const AppBottomNavigation(
      currentItem: AppBottomNavItem.timeline,
    );
  }
}
