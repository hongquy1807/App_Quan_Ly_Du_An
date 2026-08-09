import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme_controller.dart';
import 'services/project_service.dart';

enum ProjectMembersLanguage { vietnamese, english, chinese }

class ProjectMembersScreen extends StatefulWidget {
  final Map<String, dynamic>? project;
  final List<Map<String, dynamic>>? members;

  const ProjectMembersScreen({super.key, this.project, this.members});

  @override
  State<ProjectMembersScreen> createState() => _ProjectMembersScreenState();
}

class _ProjectMembersScreenState extends State<ProjectMembersScreen> {
  final _searchController = TextEditingController();
  final _inviteEmailController = TextEditingController();
  final ProjectService _projectService = ProjectService();
  bool _isAscending = true;
  bool _showInviteInput = false;
  bool _isSendingInvite = false;
  String _query = '';
  ProjectMembersLanguage _language = ProjectMembersLanguage.vietnamese;

  late final List<Map<String, dynamic>> _members =
      widget.members ?? _sampleMembers;

  static final List<Map<String, dynamic>> _sampleMembers = [
    {
      'id': '1',
      'name': 'Nguyễn Văn A',
      'email': 'nguyenvana@email.com',
      'role': 'Trưởng nhóm',
    },
    {
      'id': '2',
      'name': 'Trần Thị B',
      'email': 'tranthib@email.com',
      'role': 'Phó nhóm',
    },
    {
      'id': '3',
      'name': 'Lê Văn C',
      'email': 'levanc@email.com',
      'role': 'Thành viên',
    },
    {
      'id': '4',
      'name': 'Phạm Thị D',
      'email': 'phamthid@email.com',
      'role': 'Thành viên',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadLanguage();
  }

  String _t(String vi, String en, String zh) {
    switch (_language) {
      case ProjectMembersLanguage.vietnamese:
        return vi;
      case ProjectMembersLanguage.english:
        return en;
      case ProjectMembersLanguage.chinese:
        return zh;
    }
  }

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final rawValue = prefs.getString('app_language');
    if (!mounted) return;
    setState(() {
      _language = ProjectMembersLanguage.values.firstWhere(
        (language) => language.name == rawValue,
        orElse: () => ProjectMembersLanguage.vietnamese,
      );
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _inviteEmailController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _visibleMembers {
    final keyword = _query.toLowerCase();
    final filtered = _members.where((member) {
      final name = member['name'].toString().toLowerCase();
      final email = member['email'].toString().toLowerCase();
      return keyword.isEmpty ||
          name.contains(keyword) ||
          email.contains(keyword);
    }).toList();

    filtered.sort((a, b) {
      final roleCompare = _roleRank(
        a['project_role_id'] ?? a['role'],
      ).compareTo(_roleRank(b['project_role_id'] ?? b['role']));
      if (roleCompare != 0) return roleCompare;
      final nameCompare = a['name'].toString().compareTo(b['name'].toString());
      return _isAscending ? nameCompare : -nameCompare;
    });

    return filtered;
  }

  bool get _canManageMembers {
    final currentUserId = widget.project?['current_user_id']?.toString();
    final currentUserRole =
        widget.project?['current_user_role'] ??
        widget.project?['project_role_id'] ??
        widget.project?['role_name'] ??
        widget.project?['role'] ??
        widget.project?['project_role'];

    if (_isLeaderRole(currentUserRole)) return true;
    if (currentUserId == null || currentUserId.isEmpty) {
      return _members.any((member) => _isLeaderRole(member['role']));
    }

    return _members.any((member) {
      final memberId = member['id']?.toString();
      return memberId == currentUserId && _isLeaderRole(member['role']);
    });
  }

  bool _isLeaderRole(dynamic role) {
    final value = role.toString().toLowerCase();
    return value == 'trưởng nhóm' ||
        value == 'leader' ||
        value == 'owner' ||
        value == '1';
  }

  bool _isDeputyRole(dynamic role) {
    final value = role.toString().toLowerCase();
    return value == 'phó nhóm' || value == 'deputy leader' || value == '2';
  }

  Future<void> _promoteOrDemoteMember(Map<String, dynamic> member) async {
    final projectId = widget.project?['id']?.toString() ?? '';
    final memberId = member['id']?.toString() ?? '';
    final isDeputy = _isDeputyRole(
      member['project_role_id'] ?? member['role'],
    );
    final nextRoleId = isDeputy ? 3 : 2;

    if (projectId.isEmpty || memberId.isEmpty) {
      _showSnackBar(
        _t('Không tìm thấy dữ liệu thành viên', 'Member data not found', '未找到成员数据'),
        isError: true,
      );
      return;
    }

    try {
      final members = await _projectService.updateProjectMemberRole(
        projectId: projectId,
        memberId: memberId,
        projectRoleId: nextRoleId,
      );
      if (!mounted) return;
      setState(() {
        if (members.isNotEmpty) {
          _members
            ..clear()
            ..addAll(members);
        } else {
          member['role'] = isDeputy ? 'Thành viên' : 'Phó nhóm';
          member['project_role_id'] = nextRoleId;
        }
      });
      _showSnackBar(
        isDeputy
            ? _t('Đã giáng chức thành viên', 'Member demoted', '已降级成员')
            : _t(
                'Đã thăng làm nhóm phó',
                'Member promoted to deputy leader',
                '已提升为副组长',
              ),
      );
    } catch (err) {
      if (!mounted) return;
      _showSnackBar(err.toString(), isError: true);
    }
  }

  Future<void> _removeMember(Map<String, dynamic> member) async {
    final projectId = widget.project?['id']?.toString() ?? '';
    final memberId = member['id']?.toString() ?? '';

    if (projectId.isEmpty || memberId.isEmpty) {
      _showSnackBar(
        _t('Không tìm thấy dữ liệu thành viên', 'Member data not found', '未找到成员数据'),
        isError: true,
      );
      return;
    }

    try {
      final members = await _projectService.deleteProjectMember(
        projectId: projectId,
        memberId: memberId,
      );
      if (!mounted) return;
      setState(() {
        if (members.isNotEmpty) {
          _members
            ..clear()
            ..addAll(members);
        } else {
          _members.removeWhere(
            (item) => item['id']?.toString() == memberId,
          );
        }
      });
      _showSnackBar(_t('Đã loại thành viên', 'Member removed', '已移除成员'));
    } catch (err) {
      if (!mounted) return;
      _showSnackBar(err.toString(), isError: true);
    }
  }

  Future<void> _revokeProjectInvitation(
    BuildContext dialogContext,
    String invitationId,
  ) async {
    final projectId = widget.project?['id']?.toString() ?? '';
    if (projectId.isEmpty || invitationId.isEmpty) {
      _showSnackBar(
        _t('Không tìm thấy lời mời', 'Invitation not found', '未找到邀请'),
        isError: true,
      );
      return;
    }

    try {
      await _projectService.deleteSentProjectInvitation(
        projectId: projectId,
        invitationId: invitationId,
      );
      if (!mounted || !dialogContext.mounted) return;
      Navigator.pop(dialogContext);
      _showSnackBar(
        _t('Đã thu hồi lời mời', 'Invitation revoked', '已撤回邀请'),
      );
    } catch (err) {
      if (!mounted) return;
      _showSnackBar(err.toString(), isError: true);
    }
  }

  int _roleRank(dynamic role) {
    switch (role.toString()) {
      case '1':
      case 'Trưởng nhóm':
        return 0;
      case '2':
      case 'Phó nhóm':
        return 1;
      default:
        return 2;
    }
  }

  String _roleLabel(dynamic role) {
    switch (role.toString()) {
      case '1':
      case 'Trưởng nhóm':
        return _t('Trưởng nhóm', 'Leader', '组长');
      case '2':
      case 'Phó nhóm':
        return _t('Phó nhóm', 'Deputy leader', '副组长');
      default:
        return _t('Thành viên', 'Member', '成员');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = appThemeController;
    final members = _visibleMembers;

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            _buildSummaryActions(),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                itemCount: members.length,
                itemBuilder: (context, index) {
                  return _buildMemberCard(index + 1, members[index]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final theme = appThemeController;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
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
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            color: theme.textColor,
          ),
          Expanded(
            child: Text(
              _t(
                'Thành viên tham dự',
                'Project members',
                '项目成员',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
                color: theme.textColor,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildSummaryActions() {
    final theme = appThemeController;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Row(
            children: [
              _buildActionBox(
                icon: Icons.groups_rounded,
                title: _members.length.toString(),
                subtitle: _t('Tổng thành viên', 'Total members', '成员总数'),
                onTap: () {},
                showLargeTitle: true,
              ),
              const SizedBox(width: 8),
              _buildActionBox(
                icon: Icons.person_add_alt_1_rounded,
                title: '',
                subtitle: _t('Thêm thành viên', 'Add member', '添加成员'),
                onTap: () {
                  setState(() {
                    _showInviteInput = !_showInviteInput;
                  });
                },
              ),
              const SizedBox(width: 8),
              _buildActionBox(
                icon: Icons.mark_email_unread_rounded,
                title: '',
                subtitle: _t('Lời mời', 'Invites', '邀请'),
                onTap: _showProjectInvitationsDialog,
              ),
              const SizedBox(width: 8),
              _buildActionBox(
                icon: _isAscending
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                title: '',
                subtitle: _t('Sắp xếp', 'Sort', '排序'),
                onTap: () {
                  setState(() {
                    _isAscending = !_isAscending;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_showInviteInput) ...[
            _buildInviteInput(),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _searchController,
            onChanged: (value) {
              setState(() {
                _query = value;
              });
            },
            style: TextStyle(color: theme.textColor),
            decoration: InputDecoration(
              hintText: _t(
                'Tìm kiếm thành viên',
                'Search members',
                '搜索成员',
              ),
              hintStyle: TextStyle(color: theme.mutedTextColor),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: theme.mutedTextColor,
              ),
              filled: true,
              fillColor: theme.surfaceColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  void _showProjectInvitationsDialog() {
    final theme = appThemeController;
    final projectId = widget.project?['id']?.toString() ?? '';

    if (projectId.isEmpty) {
      _showSnackBar(
        _t('Không tìm thấy ID dự án', 'Project ID not found', '未找到项目 ID'),
        isError: true,
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(sheetContext).size.height * 0.78,
        ),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
        decoration: BoxDecoration(
          color: theme.backgroundColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
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
                    Icons.mark_email_unread_rounded,
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
                  onPressed: () => Navigator.pop(sheetContext),
                  icon: const Icon(Icons.close_rounded),
                  color: theme.mutedTextColor,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _t(
                'Danh sách lời mời đang chờ phản hồi',
                'Pending project invitations',
                '待处理的项目邀请',
              ),
              style: TextStyle(fontSize: 13, color: theme.mutedTextColor),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _projectService.getSentProjectInvitations(
                  projectId: projectId,
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 44),
                        child: CircularProgressIndicator(
                          color: theme.primaryColor,
                        ),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 44),
                        child: Text(
                          snapshot.error.toString(),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: theme.mutedTextColor),
                        ),
                      ),
                    );
                  }

                  final invitations = snapshot.data ?? const [];
                  if (invitations.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 44),
                        child: Text(
                          _t(
                            'Chưa có lời mời nào',
                            'No invitations yet',
                            '暂无邀请',
                          ),
                          style: TextStyle(color: theme.mutedTextColor),
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    itemCount: invitations.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      return _buildInvitationCard(
                        sheetContext,
                        invitations[index],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvitationCard(
    BuildContext dialogContext,
    Map<String, dynamic> invitation,
  ) {
    final theme = appThemeController;
    final invitationId = invitation['id']?.toString() ?? '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.mutedTextColor.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.mail_outline_rounded,
              color: Color(0xFFF59E0B),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  invitation['invitee_name']?.toString().trim().isNotEmpty ==
                          true
                      ? invitation['invitee_name'].toString()
                      : invitation['invitee_email']?.toString() ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: theme.textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  invitation['invitee_email']?.toString() ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: theme.mutedTextColor),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildInvitationPill(
                      invitation['role_name']?.toString() ??
                          invitation['status']?.toString() ??
                          '',
                      const Color(0xFFF59E0B),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        invitation['created_at']?.toString() ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.mutedTextColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          TextButton.icon(
            onPressed: () =>
                _revokeProjectInvitation(dialogContext, invitationId),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFEF4444),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            icon: const Icon(Icons.undo_rounded, size: 18),
            label: Text(
              _t('Thu hồi', 'Revoke', '撤回'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvitationPill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildInviteInput() {
    final theme = appThemeController;
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _inviteEmailController,
            enabled: !_isSendingInvite,
            keyboardType: TextInputType.emailAddress,
            style: TextStyle(color: theme.textColor),
            decoration: InputDecoration(
              hintText: _t('Email thành viên', 'Member email', '成员邮箱'),
              hintStyle: TextStyle(color: theme.mutedTextColor),
              prefixIcon: Icon(
                Icons.alternate_email_rounded,
                color: theme.primaryColor,
              ),
              filled: true,
              fillColor: theme.surfaceColor,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: theme.mutedTextColor.withValues(alpha: 0.14),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: theme.mutedTextColor.withValues(alpha: 0.14),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: theme.primaryColor, width: 1.4),
              ),
            ),
            onSubmitted: (_) => _sendInviteFromInput(),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 54,
          height: 54,
          child: ElevatedButton(
            onPressed: _isSendingInvite ? null : _sendInviteFromInput,
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.primaryColor,
              foregroundColor: Colors.white,
              disabledBackgroundColor:
                  theme.primaryColor.withValues(alpha: 0.45),
              elevation: 0,
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _isSendingInvite
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send_rounded, size: 22),
          ),
        ),
      ],
    );
  }

  Future<void> _sendInviteFromInput() async {
    final projectId = widget.project?['id']?.toString() ?? '';
    final email = _inviteEmailController.text.trim();

    if (projectId.isEmpty || email.isEmpty) {
      _showSnackBar(
        projectId.isEmpty
            ? _t('Không tìm thấy ID dự án', 'Project ID not found', '未找到项目 ID')
            : _t(
                'Vui lòng nhập email thành viên',
                'Please enter a member email',
                '请输入成员邮箱',
              ),
        isError: true,
      );
      return;
    }

    setState(() {
      _isSendingInvite = true;
    });

    try {
      await _projectService.sendProjectInvitation(
        projectId: projectId,
        email: email,
      );
      if (!mounted) return;
      setState(() {
        _isSendingInvite = false;
        _showInviteInput = false;
      });
      _inviteEmailController.clear();
      _showSnackBar(
        _t(
          'Đã gửi lời mời thành công',
          'Invitation sent successfully',
          '邀请已成功发送',
        ),
      );
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _isSendingInvite = false;
      });
      _showSnackBar(err.toString(), isError: true);
    }
  }

  Widget _buildActionBox({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool showLargeTitle = false,
  }) {
    final theme = appThemeController;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          height: 78,
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
              if (title.isNotEmpty)
                Text(
                  title,
                  style: TextStyle(
                    fontSize: showLargeTitle ? 22 : 16,
                    fontWeight: FontWeight.w800,
                    color: theme.primaryColor,
                  ),
                )
              else
                Icon(icon, color: theme.primaryColor, size: 24),
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

  Widget _buildMemberCard(int order, Map<String, dynamic> member) {
    final theme = appThemeController;
    final color = _roleColor(member['project_role_id'] ?? member['role']);
    final roleValue = member['project_role_id'] ?? member['role'];
    final canShowActions = _canManageMembers && !_isLeaderRole(roleValue);
    final isDeputy = _isDeputyRole(roleValue);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.surfaceColor,
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
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                order.toString(),
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member['name'],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: theme.textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  member['email'],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: theme.mutedTextColor),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _roleLabel(member['project_role_id'] ?? member['role']),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
          if (canShowActions) ...[
            const SizedBox(width: 4),
            PopupMenuButton<String>(
              tooltip: _t('Tùy chọn', 'Options', '选项'),
              icon: Icon(
                Icons.more_vert_rounded,
                color: theme.mutedTextColor,
              ),
              color: theme.surfaceColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              onSelected: (value) {
                if (value == 'role') {
                  _promoteOrDemoteMember(member);
                } else if (value == 'remove') {
                  _removeMember(member);
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'role',
                  child: Row(
                    children: [
                      Icon(
                        isDeputy
                            ? Icons.arrow_downward_rounded
                            : Icons.workspace_premium_rounded,
                        color: isDeputy
                            ? const Color(0xFFF59E0B)
                            : theme.primaryColor,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        isDeputy
                            ? _t('Giáng chức', 'Demote', '降级')
                            : _t(
                                'Thăng làm nhóm phó',
                                'Promote to deputy',
                                '提升为副组长',
                              ),
                        style: TextStyle(color: theme.textColor),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'remove',
                  child: Row(
                    children: [
                      const Icon(
                        Icons.person_remove_alt_1_rounded,
                        color: Color(0xFFEF4444),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _t('Loại thành viên', 'Remove member', '移除成员'),
                        style: const TextStyle(color: Color(0xFFEF4444)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
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

  Color _roleColor(dynamic role) {
    switch (role.toString()) {
      case '1':
      case 'Trưởng nhóm':
        return const Color(0xFF6366F1);
      case '2':
      case 'Phó nhóm':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF10B981);
    }
  }
}
