import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme_controller.dart';
import 'services/project_service.dart';
import 'utils/color_utils.dart';

enum CompletedProjectsLanguage { vietnamese, english, chinese }

class CompletedProjectsScreen extends StatefulWidget {
  const CompletedProjectsScreen({super.key});

  @override
  State<CompletedProjectsScreen> createState() =>
      _CompletedProjectsScreenState();
}

class _CompletedProjectsScreenState extends State<CompletedProjectsScreen> {
  final ProjectService _projectService = ProjectService();
  final List<Map<String, dynamic>> _projects = [];

  CompletedProjectsLanguage _language = CompletedProjectsLanguage.vietnamese;
  bool _isAscending = false;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLanguage();
    _loadProjects();
  }

  String _t(String vi, String en, String zh) {
    switch (_language) {
      case CompletedProjectsLanguage.vietnamese:
        return vi;
      case CompletedProjectsLanguage.english:
        return en;
      case CompletedProjectsLanguage.chinese:
        return zh;
    }
  }

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final rawValue = prefs.getString('app_language');
    if (!mounted) return;
    setState(() {
      _language = CompletedProjectsLanguage.values.firstWhere(
        (language) => language.name == rawValue,
        orElse: () => CompletedProjectsLanguage.vietnamese,
      );
    });
  }

  Future<void> _loadProjects() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final projects = await _projectService.getCompletedProjects(
        ascending: _isAscending,
      );
      if (!mounted) return;
      setState(() {
        _projects
          ..clear()
          ..addAll(projects);
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

  void _toggleSort() {
    setState(() {
      _isAscending = !_isAscending;
    });
    _loadProjects();
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
                onRefresh: _loadProjects,
                color: theme.primaryColor,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            icon: Icons.workspace_premium_rounded,
                            value: _projects.length.toString(),
                            label: _t(
                              'Tổng dự án',
                              'Total projects',
                              '项目总数',
                            ),
                            onTap: null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            icon: _isAscending
                                ? Icons.arrow_upward_rounded
                                : Icons.arrow_downward_rounded,
                            value: '',
                            label: _t('Sắp xếp', 'Sort', '排序'),
                            onTap: _toggleSort,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    if (_isLoading)
                      Padding(
                        padding: const EdgeInsets.only(top: 120),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: theme.primaryColor,
                          ),
                        ),
                      )
                    else if (_error != null)
                      _buildMessageState(
                        icon: Icons.error_outline_rounded,
                        title: _error!,
                        actionText: _t('Thử lại', 'Retry', '重试'),
                        onAction: _loadProjects,
                      )
                    else if (_projects.isEmpty)
                      _buildMessageState(
                        icon: Icons.inventory_2_outlined,
                        title: _t(
                          'Chưa có dự án hoàn thành',
                          'No completed projects yet',
                          '暂无已完成项目',
                        ),
                        actionText: null,
                        onAction: null,
                      )
                    else
                      ..._projects.map(_buildProjectCard),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(AppThemeController theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
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
              padding: const EdgeInsets.all(10),
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
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              _t('Dự án đã hoàn thành', 'Completed projects', '已完成项目'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: theme.textColor,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required VoidCallback? onTap,
  }) {
    final theme = appThemeController;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 92,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.surfaceColor,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            value.isEmpty
                ? Icon(icon, color: theme.primaryColor, size: 30)
                : Text(
                    value,
                    style: TextStyle(
                      color: theme.primaryColor,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: theme.mutedTextColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectCard(Map<String, dynamic> project) {
    final theme = appThemeController;
    final color = parseHexColor(project['color']?.toString() ?? '#6366F1');
    final name = project['name']?.toString() ?? '';
    final description = project['description']?.toString() ?? '';
    final memberCount = NumberParser.toInt(project['members']);
    final taskCount = NumberParser.toInt(
      project['totalTasks'] ?? project['total_tasks'],
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.folder_open_rounded, color: color, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.textColor,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: theme.mutedTextColor,
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildProjectMeta(
                      Icons.people_rounded,
                      _t(
                        '$memberCount thành viên',
                        '$memberCount members',
                        '$memberCount 名成员',
                      ),
                      color,
                    ),
                    _buildProjectMeta(
                      Icons.task_alt_rounded,
                      _t(
                        '$taskCount task',
                        '$taskCount tasks',
                        '$taskCount 个任务',
                      ),
                      color,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectMeta(IconData icon, String text, Color color) {
    final theme = appThemeController;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
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
              color: theme.textColor,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageState({
    required IconData icon,
    required String title,
    required String? actionText,
    required VoidCallback? onAction,
  }) {
    final theme = appThemeController;
    return Padding(
      padding: const EdgeInsets.only(top: 120),
      child: Column(
        children: [
          Icon(icon, size: 72, color: theme.mutedTextColor.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.textColor,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (actionText != null && onAction != null) ...[
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              child: Text(actionText),
            ),
          ],
        ],
      ),
    );
  }
}
