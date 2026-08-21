import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'app_theme_controller.dart';
import 'completed_task_detail_screen.dart';
import 'services/project_service.dart';
import 'services/profile_service.dart';

class CompletedProjectDetailScreen extends StatefulWidget {
  const CompletedProjectDetailScreen({super.key, required this.project});

  final Map<String, dynamic> project;

  @override
  State<CompletedProjectDetailScreen> createState() =>
      _CompletedProjectDetailScreenState();
}

class _CompletedProjectDetailScreenState
    extends State<CompletedProjectDetailScreen> {
  final ProjectService _projectService = ProjectService();
  final ProfileService _profileService = ProfileService();
  final TextEditingController _searchController = TextEditingController();

  Map<String, dynamic> _project = {};
  List<Map<String, dynamic>> _tasks = [];
  List<Map<String, dynamic>> _members = [];

  String _activeTab = 'tasks';
  String _taskFilter = 'all';
  String _searchQuery = '';
  String _currentUserId = '';
  bool _isAscending = true;
  bool _isLoading = true;
  bool _isExporting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _project = Map<String, dynamic>.from(widget.project);
    _loadDetail();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDetail() async {
    final id = _project['id']?.toString() ?? '';
    if (id.isEmpty) {
      setState(() {
        _error = 'Không tìm thấy dự án.';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final detail = await _projectService.getProjectDetail(id);
      if (!mounted) return;
      final projectData = detail['project'];
      final tasksData = detail['tasks'];
      final membersData = detail['members'];
      setState(() {
        _project = projectData is Map
            ? Map<String, dynamic>.from(projectData)
            : _project;
        _tasks = tasksData is List
            ? tasksData
                .whereType<Map>()
                .map((task) => _mapTask(Map<String, dynamic>.from(task)))
                .toList()
            : [];
        _members = membersData is List
            ? membersData
                .whereType<Map>()
                .map((member) => Map<String, dynamic>.from(member))
                .toList()
            : [];
        _currentUserId = detail['current_user_id']?.toString() ?? '';
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
      'assignee': task['assignee']?.toString() ?? 'Cả team',
      'assigneeId':
          task['assigneeId']?.toString() ?? task['assignee_id']?.toString() ?? '',
      'dueDate': _parseDate(task['dueDate'] ?? task['due_date']),
      'statusCode': statusCode,
      'isCompleted': task['isCompleted'] == true || statusCode == 'done',
    };
  }

  DateTime? _parseDate(dynamic value) {
    final text = value?.toString();
    if (text == null || text.isEmpty) return null;
    return DateTime.tryParse(text);
  }

  List<Map<String, dynamic>> get _visibleTasks {
    var result = _tasks.where((task) {
      if (_taskFilter == 'mine') {
        final assigneeId = task['assigneeId']?.toString() ?? '';
        if (assigneeId.isNotEmpty && assigneeId != _currentUserId) {
          return false;
        }
      }

      if (_searchQuery.trim().isEmpty) return true;
      final query = _searchQuery.toLowerCase();
      final title = task['title']?.toString().toLowerCase() ?? '';
      final description = task['description']?.toString().toLowerCase() ?? '';
      final assignee = task['assignee']?.toString().toLowerCase() ?? '';
      return title.contains(query) ||
          description.contains(query) ||
          assignee.contains(query);
    }).toList();

    result.sort((a, b) {
      final titleA = a['title']?.toString().toLowerCase() ?? '';
      final titleB = b['title']?.toString().toLowerCase() ?? '';
      return _isAscending ? titleA.compareTo(titleB) : titleB.compareTo(titleA);
    });
    return result;
  }

  List<Map<String, dynamic>> get _visibleMembers {
    final query = _searchQuery.toLowerCase();
    final result = _members.where((member) {
      if (query.isEmpty) return true;
      final name = member['name']?.toString().toLowerCase() ?? '';
      final email = member['email']?.toString().toLowerCase() ?? '';
      final role = _memberRole(member).toLowerCase();
      return name.contains(query) || email.contains(query) || role.contains(query);
    }).toList();

    result.sort((a, b) {
      final roleCompare = _roleRank(a).compareTo(_roleRank(b));
      if (roleCompare != 0) return roleCompare;
      final nameA = a['name']?.toString().toLowerCase() ?? '';
      final nameB = b['name']?.toString().toLowerCase() ?? '';
      return _isAscending ? nameA.compareTo(nameB) : nameB.compareTo(nameA);
    });
    return result;
  }

  int _roleRank(Map<String, dynamic> member) {
    final roleId = int.tryParse(
          member['project_role_id']?.toString() ??
              member['role_id']?.toString() ??
              '',
        ) ??
        3;
    if (roleId == 1) return 0;
    if (roleId == 2) return 1;
    return 2;
  }

  String _memberRole(Map<String, dynamic> member) {
    final roleName = member['project_role_name']?.toString() ??
        member['role_name']?.toString() ??
        member['role']?.toString() ??
        '';
    if (roleName.isNotEmpty) return roleName;
    switch (_roleRank(member)) {
      case 0:
        return 'Trưởng nhóm';
      case 1:
        return 'Phó nhóm';
      default:
        return 'Thành viên';
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '--/--/----';
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  String _statusText(Map<String, dynamic> task) {
    final statusCode = task['statusCode']?.toString() ?? '';
    if (task['isCompleted'] == true || statusCode == 'done') return 'Hoàn thành';
    if (statusCode == 'in_progress') return 'Đang làm';
    if (statusCode == 'review') return 'Chờ duyệt';
    return 'Chưa nhận';
  }

  Color _statusColor(Map<String, dynamic> task) {
    final statusCode = task['statusCode']?.toString() ?? '';
    if (task['isCompleted'] == true || statusCode == 'done') {
      return const Color(0xFF10B981);
    }
    if (statusCode == 'in_progress') return const Color(0xFF6366F1);
    if (statusCode == 'review') return const Color(0xFFF59E0B);
    return const Color(0xFF64748B);
  }

  Future<void> _exportReport() async {
    final projectId = _project['id']?.toString() ?? '';
    if (projectId.isEmpty || _isExporting) return;

    setState(() => _isExporting = true);
    try {
      final report = await _projectService.downloadCompletedProjectReport(
        projectId,
      );
      final savedPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Lưu báo cáo dự án',
        fileName: report.fileName,
        bytes: report.bytes,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            savedPath == null
                ? 'Đã hủy lưu báo cáo.'
                : 'Đã xuất báo cáo dự án.',
          ),
        ),
      );
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err.toString())),
      );
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
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
                onRefresh: _loadDetail,
                child: _buildBody(theme),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(AppThemeController theme) {
    final name = _project['name']?.toString() ?? 'Dự án đã hoàn thành';
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
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
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                color: theme.textColor,
              ),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.textColor,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: theme.backgroundColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                _buildTopTab(
                  value: 'tasks',
                  label: 'Công việc thực hiện',
                  icon: Icons.task_alt_rounded,
                ),
                _buildTopTab(
                  value: 'members',
                  label: 'Thành viên dự án',
                  icon: Icons.people_alt_rounded,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopTab({
    required String value,
    required String label,
    required IconData icon,
  }) {
    final theme = appThemeController;
    final selected = _activeTab == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _activeTab = value;
            _searchQuery = '';
            _searchController.clear();
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? theme.primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? Colors.white : theme.mutedTextColor,
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? Colors.white : theme.textColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
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
        padding: const EdgeInsets.fromLTRB(24, 140, 24, 24),
        children: [
          Icon(Icons.error_outline_rounded, size: 72, color: theme.primaryColor),
          const SizedBox(height: 18),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.textColor,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
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
        if (_activeTab == 'tasks') _buildTaskTools(theme) else _buildMemberTools(theme),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: _buildSearch(theme)),
            const SizedBox(width: 10),
            _buildExportButton(theme),
          ],
        ),
        const SizedBox(height: 16),
        if (_activeTab == 'tasks') _buildTasksList() else _buildMembersList(),
      ],
    );
  }

  Widget _buildTaskTools(AppThemeController theme) {
    return Row(
      children: [
        Expanded(
          child: _buildToolCard(
            icon: Icons.list_rounded,
            value: _tasks.length.toString(),
            label: 'Tất cả',
            selected: _taskFilter == 'all',
            onTap: () => setState(() => _taskFilter = 'all'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildToolCard(
            icon: Icons.person_rounded,
            value: _tasks
                .where((task) {
                  final assigneeId = task['assigneeId']?.toString() ?? '';
                  return assigneeId.isEmpty || assigneeId == _currentUserId;
                })
                .length
                .toString(),
            label: 'Tôi',
            selected: _taskFilter == 'mine',
            onTap: () => setState(() => _taskFilter = 'mine'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildToolCard(
            icon: _isAscending
                ? Icons.arrow_upward_rounded
                : Icons.arrow_downward_rounded,
            value: '',
            label: 'Sắp xếp',
            onTap: () => setState(() => _isAscending = !_isAscending),
          ),
        ),
      ],
    );
  }

  Widget _buildMemberTools(AppThemeController theme) {
    return Row(
      children: [
        Expanded(
          child: _buildToolCard(
            icon: Icons.groups_rounded,
            value: _members.length.toString(),
            label: 'Tổng thành viên',
            onTap: null,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildToolCard(
            icon: _isAscending
                ? Icons.arrow_upward_rounded
                : Icons.arrow_downward_rounded,
            value: '',
            label: 'Sắp xếp',
            onTap: () => setState(() => _isAscending = !_isAscending),
          ),
        ),
      ],
    );
  }

  Widget _buildToolCard({
    required IconData icon,
    required String value,
    required String label,
    required VoidCallback? onTap,
    bool selected = false,
  }) {
    final theme = appThemeController;
    return GestureDetector(
      onTap: onTap,
      child: Container(
          height: 86,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: selected ? theme.primaryColor : theme.surfaceColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? theme.primaryColor
                  : theme.mutedTextColor.withValues(alpha: 0.1),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              value.isEmpty
                  ? Icon(icon, color: selected ? Colors.white : theme.primaryColor)
                  : Text(
                      value,
                      style: TextStyle(
                        color: selected ? Colors.white : theme.primaryColor,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected ? Colors.white : theme.mutedTextColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
      ),
    );
  }

  Widget _buildSearch(AppThemeController theme) {
    return TextField(
      controller: _searchController,
      onChanged: (value) => setState(() => _searchQuery = value),
      style: TextStyle(color: theme.textColor),
      decoration: InputDecoration(
        hintText: _activeTab == 'tasks'
            ? 'Tìm kiếm công việc'
            : 'Tìm kiếm thành viên',
        hintStyle: TextStyle(color: theme.mutedTextColor),
        prefixIcon: Icon(Icons.search_rounded, color: theme.mutedTextColor),
        filled: true,
        fillColor: theme.surfaceColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildExportButton(AppThemeController theme) {
    return Tooltip(
      message: 'Xuất báo cáo',
      child: SizedBox(
        width: 54,
        height: 54,
        child: ElevatedButton(
          onPressed: _isExporting ? null : _exportReport,
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.zero,
            backgroundColor: theme.primaryColor,
            foregroundColor: Colors.white,
            disabledBackgroundColor: theme.primaryColor.withValues(alpha: 0.45),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
          ),
          child: _isExporting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.file_download_rounded, size: 24),
        ),
      ),
    );
  }

  Widget _buildTasksList() {
    final tasks = _visibleTasks;
    if (tasks.isEmpty) {
      return _buildEmptyState(Icons.task_alt_rounded, 'Không có công việc phù hợp');
    }
    return Column(children: tasks.map(_buildTaskCard).toList());
  }

  Widget _buildTaskCard(Map<String, dynamic> task) {
    final theme = appThemeController;
    final color = _statusColor(task);
    final dueDate = task['dueDate'] as DateTime?;
    final assigneeId = task['assigneeId']?.toString() ?? '';
    final assigneeText = assigneeId.isEmpty
        ? 'Cả team'
        : assigneeId == _currentUserId
            ? 'Tôi'
            : task['assignee']?.toString() ?? '';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CompletedTaskDetailScreen(
              task: Map<String, dynamic>.from(task),
              project: _project,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.mutedTextColor.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 4,
              height: 48,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task['title']?.toString() ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: theme.textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    task['description']?.toString() ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: theme.mutedTextColor, fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildChip(
                        Icons.person_rounded,
                        assigneeText,
                        theme.primaryColor,
                      ),
                      _buildChip(
                        Icons.access_time_rounded,
                        _formatDate(dueDate),
                        theme.mutedTextColor,
                      ),
                      _buildChip(
                        Icons.verified_rounded,
                        _statusText(task),
                        color,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: theme.mutedTextColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMembersList() {
    final members = _visibleMembers;
    if (members.isEmpty) {
      return _buildEmptyState(Icons.people_outline_rounded, 'Không có thành viên phù hợp');
    }
    return Column(
      children: List.generate(
        members.length,
        (index) => _buildMemberCard(members[index]),
      ),
    );
  }

  Widget _buildMemberCard(Map<String, dynamic> member) {
    final theme = appThemeController;
    final role = _memberRole(member);
    final color = _roleRank(member) == 0
        ? theme.primaryColor
        : _roleRank(member) == 1
            ? const Color(0xFFF59E0B)
            : const Color(0xFF10B981);
    final memberName = member['name']?.toString() ?? '';
    final memberEmail = member['email']?.toString() ?? '';
    final avatarUrl = _profileService.buildAvatarUrl(member['avatar']?.toString());
    final avatarLetter = memberName.isNotEmpty
        ? memberName[0].toUpperCase()
        : memberEmail.isNotEmpty
            ? memberEmail[0].toUpperCase()
            : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.mutedTextColor.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: color.withValues(alpha: 0.14),
            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
            onBackgroundImageError: avatarUrl != null
                ? (_, __) {
                    if (!mounted) return;
                    setState(() {
                      member['avatar'] = null;
                    });
                  }
                : null,
            child: avatarUrl == null
                ? Text(
                    avatarLetter,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  memberName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  memberEmail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: theme.mutedTextColor, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _buildChip(Icons.badge_rounded, role, color),
        ],
      ),
    );
  }

  Widget _buildChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String title) {
    final theme = appThemeController;
    return Padding(
      padding: const EdgeInsets.only(top: 92),
      child: Column(
        children: [
          Icon(icon, size: 68, color: theme.mutedTextColor.withValues(alpha: 0.45)),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.mutedTextColor,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
