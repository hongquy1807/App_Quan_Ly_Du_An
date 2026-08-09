import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme_controller.dart';
import 'project_detail_screen.dart';
import 'services/project_service.dart';
import 'utils/color_utils.dart';
import 'widgets/app_bottom_navigation.dart';

enum ProjectLanguage { vietnamese, english, chinese }

class ProjectScreen extends StatefulWidget {
  final bool showBottomNavigation;

  const ProjectScreen({super.key, this.showBottomNavigation = true});

  @override
  State<ProjectScreen> createState() => _ProjectScreenState();
}

class _ProjectScreenState extends State<ProjectScreen> {
  final ProjectService _projectService = ProjectService();
  final List<Map<String, dynamic>> _projects = [];
  final List<Map<String, dynamic>> _projectInvitations = [];

  bool _isAscending = true;
  bool _isLoadingProjects = true;
  String? _projectError;
  ProjectLanguage _language = ProjectLanguage.vietnamese;

  final List<Color> _projectColors = const [
    Color(0xFF6366F1),
    Color(0xFFEC4899),
    Color(0xFFF59E0B),
    Color(0xFF10B981),
    Color(0xFF8B5CF6),
    Color(0xFFEF4444),
    Color(0xFF3B82F6),
  ];

  @override
  void initState() {
    super.initState();
    _loadLanguage();
    _loadProjects();
    _loadProjectInvitations();
  }

