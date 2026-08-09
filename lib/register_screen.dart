import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme_controller.dart';
import 'services/auth_service.dart';

enum RegisterLanguage { vietnamese, english, chinese }

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  static const _languageStorageKey = 'app_language';

  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = AuthService();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreeTerms = false;
  bool _isLoading = false;
  RegisterLanguage _language = RegisterLanguage.vietnamese;

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
      _language = RegisterLanguage.values.firstWhere(
        (language) => language.name == rawValue,
        orElse: () => RegisterLanguage.vietnamese,
      );
    });
  }

  String _t(String vi, String en, String zh) {
    switch (_language) {
      case RegisterLanguage.vietnamese:
        return vi;
      case RegisterLanguage.english:
        return en;
      case RegisterLanguage.chinese:
        return zh;
    }
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
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (!_agreeTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              'Vui lòng đồng ý với điều khoản sử dụng',
              'Please agree to the terms of use',
              '请同意使用条款',
            ),
          ),
          backgroundColor: const Color(0xFFEF4444),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _authService.register(
        name: _fullNameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              'Đăng ký thành công! Vui lòng đăng nhập',
              'Registration successful! Please sign in',
              '注册成功！请登录',
            ),
          ),
          backgroundColor: const Color(0xFF10B981),
          duration: const Duration(seconds: 2),
        ),
      );

      Navigator.pop(context);
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
                _t('Tạo tài khoản', 'Create account', '创建账号'),
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: theme.textColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _t(
                  'Đăng ký để bắt đầu quản lý dự án của bạn',
                  'Register to start managing your projects',
                  '注册以开始管理你的项目',
                ),
                style: TextStyle(fontSize: 14, color: theme.mutedTextColor),
              ),
              const SizedBox(height: 32),
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel(_t('Họ và tên', 'Full name', '姓名')),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _fullNameController,
                      textInputAction: TextInputAction.next,
                      style: TextStyle(fontSize: 15, color: theme.textColor),
                      decoration: _inputDecoration(
                        hintText: _t('Nguyễn Văn A', 'John Smith', '张三'),
                        prefixIcon: Icons.person_outline,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return _t(
                            'Vui lòng nhập họ và tên',
                            'Please enter your full name',
                            '请输入姓名',
                          );
                        }
                        if (value.trim().split(' ').length < 2) {
                          return _t(
                            'Vui lòng nhập đầy đủ họ và tên',
                            'Please enter your full name',
                            '请输入完整姓名',
                          );
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    _buildLabel('Email'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
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
                      textInputAction: TextInputAction.next,
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
                        if (!RegExp(r'^(?=.*[A-Za-z])(?=.*\d)').hasMatch(value)) {
                          return _t(
                            'Mật khẩu phải có ít nhất 1 chữ và 1 số',
                            'Password must include at least 1 letter and 1 number',
                            '密码必须包含至少 1 个字母和 1 个数字',
                          );
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    _buildLabel(
                      _t(
                        'Xác nhận mật khẩu',
                        'Confirm password',
                        '确认密码',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      textInputAction: TextInputAction.done,
                      style: TextStyle(fontSize: 15, color: theme.textColor),
                      decoration: _inputDecoration(
                        hintText: '••••••••',
                        prefixIcon: Icons.lock_outline,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: theme.mutedTextColor,
                            size: 22,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscureConfirmPassword =
                                  !_obscureConfirmPassword;
                            });
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return _t(
                            'Vui lòng xác nhận mật khẩu',
                            'Please confirm your password',
                            '请确认密码',
                          );
                        }
                        if (value != _passwordController.text) {
                          return _t(
                            'Mật khẩu không khớp',
                            'Passwords do not match',
                            '两次密码不一致',
                          );
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: Checkbox(
                            value: _agreeTerms,
                            onChanged: (value) {
                              setState(() {
                                _agreeTerms = value ?? false;
                              });
                            },
                            activeColor: theme.primaryColor,
                            checkColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: _buildTermsText()),
                      ],
                    ),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleRegister,
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
                                      'Đang đăng ký...',
                                      'Creating account...',
                                      '正在注册...',
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
                                    _t('Đăng ký', 'Register', '注册'),
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
                    _buildDivider(_t('HOẶC', 'OR', '或者')),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildSocialButton(
                          icon: Icons.g_mobiledata,
                          color: const Color(0xFFEA4335),
                          onTap: () {},
                        ),
                        const SizedBox(width: 16),
                        _buildSocialButton(
                          icon: Icons.facebook,
                          color: const Color(0xFF1877F2),
                          onTap: () {},
                        ),
                        const SizedBox(width: 16),
                        _buildSocialButton(
                          icon: Icons.apple,
                          color: theme.textColor,
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
                            'Đã có tài khoản? ',
                            'Already have an account? ',
                            '已有账号？',
                          ),
                          style: TextStyle(
                            fontSize: 14,
                            color: theme.mutedTextColor,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                          },
                          child: Text(
                            _t('Đăng nhập', 'Sign in', '登录'),
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

  Widget _buildTermsText() {
    final theme = appThemeController;
    return RichText(
      text: TextSpan(
        style: TextStyle(fontSize: 13, color: theme.mutedTextColor),
        children: [
          TextSpan(text: _t('Tôi đồng ý với ', 'I agree to the ', '我同意')),
          TextSpan(
            text: _t('Điều khoản sử dụng', 'Terms of use', '使用条款'),
            style: TextStyle(
              color: theme.primaryColor,
              fontWeight: FontWeight.w600,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      _t(
                        'Mở điều khoản sử dụng',
                        'Open terms of use',
                        '打开使用条款',
                      ),
                    ),
                  ),
                );
              },
          ),
          TextSpan(text: _t(' và ', ' and ', ' 和 ')),
          TextSpan(
            text: _t('Chính sách bảo mật', 'Privacy policy', '隐私政策'),
            style: TextStyle(
              color: theme.primaryColor,
              fontWeight: FontWeight.w600,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      _t(
                        'Mở chính sách bảo mật',
                        'Open privacy policy',
                        '打开隐私政策',
                      ),
                    ),
                  ),
                );
              },
          ),
        ],
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
