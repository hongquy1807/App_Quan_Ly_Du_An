import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_theme_controller.dart';
import 'services/auth_service.dart';

class RegisterOtpScreen extends StatefulWidget {
  const RegisterOtpScreen({super.key, required this.email});

  final String email;

  @override
  State<RegisterOtpScreen> createState() => _RegisterOtpScreenState();
}

class _RegisterOtpScreenState extends State<RegisterOtpScreen> {
  final _otpController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(otp)) {
      _showMessage('Vui lòng nhập mã OTP gồm 6 chữ số.', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _authService.verifyRegisterOtp(email: widget.email, otp: otp);
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showMessage('Đăng ký thành công. Vui lòng đăng nhập.');
      Navigator.popUntil(context, ModalRoute.withName('/login'));
    } on ApiException catch (err) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showMessage(err.message, isError: true);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? const Color(0xFFEF4444) : const Color(0xFF10B981),
      ),
    );
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
              GestureDetector(
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
              ),
              const SizedBox(height: 42),
              Text(
                'Xác thực email',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: theme.textColor,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Nhập mã OTP đã được gửi đến ${widget.email}',
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: theme.mutedTextColor,
                ),
              ),
              const SizedBox(height: 34),
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                textAlign: TextAlign.center,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 10,
                  color: theme.textColor,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '000000',
                  hintStyle: TextStyle(
                    color: theme.mutedTextColor.withValues(alpha: 0.45),
                    letterSpacing: 10,
                  ),
                  filled: true,
                  fillColor: theme.isDark
                      ? const Color(0xFF1F2937)
                      : const Color(0xFFF9FAFB),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide(
                      color: theme.isDark
                          ? const Color(0xFF374151)
                          : const Color(0xFFE5E7EB),
                      width: 1.5,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide(
                      color: theme.isDark
                          ? const Color(0xFF374151)
                          : const Color(0xFFE5E7EB),
                      width: 1.5,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide:
                        BorderSide(color: theme.primaryColor, width: 2),
                  ),
                ),
                onSubmitted: (_) => _isLoading ? null : _verifyOtp(),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _verifyOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Xác thực OTP',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 18),
              Center(
                child: Text(
                  'Mã OTP có hiệu lực trong 5 phút.',
                  style: TextStyle(fontSize: 13, color: theme.mutedTextColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