  String _t(String vi, String en, String zh) {
    switch (_language) {
      case ProjectLanguage.vietnamese:
        return vi;
      case ProjectLanguage.english:
        return en;
      case ProjectLanguage.chinese:
        return zh;
    }
  }

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final rawValue = prefs.getString('app_language');
    if (!mounted) return;
    setState(() {
      _language = ProjectLanguage.values.firstWhere(
        (language) => language.name == rawValue,
        orElse: () => ProjectLanguage.vietnamese,
      );
    });
  }

  Future<void> _loadProjects() async {
    setState(() {
      _isLoadingProjects = true;
      _projectError = null;
    });

    try {
      final projects = await _projectService.getProjects(
        ascending: _isAscending,
      );
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _projects
          ..clear()
          ..addAll(projects.map((project) => _mapApiProject(project, prefs)));
        _sortProjects();
        _isLoadingProjects = false;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _projectError = err.toString();
        _isLoadingProjects = false;
      });
    }
  }

  Future<void> _loadProjectInvitations() async {
    try {
      final invitations = await _projectService.getProjectInvitations();
      if (!mounted) return;
      setState(() {
        _projectInvitations
          ..clear()
          ..addAll(invitations);
      });
    } catch (err) {
      if (!mounted) return;
      _showSnackBar(err.toString(), isError: true);
    }
  }

  Future<void> _respondInvitation(
    Map<String, dynamic> invitation, {
    required bool accepted,
  }) async {
    final invitationId = invitation['id']?.toString() ?? '';
    if (invitationId.isEmpty) return;

    try {
      if (accepted) {
        await _projectService.acceptProjectInvitation(invitationId);
      } else {
        await _projectService.declineProjectInvitation(invitationId);
      }

      if (!mounted) return;
      setState(() {
        _projectInvitations.removeWhere(
          (item) => item['id']?.toString() == invitationId,
        );
      });
      Navigator.of(context).pop();
      if (accepted) {
        _loadProjects();
      }
      _showSnackBar(
        accepted
            ? _t('Đã xác nhận lời mời', 'Invitation accepted', '已接受邀请')
            : _t('Đã từ chối lời mời', 'Invitation declined', '已拒绝邀请'),
      );
    } catch (err) {
      if (!mounted) return;
      _showSnackBar(err.toString(), isError: true);
    }
  }

  Map<String, dynamic> _mapApiProject(
    Map<String, dynamic> project, [
    SharedPreferences? prefs,
  ]) {
    final projectId = project['id']?.toString() ?? '';
    final localColor = prefs?.getString('project_color_$projectId');
    return {
      ...project,
      'id': projectId,
      'name': project['name']?.toString() ?? '',
      'description': project['description']?.toString() ?? '',
      'color': localColor ?? project['color']?.toString() ?? '#6366F1',
      'icon': Icons.folder_open_rounded,
      'members': project['members'] ?? 1,
      'totalTasks': project['totalTasks'] ?? project['total_tasks'] ?? 0,
      'completedTasks':
          project['completedTasks'] ?? project['completed_tasks'] ?? 0,
    };
  }

  bool _isProjectLeader(Map<String, dynamic> project) {
    return NumberParser.toInt(project['project_role_id']) == 1;
  }

  String _colorToHex(Color color) {
    final value = color.toARGB32() & 0xFFFFFF;
    return '#${value.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  Future<void> _saveProjectColor(Map<String, dynamic> project, Color color) async {
    final projectId = project['id']?.toString() ?? '';
    if (projectId.isEmpty) return;

    final colorHex = _colorToHex(color);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('project_color_$projectId', colorHex);
    if (!mounted) return;
    setState(() {
      final index = _projects.indexWhere((item) => item['id'] == projectId);
      if (index != -1) {
        _projects[index] = {
          ..._projects[index],
          'color': colorHex,
        };
      }
    });
  }

  void _sortProjects() {
    _projects.sort((a, b) {
      final nameA = (a['name'] ?? '').toString().toLowerCase();
      final nameB = (b['name'] ?? '').toString().toLowerCase();
      return _isAscending ? nameA.compareTo(nameB) : nameB.compareTo(nameA);
    });
  }

  String _projectName(Map<String, dynamic> project) {
    return project['name']?.toString() ?? '';
  }

  String _projectDescription(Map<String, dynamic> project) {
    return project['description']?.toString() ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final theme = appThemeController;
    return Scaffold(
      backgroundColor: theme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            _buildBodyActions(),
            const SizedBox(height: 16),
            Expanded(child: _buildProjectBody()),
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
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
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
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            _t('Dự án', 'Projects', '项目'),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: theme.textColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _t(
              'Quản lý tất cả dự án của bạn',
              'Manage all your projects',
              '管理你的所有项目',
            ),
            style: TextStyle(fontSize: 13, color: theme.mutedTextColor),
          ),
        ],
      ),
    );
  }

  Widget _buildBodyActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _buildActionTile(
            icon: Icons.folder_open_rounded,
            title: _projects.length.toString(),
            subtitle: _t('Tổng dự án', 'Total projects', '项目总数'),
            onTap: () {},
            emphasizeTitle: true,
          ),
          const SizedBox(width: 8),
          _buildActionTile(
            icon: Icons.person_add_alt_1_rounded,
            title: '',
            subtitle: _t('Lời mời', 'Invites', '邀请'),
            badgeCount: _projectInvitations.length,
            onTap: _showProjectInvitationsDialog,
          ),
          const SizedBox(width: 8),
          _buildActionTile(
            icon: Icons.add_rounded,
            title: '',
            subtitle: _t('Thêm dự án', 'Add project', '添加项目'),
            onTap: () async {
              final created = await Navigator.pushNamed(
                context,
                '/create-project',
              );
              if (created == true && mounted) {
                _loadProjects();
                _loadProjectInvitations();
              }
            },
          ),
          const SizedBox(width: 8),
          _buildActionTile(
            icon: _isAscending
                ? Icons.arrow_upward_rounded
                : Icons.arrow_downward_rounded,
            title: '',
            subtitle: _t('Sắp xếp', 'Sort', '排序'),
            onTap: () {
              setState(() {
                _isAscending = !_isAscending;
                _sortProjects();
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool emphasizeTitle = false,
    int badgeCount = 0,
  }) {
    final theme = appThemeController;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          height: 82,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
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
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  if (title.isNotEmpty)
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: emphasizeTitle ? 22 : 16,
                        fontWeight: FontWeight.w800,
                        color: theme.primaryColor,
                      ),
                    )
                  else
                    Icon(icon, color: theme.primaryColor, size: 24),
                  if (badgeCount > 0)
                    Positioned(
                      top: -8,
                      right: -12,
                      child: Container(
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: theme.surfaceColor,
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            badgeCount > 99 ? '99+' : badgeCount.toString(),
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
              const SizedBox(height: 6),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: theme.mutedTextColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProjectBody() {
    final theme = appThemeController;
    if (_isLoadingProjects) {
      return Center(
        child: CircularProgressIndicator(color: theme.primaryColor),
      );
    }

    if (_projectError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.wifi_off_rounded,
                size: 64,
                color: theme.mutedTextColor.withValues(alpha: 0.35),
              ),
              const SizedBox(height: 12),
              Text(
                _t('Không thể tải dự án', 'Cannot load projects', '无法加载项目'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: theme.textColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _projectError!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: theme.mutedTextColor),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadProjects,
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

    if (_projects.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.folder_open_rounded,
                size: 80,
                color: theme.mutedTextColor.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 16),
              Text(
                _t('Chưa có dự án nào', 'No projects yet', '暂无项目'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: theme.mutedTextColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _t(
                  'Nhấn nút "+" để tạo dự án mới',
                  'Tap "+" to create a new project',
                  '点击“+”创建新项目',
                ),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: theme.mutedTextColor),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([
          _loadProjects(),
          _loadProjectInvitations(),
        ]);
      },
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        itemCount: _projects.length,
        itemBuilder: (context, index) => _buildProjectCard(_projects[index]),
      ),
    );
  }

  Widget _buildProjectCard(Map<String, dynamic> project) {
    final theme = appThemeController;
    final color = parseHexColor(project['color']);
    final totalTasks = NumberParser.toInt(project['totalTasks']);
    final completedTasks = NumberParser.toInt(project['completedTasks']);
    final progress = totalTasks == 0 ? 0.0 : completedTasks / totalTasks;
    final isLeader = _isProjectLeader(project);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProjectDetailScreen(project: project),
          ),
        ).then((_) {
          if (mounted) _loadProjects();
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.surfaceColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.folder_open_rounded,
                    color: color,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _projectName(project),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: theme.textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _projectDescription(project),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.mutedTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  color: theme.surfaceColor,
                  icon: Icon(
                    Icons.more_vert_rounded,
                    color: theme.mutedTextColor,
                  ),
                  onSelected: (value) => _handleProjectMenu(value, project),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'color',
                      child: _buildMenuItem(
                        Icons.palette_rounded,
                        _t('Đổi màu', 'Change color', '更改颜色'),
                        theme.textColor,
                      ),
                    ),
                    if (isLeader)
                      PopupMenuItem(
                        value: 'edit',
                        child: _buildMenuItem(
                          Icons.edit_rounded,
                          _t('Sửa', 'Edit', '编辑'),
                          theme.textColor,
                        ),
                      ),
                    if (isLeader)
                      PopupMenuItem(
                        value: 'complete',
                        child: _buildMenuItem(
                          Icons.check_circle_rounded,
                          _t('Hoàn thành', 'Complete', '完成'),
                          const Color(0xFF10B981),
                        ),
                      ),
                    if (isLeader)
                      PopupMenuItem(
                        value: 'delete',
                        child: _buildMenuItem(
                          Icons.delete_outline_rounded,
                          _t('Xóa', 'Delete', '删除'),
                          const Color(0xFFEF4444),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _buildProjectStat(
                  Icons.task_alt_rounded,
                  '$completedTasks/$totalTasks',
                  color,
                ),
                const SizedBox(width: 10),
                _buildProjectStat(
                  Icons.people_rounded,
                  NumberParser.toInt(project['members']).toString(),
                  color,
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                minHeight: 7,
                backgroundColor: color.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectStat(IconData icon, String value, Color color) {
    final theme = appThemeController;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 5),
          Text(
            value,
            style: TextStyle(
              color: theme.textColor,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String label, Color color) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: color)),
      ],
    );
  }

  void _handleProjectMenu(String action, Map<String, dynamic> project) {
    switch (action) {
      case 'color':
        _showChangeProjectColorDialog(project);
        break;
      case 'edit':
        _showEditProjectDialog(project);
        break;
      case 'complete':
        _confirmCompleteProject(project);
        break;
      case 'delete':
        _confirmDeleteProject(project);
        break;
    }
  }

  void _showChangeProjectColorDialog(Map<String, dynamic> project) {
    final theme = appThemeController;
    final currentColor = project['color']?.toString() ?? '#6366F1';

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: theme.surfaceColor,
        title: Text(
          _t('Đổi màu dự án', 'Change project color', '更改项目颜色'),
          style: TextStyle(color: theme.textColor, fontWeight: FontWeight.w700),
        ),
        content: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _projectColors.map((color) {
            final selected =
                _colorToHex(color).toUpperCase() == currentColor.toUpperCase();
            return InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () async {
                Navigator.pop(dialogContext);
                await _saveProjectColor(project, color);
              },
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? theme.textColor : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: selected
                    ? const Icon(Icons.check_rounded, color: Colors.white)
                    : null,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showEditProjectDialog(Map<String, dynamic> project) {
    final theme = appThemeController;
    final nameController = TextEditingController(text: _projectName(project));
    final descriptionController = TextEditingController(
      text: _projectDescription(project),
    );

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: theme.surfaceColor,
        title: Text(
          _t('Sửa dự án', 'Edit project', '编辑项目'),
          style: TextStyle(color: theme.textColor, fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: TextStyle(color: theme.textColor),
              decoration: InputDecoration(
                labelText: _t('Tên dự án', 'Project name', '项目名称'),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descriptionController,
              style: TextStyle(color: theme.textColor),
              maxLines: 3,
              decoration: InputDecoration(
                labelText: _t('Mô tả', 'Description', '描述'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(_t('Hủy', 'Cancel', '取消')),
          ),
          TextButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(dialogContext);
              try {
                await _projectService.updateProject(
                  id: project['id'].toString(),
                  name: name,
                  description: descriptionController.text.trim(),
                );
                if (!mounted) return;
                _showSnackBar(
                  _t(
                    'Đã cập nhật dự án',
                    'Project updated',
                    '项目已更新',
                  ),
                );
                _loadProjects();
              } catch (err) {
                if (!mounted) return;
                _showSnackBar(err.toString(), isError: true);
              }
            },
            child: Text(_t('Lưu', 'Save', '保存')),
          ),
        ],
      ),
    ).then((_) {
      nameController.dispose();
      descriptionController.dispose();
    });
  }

  Future<void> _confirmCompleteProject(Map<String, dynamic> project) async {
    final confirmed = await _showConfirmDialog(
      title: _t('Hoàn thành dự án', 'Complete project', '完成项目'),
      message: _t(
        'Bạn có chắc muốn đánh dấu dự án này là hoàn thành không?',
        'Are you sure you want to mark this project as completed?',
        '确定要将此项目标记为完成吗？',
      ),
      confirmText: _t('Hoàn thành', 'Complete', '完成'),
      confirmColor: const Color(0xFF10B981),
    );
    if (confirmed != true) return;

    try {
      await _projectService.completeProject(project['id'].toString());
      if (!mounted) return;
      _showSnackBar(_t('Đã hoàn thành dự án', 'Project completed', '项目已完成'));
      _loadProjects();
    } catch (err) {
      if (!mounted) return;
      _showSnackBar(err.toString(), isError: true);
    }
  }

  void _confirmDeleteProject(Map<String, dynamic> project) {
    final theme = appThemeController;
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: theme.surfaceColor,
        title: Text(
          _t('Xóa dự án', 'Delete project', '删除项目'),
          style: TextStyle(color: theme.textColor, fontWeight: FontWeight.w700),
        ),
        content: TextField(
          controller: passwordController,
          obscureText: true,
          style: TextStyle(color: theme.textColor),
          decoration: InputDecoration(
            labelText: _t(
              'Nhập mật khẩu để xác nhận',
              'Enter password to confirm',
              '输入密码确认',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(_t('Hủy', 'Cancel', '取消')),
          ),
          TextButton(
            onPressed: () async {
              final password = passwordController.text;
              if (password.isEmpty) return;
              Navigator.pop(dialogContext);
              try {
                await _projectService.deleteProject(
                  id: project['id'].toString(),
                  password: password,
                );
                if (!mounted) return;
                _showSnackBar(_t('Đã xóa dự án', 'Project deleted', '项目已删除'));
                _loadProjects();
              } catch (err) {
                if (!mounted) return;
                _showSnackBar(err.toString(), isError: true);
              }
            },
            child: Text(
              _t('Xóa', 'Delete', '删除'),
              style: const TextStyle(color: Color(0xFFEF4444)),
            ),
          ),
        ],
      ),
    ).then((_) => passwordController.dispose());
  }

  Future<bool?> _showConfirmDialog({
    required String title,
    required String message,
    required String confirmText,
    required Color confirmColor,
  }) {
    final theme = appThemeController;
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: theme.surfaceColor,
        title: Text(
          title,
          style: TextStyle(color: theme.textColor, fontWeight: FontWeight.w700),
        ),
        content: Text(message, style: TextStyle(color: theme.mutedTextColor)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(_t('Hủy', 'Cancel', '取消')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(confirmText, style: TextStyle(color: confirmColor)),
          ),
        ],
      ),
    );
  }

  void _showProjectInvitationsDialog() {
    final theme = appThemeController;

    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420, maxHeight: 560),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
          decoration: BoxDecoration(
            color: theme.backgroundColor,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.person_add_alt_1_rounded,
                      color: theme.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _t('Lời mời tham gia', 'Project invitations', '项目邀请'),
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        color: theme.textColor,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    icon: const Icon(Icons.close_rounded),
                    color: theme.mutedTextColor,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Flexible(
                child: _projectInvitations.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 36),
                          child: Text(
                            _t(
                              'Chưa có lời mời mới',
                              'No new invitations',
                              '暂无新邀请',
                            ),
                            style: TextStyle(color: theme.mutedTextColor),
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        physics: const BouncingScrollPhysics(),
                        itemCount: _projectInvitations.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, index) =>
                            _buildInvitationCard(_projectInvitations[index]),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInvitationCard(Map<String, dynamic> invitation) {
    final theme = appThemeController;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: theme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.folder_shared_rounded,
              color: theme.primaryColor,
              size: 26,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  invitation['project_name']?.toString() ??
                      invitation['projectName']?.toString() ??
                      '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: theme.textColor,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  invitation['inviter_name']?.toString() ??
                      invitation['inviterName']?.toString() ??
                      '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: theme.textColor.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  invitation['inviter_email']?.toString() ??
                      invitation['inviterEmail']?.toString() ??
                      '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: theme.mutedTextColor),
                ),
              ],
            ),
          ),
          _buildInviteIconButton(
            icon: Icons.close_rounded,
            color: const Color(0xFFEF4444),
            onTap: () => _respondInvitation(invitation, accepted: false),
          ),
          const SizedBox(width: 8),
          _buildInviteIconButton(
            icon: Icons.check_rounded,
            color: const Color(0xFF10B981),
            onTap: () => _respondInvitation(invitation, accepted: true),
          ),
        ],
      ),
    );
  }

  Widget _buildInviteIconButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return const AppBottomNavigation(
      currentItem: AppBottomNavItem.projects,
      rounded: false,
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? const Color(0xFFEF4444) : const Color(0xFF10B981),
      ),
    );
  }
}

class NumberParser {
  static int toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
