import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_language_controller.dart';
import 'app_theme_controller.dart';

enum AppLanguage { vietnamese, english, chinese }

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _languageStorageKey = 'app_language';

  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  AppThemeMode _themeMode = appThemeController.mode;
  AppLanguage _language = AppLanguage.vietnamese;
  bool _notificationsEnabled = true;
  bool _showChangePasswordPanel = false;
  bool _showCurrentPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;

  @override
  void initState() {
    super.initState();
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final rawValue = prefs.getString(_languageStorageKey);
    if (!mounted) return;
    setState(() {
      _language = AppLanguage.values.firstWhere(
        (language) => language.name == rawValue,
        orElse: () => AppLanguage.vietnamese,
      );
    });
  }

  Future<void> _setLanguage(AppLanguage language) async {
    setState(() {
      _language = language;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageStorageKey, language.name);
    await appLanguageController.setMode(
      switch (language) {
        AppLanguage.vietnamese => AppLanguageMode.vietnamese,
        AppLanguage.english => AppLanguageMode.english,
        AppLanguage.chinese => AppLanguageMode.chinese,
      },
    );
  }

  String _t(String vi, String en, String zh) {
    switch (_language) {
      case AppLanguage.vietnamese:
        return vi;
      case AppLanguage.english:
        return en;
      case AppLanguage.chinese:
        return zh;
    }
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = appThemeController;
    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        backgroundColor: theme.surfaceColor,
        foregroundColor: theme.textColor,
        elevation: 0,
        centerTitle: true,
        title: Text(
          _t('Cài đặt ứng dụng', 'App settings', '应用设置'),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          _buildSectionTitle(_t('Giao diện', 'Appearance', '外观')),
          _buildThemeOption(
            icon: Icons.light_mode_rounded,
            title: _t('Sáng', 'Light', '浅色'),
            value: AppThemeMode.light,
          ),
          _buildThemeOption(
            icon: Icons.dark_mode_rounded,
            title: _t('Tối', 'Dark', '深色'),
            value: AppThemeMode.dark,
          ),
          _buildThemeOption(
            icon: Icons.favorite_rounded,
            title: _t('Hồng', 'Pink', '粉色'),
            value: AppThemeMode.pink,
          ),
          const SizedBox(height: 12),
          _buildSectionTitle(_t('Ngôn ngữ', 'Language', '语言')),
          _buildLanguageOption(
            icon: Icons.language_rounded,
            title: 'Tiếng Việt',
            value: AppLanguage.vietnamese,
          ),
          _buildLanguageOption(
            icon: Icons.translate_rounded,
            title: 'English',
            value: AppLanguage.english,
          ),
          _buildLanguageOption(
            icon: Icons.public_rounded,
            title: '中文',
            value: AppLanguage.chinese,
          ),
          const SizedBox(height: 12),
          _buildSectionTitle(_t('Thông báo', 'Notifications', '通知')),
          Container(
            color: theme.surfaceColor,
            child: SwitchListTile(
              value: _notificationsEnabled,
              onChanged: (value) {
                setState(() {
                  _notificationsEnabled = value;
                });
              },
              secondary: Icon(
                Icons.notifications_rounded,
                color: theme.primaryColor,
              ),
              title: Text(
                _t('Thông báo', 'Notifications', '通知'),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: theme.textColor,
                ),
              ),
              subtitle: Text(
                _t(
                  'Tắt hoặc mở thông báo của ứng dụng',
                  'Turn app notifications on or off',
                  '开启或关闭应用通知',
                ),
                style: TextStyle(color: theme.mutedTextColor),
              ),
              activeThumbColor: theme.primaryColor,
            ),
          ),
          const SizedBox(height: 12),
          _buildSectionTitle(_t('Thông tin', 'Information', '信息')),
          _buildInfoAction(
            icon: Icons.info_outline_rounded,
            title: _t('Phiên bản', 'Version', '版本'),
            trailingText: '1.0.0',
            onTap: () {},
          ),
          _buildInfoAction(
            icon: Icons.help_outline_rounded,
            title: _t('Giới thiệu', 'About', '关于'),
            onTap: _showAboutAppDialog,
          ),
          const SizedBox(height: 12),
          _buildSectionTitle(_t('Tài khoản', 'Account', '账户')),
          _buildAccountAction(
            icon: Icons.lock_reset_rounded,
            title: _t('Đổi mật khẩu', 'Change password', '修改密码'),
            subtitle: _t(
              'Cập nhật mật khẩu đăng nhập',
              'Update your sign-in password',
              '更新登录密码',
            ),
            color: theme.primaryColor,
            isExpanded: _showChangePasswordPanel,
            onTap: () {
              setState(() {
                _showChangePasswordPanel = !_showChangePasswordPanel;
              });
            },
          ),
          if (_showChangePasswordPanel) _buildChangePasswordPanel(),
          _buildAccountAction(
            icon: Icons.delete_outline_rounded,
            title: _t('Xóa tài khoản', 'Delete account', '删除账户'),
            subtitle: _t(
              'Xóa vĩnh viễn tài khoản của bạn',
              'Permanently delete your account',
              '永久删除你的账户',
            ),
            color: const Color(0xFFEF4444),
            onTap: _showDeleteAccountDialog,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    final theme = appThemeController;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      color: theme.primaryColor.withValues(alpha: theme.isDark ? 0.14 : 0.08),
      child: Text(
        title,
        style: TextStyle(
          color: theme.primaryColor,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildThemeOption({
    required IconData icon,
    required String title,
    required AppThemeMode value,
  }) {
    return _buildRadioTile<AppThemeMode>(
      icon: icon,
      title: title,
      value: value,
      groupValue: _themeMode,
      onChanged: (newValue) {
        setState(() {
          _themeMode = newValue;
        });
        appThemeController.setMode(newValue);
      },
    );
  }

  Widget _buildLanguageOption({
    required IconData icon,
    required String title,
    required AppLanguage value,
  }) {
    return _buildRadioTile<AppLanguage>(
      icon: icon,
      title: title,
      value: value,
      groupValue: _language,
      onChanged: _setLanguage,
    );
  }

  Widget _buildRadioTile<T>({
    required IconData icon,
    required String title,
    required T value,
    required T groupValue,
    required ValueChanged<T> onChanged,
  }) {
    final theme = appThemeController;
    return Container(
      color: theme.surfaceColor,
      child: ListTile(
        leading: Icon(icon, color: theme.primaryColor),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: theme.textColor,
          ),
        ),
        trailing: _buildSelectionIndicator(groupValue == value),
        selected: groupValue == value,
        onTap: () => onChanged(value),
      ),
    );
  }

  Widget _buildSelectionIndicator(bool selected) {
    final theme = appThemeController;
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? theme.primaryColor : theme.mutedTextColor,
          width: 2,
        ),
      ),
      child: selected
          ? Center(
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.primaryColor,
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildInfoAction({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    String? trailingText,
  }) {
    final theme = appThemeController;
    return Container(
      color: theme.surfaceColor,
      child: ListTile(
        leading: Icon(icon, color: theme.primaryColor),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: theme.textColor,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (trailingText != null)
              Text(
                trailingText,
                style: TextStyle(
                  color: theme.mutedTextColor,
                  fontWeight: FontWeight.w600,
                ),
              )
            else
              Icon(Icons.chevron_right_rounded, color: theme.mutedTextColor),
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildAccountAction({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    bool isExpanded = false,
  }) {
    final theme = appThemeController;
    final isDelete = color == const Color(0xFFEF4444);
    return Container(
      color: theme.surfaceColor,
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDelete ? const Color(0xFFEF4444) : theme.textColor,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: theme.mutedTextColor),
        ),
        trailing: Icon(
          isExpanded ? Icons.expand_less_rounded : Icons.chevron_right_rounded,
          color: theme.mutedTextColor,
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildChangePasswordPanel() {
    final theme = appThemeController;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 10, 20, 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _t('Đổi mật khẩu', 'Change password', '修改密码'),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: theme.textColor,
            ),
          ),
          const SizedBox(height: 16),
          _buildPasswordField(
            controller: _currentPasswordController,
            hintText: _t('Mật khẩu hiện tại', 'Current password', '当前密码'),
            visible: _showCurrentPassword,
            onToggle: () {
              setState(() {
                _showCurrentPassword = !_showCurrentPassword;
              });
            },
          ),
          const SizedBox(height: 12),
          _buildPasswordField(
            controller: _newPasswordController,
            hintText: _t('Mật khẩu mới', 'New password', '新密码'),
            visible: _showNewPassword,
            onToggle: () {
              setState(() {
                _showNewPassword = !_showNewPassword;
              });
            },
          ),
          const SizedBox(height: 12),
          _buildPasswordField(
            controller: _confirmPasswordController,
            hintText: _t(
              'Nhập lại mật khẩu mới',
              'Confirm new password',
              '确认新密码',
            ),
            visible: _showConfirmPassword,
            onToggle: () {
              setState(() {
                _showConfirmPassword = !_showConfirmPassword;
              });
            },
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _handleChangePassword,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                _t('Đổi mật khẩu', 'Change password', '修改密码'),
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String hintText,
    required bool visible,
    required VoidCallback onToggle,
  }) {
    final theme = appThemeController;
    return TextField(
      controller: controller,
      obscureText: !visible,
      style: TextStyle(color: theme.textColor),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: theme.mutedTextColor),
        filled: true,
        fillColor: theme.backgroundColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: theme.mutedTextColor.withValues(alpha: 0.35)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: theme.mutedTextColor.withValues(alpha: 0.35)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: theme.primaryColor, width: 1.5),
        ),
        suffixIcon: IconButton(
          onPressed: onToggle,
          icon: Icon(
            visible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: theme.mutedTextColor,
          ),
        ),
      ),
    );
  }

  void _handleChangePassword() {
    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              'Mật khẩu mới không khớp',
              'New passwords do not match',
              '两次输入的新密码不一致',
            ),
          ),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _t(
            'Đã đổi mật khẩu thành công',
            'Password changed successfully',
            '密码修改成功',
          ),
        ),
        backgroundColor: const Color(0xFF10B981),
      ),
    );
    _currentPasswordController.clear();
    _newPasswordController.clear();
    _confirmPasswordController.clear();
    setState(() {
      _showChangePasswordPanel = false;
    });
  }

  void _showAboutAppDialog() {
    final theme = appThemeController;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: theme.surfaceColor,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.16),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          theme.primaryColor,
                          theme.primaryColor.withValues(alpha: 0.72),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.dashboard_customize_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _t('Thông tin ứng dụng', 'App information', '应用信息'),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: theme.textColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _buildAboutRow(
                _t('Tên ứng dụng', 'App name', '应用名称'),
                _t('App quản lý dự án', 'Project management app', '项目管理应用'),
              ),
              _buildAboutRow(_t('Phiên bản', 'Version', '版本'), '1.0.0'),
              _buildAboutRow(
                _t('Phát triển bởi', 'Developed by', '开发团队'),
                _t(
                  'Nhóm 9 - môn Lập Trình Trên Thiết Bị Di Động - Đại Học Bình Dương',
                  'Group 9 - Mobile Device Programming - Binh Duong University',
                  '第9组 - 移动设备编程课程 - 平阳大学',
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    _t('Đóng', 'Close', '关闭'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAboutRow(String label, String value) {
    final theme = appThemeController;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: theme.mutedTextColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              height: 1.35,
              color: theme.textColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    final theme = appThemeController;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.surfaceColor,
        title: Text(
          _t('Xóa tài khoản', 'Delete account', '删除账户'),
          style: TextStyle(color: theme.textColor),
        ),
        content: Text(
          _t(
            'Bạn có chắc chắn muốn xóa tài khoản? Hành động này không thể hoàn tác.',
            'Are you sure you want to delete your account? This action cannot be undone.',
            '你确定要删除账户吗？此操作无法撤销。',
          ),
          style: TextStyle(color: theme.mutedTextColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_t('Hủy', 'Cancel', '取消')),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    _t(
                      'Chức năng xóa tài khoản đang được phát triển',
                      'Delete account is still in development',
                      '删除账户功能正在开发中',
                    ),
                  ),
                  backgroundColor: const Color(0xFFEF4444),
                ),
              );
            },
            child: Text(
              _t('Xóa tài khoản', 'Delete account', '删除账户'),
              style: const TextStyle(color: Color(0xFFEF4444)),
            ),
          ),
        ],
      ),
    );
  }
}
