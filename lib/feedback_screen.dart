import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme_controller.dart';
import 'services/auth_service.dart';
import 'services/feedback_service.dart';

enum FeedbackLanguage { vietnamese, english, chinese }

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  static const _languageStorageKey = 'app_language';

  final FeedbackService _feedbackService = FeedbackService();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  String? _selectedAttachmentType;
  FeedbackLanguage _language = FeedbackLanguage.vietnamese;
  bool _isSubmitting = false;

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
      _language = FeedbackLanguage.values.firstWhere(
        (language) => language.name == rawValue,
        orElse: () => FeedbackLanguage.vietnamese,
      );
    });
  }

  String _t(String vi, String en, String zh) {
    switch (_language) {
      case FeedbackLanguage.vietnamese:
        return vi;
      case FeedbackLanguage.english:
        return en;
      case FeedbackLanguage.chinese:
        return zh;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
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
          _t('Hòm thư góp ý', 'Feedback inbox', '反馈信箱'),
          style: TextStyle(fontWeight: FontWeight.w700, color: theme.textColor),
        ),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          _buildLabel(_t('Tiêu đề góp ý', 'Feedback title', '反馈标题')),
          const SizedBox(height: 8),
          TextField(
            controller: _titleController,
            style: TextStyle(color: theme.textColor),
            decoration: _inputDecoration(
              _t('Nhập tiêu đề góp ý', 'Enter feedback title', '请输入反馈标题'),
            ),
          ),
          const SizedBox(height: 20),
          _buildLabel(_t('Nội dung góp ý', 'Feedback content', '反馈内容')),
          const SizedBox(height: 8),
          TextField(
            controller: _contentController,
            maxLines: 7,
            style: TextStyle(color: theme.textColor),
            decoration: _inputDecoration(
              _t('Nhập nội dung góp ý', 'Enter feedback content', '请输入反馈内容'),
            ),
          ),
          const SizedBox(height: 20),
          _buildLabel(_t('File đính kèm', 'Attachment', '附件')),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildAttachmentButton(
                  icon: Icons.image_rounded,
                  type: 'image',
                  label: _t('Ảnh', 'Image', '图片'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildAttachmentButton(
                  icon: Icons.videocam_rounded,
                  type: 'video',
                  label: _t('Video', 'Video', '视频'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildAttachmentButton(
                  icon: Icons.folder_rounded,
                  type: 'document',
                  label: _t('Tài liệu', 'Document', '文档'),
                ),
              ),
            ],
          ),
          if (_selectedAttachmentType != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.surfaceColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.mutedTextColor.withValues(alpha: 0.18),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.attach_file_rounded, color: theme.primaryColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _t(
                        'Đã chọn loại file: ${_attachmentLabel(_selectedAttachmentType!)}',
                        'Selected file type: ${_attachmentLabel(_selectedAttachmentType!)}',
                        '已选择文件类型：${_attachmentLabel(_selectedAttachmentType!)}',
                      ),
                      style: TextStyle(
                        color: theme.textColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _selectedAttachmentType = null;
                      });
                    },
                    icon: const Icon(Icons.close_rounded),
                    color: theme.mutedTextColor,
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 28),
          SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitFeedback,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                _t('Gửi phản hồi', 'Send feedback', '发送反馈'),
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _attachmentLabel(String type) {
    switch (type) {
      case 'image':
        return _t('Ảnh', 'Image', '图片');
      case 'video':
        return _t('Video', 'Video', '视频');
      case 'document':
        return _t('Tài liệu', 'Document', '文档');
      default:
        return type;
    }
  }

  Widget _buildLabel(String text) {
    final theme = appThemeController;
    return Text(
      text,
      style: TextStyle(
        color: theme.textColor,
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  InputDecoration _inputDecoration(String hintText) {
    final theme = appThemeController;
    final borderColor = theme.mutedTextColor.withValues(alpha: 0.18);
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: theme.mutedTextColor, fontSize: 14),
      filled: true,
      fillColor: theme.surfaceColor,
      contentPadding: const EdgeInsets.all(14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: theme.primaryColor, width: 1.5),
      ),
    );
  }

  Widget _buildAttachmentButton({
    required IconData icon,
    required String type,
    required String label,
  }) {
    final theme = appThemeController;
    final selected = _selectedAttachmentType == type;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        setState(() {
          _selectedAttachmentType = type;
        });
      },
      child: Container(
        height: 78,
        decoration: BoxDecoration(
          color: selected
              ? theme.primaryColor.withValues(alpha: 0.1)
              : theme.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? theme.primaryColor
                : theme.mutedTextColor.withValues(alpha: 0.18),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: theme.primaryColor, size: 26),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: theme.textColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitFeedback() async {
    if (_titleController.text.trim().isEmpty ||
        _contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              'Vui lòng nhập tiêu đề và nội dung góp ý',
              'Please enter a title and feedback content',
              '请输入反馈标题和内容',
            ),
          ),
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await _feedbackService.submitFeedback(
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
      );
    } on ApiException catch (err) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err.message)),
      );
      return;
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể gửi phản hồi.')),
      );
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _t(
            'Cảm ơn bạn đã gửi phản hồi!',
            'Thank you for sending feedback!',
            '感谢你的反馈！',
          ),
        ),
        backgroundColor: const Color(0xFF10B981),
      ),
    );
    Navigator.pop(context, true);
  }
}
