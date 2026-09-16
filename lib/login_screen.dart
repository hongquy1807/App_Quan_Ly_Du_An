import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme_controller.dart';
import 'services/auth_service.dart';
import 'services/push_notification_service.dart';

enum LoginLanguage { vietnamese, english, chinese }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const _languageStorageKey = 'app_language';

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();

  bool _obscurePassword = true;
  bool _rememberMe = false;
  bool _isLoading = false;
  LoginLanguage _language = LoginLanguage.vietnamese;

  @override
  void initState() {
    super.initState();
    _loadLanguage();
    _loadRememberLogin();
  }

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final rawValue = prefs.getString(_languageStorageKey);
    if (!mounted) return;
    setState(() {
      _language = LoginLanguage.values.firstWhere(
        (language) => language.name == rawValue,
        orElse: () => LoginLanguage.vietnamese,
      );
    });
  }

  String _t(String vi, String en, String zh) {
    switch (_language) {
      case LoginLanguage.vietnamese:
        return vi;
      case LoginLanguage.english:
        return en;
      case LoginLanguage.chinese:
        return zh;
    }
  }

  Future<void> _loadRememberLogin() async {
    final rememberLogin = await AuthService.getRememberLogin();
    if (!mounted) return;
    setState(() {
      _rememberMe = rememberLogin;
    });
  }

  Color get _fieldColor {
    if (appThemeController.isDark) return const Color(0xFF1F2937);
    if (appThemeController.mode == AppThemeMode.pink) {
      return const Color(0xFFFFFBFD);
    }
    return const Color(0xFFF9FAFB);
  }

  Color get _borderColor {
    if (appThemeController.isDark) return const Color(0xFF374151);
    if (appThemeController.mode == AppThemeMode.pink) {
      return const Color(0xFFFBCFE8);
    }
    return const Color(0xFFE5E7EB);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _authService.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        rememberLogin: _rememberMe,
      );
      await PushNotificationService.instance.registerCurrentDevice();

      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              'Đăng nhập thành công!',
              'Login successful!',
              '登录成功！',
            ),
          ),
          backgroundColor: const Color(0xFF10B981),
          duration: const Duration(seconds: 2),
        ),
      );

      Navigator.pushReplacementNamed(context, '/home');
    } on ApiException catch (err) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err.message),
          backgroundColor: const Color(0xFFEF4444),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = appThemeController;

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              _buildBackButton(),
              const SizedBox(height: 30),
              Text(
                _t('Chào mừng trở lại', 'Welcome back', '欢迎回来'),
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: theme.textColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _t(
                  'Đăng nhập để tiếp tục quản lý dự án của bạn',
                  'Sign in to continue managing your projects',
                  '登录以继续管理你的项目',
                ),
                style: TextStyle(fontSize: 14, color: theme.mutedTextColor),
              ),
              const SizedBox(height: 40),
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('Email'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: TextStyle(fontSize: 15, color: theme.textColor),
                      decoration: _inputDecoration(
                        hintText: 'nhap@email.com',
                        prefixIcon: Icons.email_outlined,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return _t(
                            'Vui lòng nhập email',
                            'Please enter your email',
                            '请输入邮箱',
                          );
                        }
                        if (!RegExp(
                          r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                        ).hasMatch(value)) {
                          return _t(
                            'Email không hợp lệ',
                            'Invalid email address',
                            '邮箱格式无效',
                          );
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    _buildLabel(_t('Mật khẩu', 'Password', '密码')),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      style: TextStyle(fontSize: 15, color: theme.textColor),
                      decoration: _inputDecoration(
                        hintText: '••••••••',
                        prefixIcon: Icons.lock_outlined,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: theme.mutedTextColor,
                            size: 22,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return _t(
                            'Vui lòng nhập mật khẩu',
                            'Please enter your password',
                            '请输入密码',
                          );
                        }
                        if (value.length < 6) {
                          return _t(
                            'Mật khẩu phải có ít nhất 6 ký tự',
                            'Password must be at least 6 characters',
                            '密码至少需要 6 个字符',
                          );
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: Checkbox(
                                value: _rememberMe,
                                onChanged: (value) {
                                  setState(() {
                                    _rememberMe = value ?? false;
                                  });
                                },
                                activeColor: theme.primaryColor,
                                checkColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _t(
                                'Ghi nhớ đăng nhập',
                                'Remember me',
                                '记住登录',
                              ),
                              style: TextStyle(
                                fontSize: 13,
                                color: theme.mutedTextColor,
                              ),
                            ),
                          ],
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.pushNamed(context, '/forgot-password');
                          },
                          child: Text(
                            _t(
                              'Quên mật khẩu?',
                              'Forgot password?',
                              '忘记密码？',
                            ),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: theme.primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          disabledBackgroundColor: theme.primaryColor
                              .withValues(alpha: 0.6),
                        ),
                        child: _isLoading
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    _t(
                                      'Đang đăng nhập...',
                                      'Signing in...',
                                      '正在登录...',
                                    ),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _t('Đăng nhập', 'Sign in', '登录'),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 20,
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildDivider(
                      _t(
                        'HOẶC ĐĂNG NHẬP VỚI',
                        'OR SIGN IN WITH',
                        '或使用以下方式登录',
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildSocialButton(
                          icon: Icons.g_mobiledata,
                          color: const Color(0xFFEA4335),
                          onTap: () {},
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _t(
                            'Chưa có tài khoản? ',
                            'No account yet? ',
                            '还没有账号？',
                          ),
                          style: TextStyle(
                            fontSize: 14,
                            color: theme.mutedTextColor,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.pushNamed(context, '/register');
                          },
                          child: Text(
                            _t('Đăng ký ngay', 'Register now', '立即注册'),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: theme.primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBackButton() {
    final theme = appThemeController;
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: theme.surfaceColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.arrow_back_ios_new_rounded,
          size: 20,
          color: theme.textColor,
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: appThemeController.textColor,
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    final theme = appThemeController;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: _borderColor, width: 1.5),
    );

    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: theme.mutedTextColor, fontSize: 14),
      prefixIcon: Icon(prefixIcon, color: theme.mutedTextColor, size: 22),
      suffixIcon: suffixIcon,
      border: border,
      enabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: theme.primaryColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
      ),
      filled: true,
      fillColor: _fieldColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  Widget _buildDivider(String text) {
    final theme = appThemeController;
    return Row(
      children: [
        Expanded(child: Divider(color: _borderColor, thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            text,
            style: TextStyle(
              color: theme.mutedTextColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(child: Divider(color: _borderColor, thickness: 1)),
      ],
    );
  }

  Widget _buildSocialButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: _fieldColor,
          shape: BoxShape.circle,
          border: Border.all(color: _borderColor, width: 1.5),
        ),
        child: Icon(icon, size: 30, color: color),
      ),
    );
  }
}
