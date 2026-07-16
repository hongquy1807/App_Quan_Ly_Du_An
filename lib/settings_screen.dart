import 'package:flutter/material.dart';

enum AppThemeMode { light, dark, pink }

enum AppLanguage { vietnamese, english, chinese }

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  AppThemeMode _themeMode = AppThemeMode.light;
  AppLanguage _language = AppLanguage.vietnamese;
  bool _notificationsEnabled = true;
  bool _showChangePasswordPanel = false;
  bool _showCurrentPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1F2937),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Cài đặt ứng dụng',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          _buildSectionTitle('Giao diện'),
          _buildThemeOption(
            icon: Icons.light_mode_rounded,
            title: 'Sáng',
            value: AppThemeMode.light,
          ),
          _buildThemeOption(
            icon: Icons.dark_mode_rounded,
            title: 'Tối',
            value: AppThemeMode.dark,
          ),
          _buildThemeOption(
            icon: Icons.favorite_rounded,
            title: 'Hồng',
            value: AppThemeMode.pink,
          ),
          const SizedBox(height: 12),
          _buildSectionTitle('Ngôn ngữ'),
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
          _buildSectionTitle('Thông báo'),
          Container(
            color: Colors.white,
            child: SwitchListTile(
              value: _notificationsEnabled,
              onChanged: (value) {
                setState(() {
                  _notificationsEnabled = value;
                });
              },
              secondary: const Icon(
                Icons.notifications_rounded,
                color: Color(0xFF6366F1),
              ),
              title: const Text(
                'Thông báo',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1F2937),
                ),
              ),
              subtitle: const Text('Tắt hoặc mở thông báo của ứng dụng'),
              activeColor: const Color(0xFF6366F1),
            ),
          ),
          const SizedBox(height: 12),
          _buildSectionTitle('Tài khoản'),
          _buildAccountAction(
            icon: Icons.lock_reset_rounded,
            title: 'Đổi mật khẩu',
            subtitle: 'Cập nhật mật khẩu đăng nhập',
            color: const Color(0xFF6366F1),
            onTap: () {
              setState(() {
                _showChangePasswordPanel = !_showChangePasswordPanel;
              });
            },
          ),
          if (_showChangePasswordPanel) _buildChangePasswordPanel(),
          _buildAccountAction(
            icon: Icons.delete_outline_rounded,
            title: 'Xóa tài khoản',
            subtitle: 'Xóa vĩnh viễn tài khoản của bạn',
            color: const Color(0xFFEF4444),
            onTap: _showDeleteAccountDialog,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      color: const Color(0xFFF1F5F9),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF6366F1),
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
      onChanged: (newValue) {
        setState(() {
          _language = newValue;
        });
      },
    );
  }

  Widget _buildRadioTile<T>({
    required IconData icon,
    required String title,
    required T value,
    required T groupValue,
    required ValueChanged<T> onChanged,
  }) {
    return Container(
      color: Colors.white,
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF6366F1)),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1F2937),
          ),
        ),
        trailing: Radio<T>(
          value: value,
          groupValue: groupValue,
          onChanged: (newValue) {
            if (newValue == null) return;
            onChanged(newValue);
          },
          activeColor: const Color(0xFF6366F1),
        ),
        selected: groupValue == value,
        onTap: () => onChanged(value),
      ),
    );
  }

  Widget _buildAccountAction({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      color: Colors.white,
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: color == const Color(0xFFEF4444)
                ? const Color(0xFFEF4444)
                : const Color(0xFF1F2937),
          ),
        ),
        subtitle: Text(subtitle),
        trailing: Icon(
          _showChangePasswordPanel && title == 'Đổi mật khẩu'
              ? Icons.expand_less_rounded
              : Icons.chevron_right_rounded,
          color: const Color(0xFF9CA3AF),
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildChangePasswordPanel() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 10, 20, 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
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
          const Text(
            'Đổi mật khẩu',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 16),
          _buildPasswordField(
            controller: _currentPasswordController,
            hintText: 'Mật khẩu hiện tại',
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
            hintText: 'Mật khẩu mới',
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
            hintText: 'Nhập lại mật khẩu mới',
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
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Đổi mật khẩu',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
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
    return TextField(
      controller: controller,
      obscureText: !visible,
      decoration: InputDecoration(
        hintText: hintText,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
        ),
        suffixIcon: IconButton(
          onPressed: onToggle,
          icon: Icon(
            visible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }

  void _handleChangePassword() {
    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mật khẩu mới không khớp')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã đổi mật khẩu thành công'),
        backgroundColor: Color(0xFF10B981),
      ),
    );
    _currentPasswordController.clear();
    _newPasswordController.clear();
    _confirmPasswordController.clear();
    setState(() {
      _showChangePasswordPanel = false;
    });
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa tài khoản'),
        content: const Text(
          'Bạn có chắc chắn muốn xóa tài khoản? Hành động này không thể hoàn tác.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Chức năng xóa tài khoản đang được phát triển'),
                  backgroundColor: Color(0xFFEF4444),
                ),
              );
            },
            child: const Text(
              'Xóa tài khoản',
              style: TextStyle(color: Color(0xFFEF4444)),
            ),
          ),
        ],
      ),
    );
  }
}
