import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme_controller.dart';
import 'services/friend_service.dart';
import 'services/project_service.dart';

enum CreateProjectLanguage { vietnamese, english, chinese }

class CreateProjectScreen extends StatefulWidget {
  const CreateProjectScreen({super.key});

  @override
  State<CreateProjectScreen> createState() => _CreateProjectScreenState();
}

class _CreateProjectScreenState extends State<CreateProjectScreen> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _memberEmailController = TextEditingController();
  final ProjectService _projectService = ProjectService();
  final FriendService _friendService = FriendService();
  CreateProjectLanguage _language = CreateProjectLanguage.vietnamese;
  DateTime? _deadline;
  int _selectedColorIndex = 0;
  bool _isSubmitting = false;
  bool _isLoadingFriends = false;
  String? _friendError;
  final List<String> _memberEmails = [];
  List<Map<String, dynamic>> _friends = [];

  final List<Color> _colors = const [
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
    _loadFriends();
  }

  String _t(String vi, String en, String zh) {
    switch (_language) {
      case CreateProjectLanguage.vietnamese:
        return vi;
      case CreateProjectLanguage.english:
        return en;
      case CreateProjectLanguage.chinese:
        return zh;
    }
  }

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final rawValue = prefs.getString('app_language');
    if (!mounted) return;
    setState(() {
      _language = CreateProjectLanguage.values.firstWhere(
        (language) => language.name == rawValue,
        orElse: () => CreateProjectLanguage.vietnamese,
      );
    });
  }

  Future<void> _loadFriends() async {
    setState(() {
      _isLoadingFriends = true;
      _friendError = null;
    });

    try {
      final data = await _friendService.getFriends();
      final friends = data['friends'];
      if (!mounted) return;
      setState(() {
        _friends = friends is List
            ? friends
                .whereType<Map>()
                .map((friend) => Map<String, dynamic>.from(friend))
                .toList()
            : [];
        _isLoadingFriends = false;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _friends = [];
        _friendError = err.toString();
        _isLoadingFriends = false;
      });
    }
  }

  String _colorToHex(Color color) {
    final value = color.toARGB32() & 0xFFFFFF;
    return '#${value.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  Future<void> _saveProjectColor(String projectId) async {
    if (projectId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'project_color_$projectId',
      _colorToHex(_colors[_selectedColorIndex]),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _memberEmailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = appThemeController;
    final color = _colors[_selectedColorIndex];

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTextField(
                      label: _t('Tên dự án', 'Project name', '项目名称'),
                      hintText: _t(
                        'Nhập tên dự án',
                        'Enter project name',
                        '请输入项目名称',
                      ),
                      controller: _nameController,
                      icon: Icons.folder_rounded,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: _t('Mô tả', 'Description', '描述'),
                      hintText: _t(
                        'Nhập mô tả dự án',
                        'Enter project description',
                        '请输入项目描述',
                      ),
                      controller: _descriptionController,
                      icon: Icons.notes_rounded,
                      maxLines: 4,
                    ),
                    const SizedBox(height: 16),
                    _buildDeadlinePicker(),
                    const SizedBox(height: 16),
                    _buildColorPicker(),
                    const SizedBox(height: 16),
                    _buildMemberSection(),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _isSubmitting ? null : _submitProject,
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.add_rounded),
                        label: Text(_t('Tạo dự án', 'Create project', '创建项目')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: color,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
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
              _t('Tạo dự án', 'Create project', '创建项目'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
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

  Widget _buildTextField({
    required String label,
    required String hintText,
    required TextEditingController controller,
    required IconData icon,
    int maxLines = 1,
  }) {
    final theme = appThemeController;
    return _buildSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionLabel(label, icon),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            maxLines: maxLines,
            style: TextStyle(color: theme.textColor),
            decoration: _inputDecoration(hintText),
          ),
        ],
      ),
    );
  }

  Widget _buildDeadlinePicker() {
    final theme = appThemeController;
    return _buildSectionCard(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _pickDeadline,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionLabel(
              _t(
                'Hạn hoàn thành dự án',
                'Project deadline',
                '项目截止日期',
              ),
              Icons.event_rounded,
            ),
            const SizedBox(height: 10),
            Text(
              _deadline == null
                  ? _t('Chọn ngày', 'Choose date', '选择日期')
                  : _formatDate(_deadline!),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _deadline == null ? theme.mutedTextColor : theme.textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorPicker() {
    final theme = appThemeController;
    return _buildSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionLabel(_t('Màu dự án', 'Project color', '项目颜色'), Icons.palette_rounded),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: List.generate(_colors.length, (index) {
                final selected = _selectedColorIndex == index;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedColorIndex = index;
                    });
                  },
                  child: Container(
                    width: 42,
                    height: 42,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: _colors[index],
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? theme.textColor : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: selected
                        ? const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 22,
                          )
                        : null,
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberSection() {
    final theme = appThemeController;
    return _buildSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionLabel(_t('Thành viên', 'Members', '成员'), Icons.group_add_rounded),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _memberEmailController,
                  keyboardType: TextInputType.emailAddress,
                  style: TextStyle(color: theme.textColor),
                  decoration: _inputDecoration(
                    _t(
                      'Nhập email thành viên',
                      'Enter member email',
                      '请输入成员邮箱',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _addMemberEmail,
                icon: const Icon(Icons.add_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: _colors[_selectedColorIndex],
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton.icon(
              onPressed: _showFriendPicker,
              icon: const Icon(Icons.people_alt_rounded),
              label: Text(_t('Mời bạn bè', 'Invite friends', '邀请好友')),
              style: OutlinedButton.styleFrom(
                foregroundColor: _colors[_selectedColorIndex],
                side: BorderSide(
                  color: _colors[_selectedColorIndex].withValues(alpha: 0.45),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          ..._memberEmails.asMap().entries.map((entry) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: theme.backgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.mutedTextColor.withValues(alpha: 0.18),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.person_outline_rounded,
                    color: theme.primaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      entry.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, color: theme.textColor),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _removeMemberEmail(entry.key),
                    icon: const Icon(Icons.close_rounded),
                    color: const Color(0xFFEF4444),
                    iconSize: 20,
                    visualDensity: VisualDensity.compact,
                    tooltip: _t('Xóa thành viên', 'Remove member', '删除成员'),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSectionCard({required Widget child}) {
    final theme = appThemeController;
    return Container(
      width: double.infinity,
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
      child: child,
    );
  }

  Widget _buildSectionLabel(String label, IconData icon) {
    final theme = appThemeController;
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.primaryColor),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: theme.textColor,
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String hintText) {
    final theme = appThemeController;
    final borderColor = theme.mutedTextColor.withValues(alpha: 0.18);
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: theme.mutedTextColor, fontSize: 14),
      filled: true,
      fillColor: theme.backgroundColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: _colors[_selectedColorIndex],
          width: 1.5,
        ),
      ),
    );
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      builder: (context, child) {
        return Theme(
          data: appThemeController.themeData,
          child: child!,
        );
      },
    );

    if (picked == null) return;
    setState(() {
      _deadline = picked;
    });
  }

  void _showFriendPicker() {
    final theme = appThemeController;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.72,
              ),
              padding: EdgeInsets.fromLTRB(18, 18, 18, 18 + bottomPadding),
              decoration: BoxDecoration(
                color: theme.surfaceColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
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
                          color: _colors[_selectedColorIndex]
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.people_alt_rounded,
                          color: _colors[_selectedColorIndex],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _t('Mời bạn bè', 'Invite friends', '邀请好友'),
                          style: TextStyle(
                            color: theme.textColor,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(
                          Icons.close_rounded,
                          color: theme.mutedTextColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (_isLoadingFriends)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 48),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: _colors[_selectedColorIndex],
                        ),
                      ),
                    )
                  else if (_friendError != null)
                    _buildFriendPickerMessage(
                      icon: Icons.error_outline_rounded,
                      message: _friendError!,
                      actionLabel: _t('Thử lại', 'Retry', '重试'),
                      onAction: () {
                        _loadFriends().then((_) {
                          if (mounted) setSheetState(() {});
                        });
                      },
                    )
                  else if (_friends.isEmpty)
                    _buildFriendPickerMessage(
                      icon: Icons.people_outline_rounded,
                      message: _t(
                        'Bạn chưa có bạn bè để mời',
                        'No friends to invite',
                        '暂无可邀请好友',
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const BouncingScrollPhysics(),
                        itemCount: _friends.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final friend = _friends[index];
                          final name = friend['name']?.toString() ?? '';
                          final email = friend['email']?.toString() ?? '';
                          final selected = _memberEmails.any(
                            (item) => item.toLowerCase() == email.toLowerCase(),
                          );
                          return _buildFriendInviteTile(
                            name: name,
                            email: email,
                            selected: selected,
                            onTap: () {
                              if (email.isEmpty) return;
                              setState(() {
                                if (selected) {
                                  _memberEmails.removeWhere(
                                    (item) =>
                                        item.toLowerCase() ==
                                        email.toLowerCase(),
                                  );
                                } else {
                                  _memberEmails.add(email);
                                }
                              });
                              setSheetState(() {});
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFriendPickerMessage({
    required IconData icon,
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final theme = appThemeController;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Center(
        child: Column(
          children: [
            Icon(
              icon,
              color: theme.mutedTextColor.withValues(alpha: 0.65),
              size: 52,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.textColor,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(actionLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFriendInviteTile({
    required String name,
    required String email,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final theme = appThemeController;
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.backgroundColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? _colors[_selectedColorIndex]
                : theme.mutedTextColor.withValues(alpha: 0.14),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _colors[_selectedColorIndex].withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  initial,
                  style: TextStyle(
                    color: _colors[_selectedColorIndex],
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
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
                    name.isEmpty ? email : name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: theme.textColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: theme.mutedTextColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.add_circle_outline_rounded,
              color:
                  selected ? _colors[_selectedColorIndex] : theme.mutedTextColor,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitProject() async {
    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              'Vui lòng nhập tên dự án',
              'Please enter project name',
              '请输入项目名称',
            ),
          ),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final result = await _projectService.createProject(
        name: name,
        description: description.isEmpty ? null : description,
        deadline: _deadline,
        memberEmails: _memberEmails,
      );
      final createdProject = result['project'];
      await _saveProjectColor(
        createdProject is Map
            ? createdProject['id']?.toString() ?? ''
            : result['id']?.toString() ?? '',
      );
      final missingMembers = result['missing_members'];
      final hasMissingMembers = missingMembers is List && missingMembers.isNotEmpty;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            hasMissingMembers
                ? _t(
                    'Tạo dự án thành công, một số email chưa có tài khoản',
                    'Project created, some emails do not have accounts yet',
                    '项目已创建，部分邮箱尚未注册账号',
                  )
                : _t(
                    'Tạo dự án thành công',
                    'Project created successfully',
                    '项目创建成功',
                  ),
          ),
          backgroundColor: hasMissingMembers
              ? const Color(0xFFF59E0B)
              : const Color(0xFF10B981),
        ),
      );
      Navigator.pop(context, true);
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err.toString()),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _addMemberEmail() {
    final email = _memberEmailController.text.trim();
    if (email.isEmpty) return;
    final exists = _memberEmails.any(
      (item) => item.toLowerCase() == email.toLowerCase(),
    );
    if (exists) {
      _memberEmailController.clear();
      return;
    }
    setState(() {
      _memberEmails.add(email);
      _memberEmailController.clear();
    });
  }

  void _removeMemberEmail(int index) {
    setState(() {
      _memberEmails.removeAt(index);
    });
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
