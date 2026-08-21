import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'app_theme_controller.dart';
import 'services/auth_service.dart';
import 'services/cv_service.dart';
import 'services/profile_service.dart';

class ElectronicCvScreen extends StatefulWidget {
  const ElectronicCvScreen({super.key, required this.userInfo});

  final Map<String, dynamic> userInfo;

  @override
  State<ElectronicCvScreen> createState() => _ElectronicCvScreenState();
}

class _ElectronicCvScreenState extends State<ElectronicCvScreen> {
  final CvService _cvService = CvService();
  final ProfileService _profileService = ProfileService();
  final _nameController = TextEditingController();
  final _titleController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _birthdayController = TextEditingController();
  final _addressController = TextEditingController();
  final _objectiveController = TextEditingController();
  final _educationController = TextEditingController();
  final _skillsController = TextEditingController();
  final _softSkillsController = TextEditingController();
  final _languagesController = TextEditingController();
  final _projectsController = TextEditingController();
  final _certificatesController = TextEditingController();

  bool _previewMode = false;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isExporting = false;
  String? _avatarPath;

  @override
  void initState() {
    super.initState();
    _fillFromProfile(widget.userInfo);
    _loadCv();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _titleController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _birthdayController.dispose();
    _addressController.dispose();
    _objectiveController.dispose();
    _educationController.dispose();
    _skillsController.dispose();
    _softSkillsController.dispose();
    _languagesController.dispose();
    _projectsController.dispose();
    _certificatesController.dispose();
    super.dispose();
  }

  void _fillFromProfile(Map<String, dynamic> profile) {
    _nameController.text = profile['name']?.toString() ?? profile['fullName']?.toString() ?? '';
    _emailController.text = profile['email']?.toString() ?? '';
    _phoneController.text = profile['phone']?.toString() ?? '';
    _birthdayController.text = profile['birthday']?.toString() ?? '';
    _addressController.text = profile['address']?.toString() ?? '';
    _avatarPath = profile['avatar']?.toString();
  }

  Future<void> _loadCv() async {
    setState(() => _isLoading = true);
    try {
      final data = await _cvService.getCv();
      final profile = Map<String, dynamic>.from(data['profile'] as Map? ?? {});
      final cv = Map<String, dynamic>.from(data['cv'] as Map? ?? {});
      if (!mounted) return;
      setState(() {
        _fillFromProfile(profile);
        _titleController.text = cv['title']?.toString() ?? '';
        _objectiveController.text = cv['objective']?.toString() ?? '';
        _educationController.text = cv['education']?.toString() ?? '';
        _skillsController.text = cv['skills']?.toString() ?? '';
        _softSkillsController.text = cv['softSkills']?.toString() ?? '';
        _languagesController.text = cv['languages']?.toString() ?? '';
        _projectsController.text = cv['projects']?.toString() ?? '';
        _certificatesController.text = cv['certificates']?.toString() ?? '';
      });
    } on ApiException catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err.message)));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveCv({bool showMessage = true}) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      await _cvService.saveCv(
        title: _titleController.text,
        objective: _objectiveController.text,
        education: _educationController.text,
        skills: _skillsController.text,
        softSkills: _softSkillsController.text,
        languages: _languagesController.text,
        projects: _projectsController.text,
        certificates: _certificatesController.text,
      );
      if (!mounted || !showMessage) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã lưu CV điện tử.')),
      );
    } on ApiException catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err.message)));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _exportCv(String type) async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    try {
      await _saveCv(showMessage: false);
      final file = await _cvService.downloadCv(type);
      final savedPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Lưu CV Word',
        fileName: file.fileName,
        bytes: file.bytes,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(savedPath == null ? 'Đã hủy lưu CV.' : 'Đã xuất CV.'),
        ),
      );
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err.toString())));
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  String? get _avatarUrl => _profileService.buildAvatarUrl(_avatarPath);

  String get _avatarLetter {
    final name = _nameController.text.trim();
    return name.isNotEmpty ? name[0].toUpperCase() : 'C';
  }

  List<String> _lines(TextEditingController controller) {
    return controller.text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
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
            _buildModeSwitch(theme),
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: theme.primaryColor))
                  : AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: _previewMode ? _buildPreview(theme) : _buildForm(theme),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(AppThemeController theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
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
              'CV điện tử',
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.textColor, fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            onPressed: _isSaving ? null : () => _saveCv(),
            icon: _isSaving
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: theme.primaryColor),
                  )
                : const Icon(Icons.save_rounded),
            color: theme.primaryColor,
          ),
        ],
      ),
    );
  }

  Widget _buildModeSwitch(AppThemeController theme) {
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 16, 18, 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: theme.surfaceColor, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          _buildModeButton(theme, label: 'Nhập thông tin', icon: Icons.edit_note_rounded, selected: !_previewMode, onTap: () => setState(() => _previewMode = false)),
          _buildModeButton(theme, label: 'Xem trước CV', icon: Icons.article_rounded, selected: _previewMode, onTap: () => setState(() => _previewMode = true)),
        ],
      ),
    );
  }

  Widget _buildModeButton(AppThemeController theme, {required String label, required IconData icon, required bool selected, required VoidCallback onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: selected ? theme.primaryColor : Colors.transparent, borderRadius: BorderRadius.circular(13)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: selected ? Colors.white : theme.mutedTextColor),
              const SizedBox(width: 7),
              Flexible(
                child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: selected ? Colors.white : theme.textColor, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForm(AppThemeController theme) {
    return ListView(
      key: const ValueKey('cv_form'),
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
      children: [
        _buildFormSection(theme, title: 'Thông tin cá nhân', icon: Icons.person_rounded, children: [
          _buildInput(theme, _nameController, 'Họ tên', enabled: false),
          _buildInput(theme, _titleController, 'Vị trí / tiêu đề CV'),
          _buildInput(theme, _emailController, 'Email', enabled: false),
          _buildInput(theme, _phoneController, 'Số điện thoại', enabled: false),
          _buildInput(theme, _birthdayController, 'Ngày sinh', enabled: false),
          _buildInput(theme, _addressController, 'Địa chỉ', enabled: false),
        ]),
        _buildFormSection(theme, title: 'Nội dung CV', icon: Icons.description_rounded, children: [
          _buildInput(theme, _objectiveController, 'Mục tiêu nghề nghiệp', maxLines: 4),
          _buildInput(theme, _educationController, 'Học vấn', maxLines: 4),
          _buildInput(theme, _skillsController, 'Kỹ năng chuyên môn', maxLines: 5),
          _buildInput(theme, _softSkillsController, 'Kỹ năng mềm', maxLines: 4),
          _buildInput(theme, _languagesController, 'Ngoại ngữ', maxLines: 3),
          _buildInput(
            theme,
            _projectsController,
            'Dự án / kinh nghiệm',
            maxLines: 7,
            enabled: false,
          ),
          _buildInput(theme, _certificatesController, 'Chứng chỉ / hoạt động / sở thích', maxLines: 4),
        ]),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: _isSaving ? null : () => _saveCv(),
          icon: const Icon(Icons.save_rounded),
          label: const Text('Lưu CV'),
          style: _buttonStyle(theme),
        ),
        const SizedBox(height: 10),
        ElevatedButton.icon(
          onPressed: () => setState(() => _previewMode = true),
          icon: const Icon(Icons.visibility_rounded),
          label: const Text('Xem trước CV'),
          style: _buttonStyle(theme),
        ),
      ],
    );
  }

  Widget _buildFormSection(AppThemeController theme, {required String title, required IconData icon, required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.mutedTextColor.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: theme.primaryColor),
            const SizedBox(width: 8),
            Text(title, style: TextStyle(color: theme.textColor, fontSize: 18, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInput(AppThemeController theme, TextEditingController controller, String label, {int maxLines = 1, bool enabled = true}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        enabled: enabled,
        maxLines: maxLines,
        style: TextStyle(color: theme.textColor),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: theme.mutedTextColor),
          filled: true,
          fillColor: theme.backgroundColor,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: theme.mutedTextColor.withValues(alpha: 0.12)),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: theme.mutedTextColor.withValues(alpha: 0.08)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: theme.primaryColor, width: 1.4),
          ),
        ),
      ),
    );
  }

  Widget _buildPreview(AppThemeController theme) {
    final accent = theme.primaryColor;
    return ListView(
      key: const ValueKey('cv_preview'),
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
      children: [
        Container(
          decoration: BoxDecoration(
            color: theme.surfaceColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: theme.mutedTextColor.withValues(alpha: 0.08)),
          ),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                ),
                child: Column(
                  children: [
                    _buildPreviewAvatar(accent),
                    const SizedBox(height: 14),
                    Text(
                      _nameController.text.trim().isEmpty ? 'Họ tên của bạn' : _nameController.text.trim(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _titleController.text.trim(),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.88), fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildContactGrid(theme),
                    const SizedBox(height: 18),
                    _buildCvSection(theme, 'Mục tiêu nghề nghiệp', [_objectiveController.text]),
                    _buildCvSection(theme, 'Học vấn', _lines(_educationController)),
                    _buildCvSection(theme, 'Kỹ năng chuyên môn', _lines(_skillsController), chipMode: true),
                    _buildCvSection(theme, 'Kỹ năng mềm', _lines(_softSkillsController), chipMode: true),
                    _buildCvSection(theme, 'Ngoại ngữ', _lines(_languagesController), chipMode: true),
                    _buildCvSection(theme, 'Dự án / kinh nghiệm', _lines(_projectsController)),
                    _buildCvSection(theme, 'Chứng chỉ / hoạt động / sở thích', _lines(_certificatesController)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _exportButton(theme, 'Xuất Word', Icons.description_rounded, () => _exportCv('word')),
      ],
    );
  }

  Widget _exportButton(AppThemeController theme, String label, IconData icon, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: _isExporting ? null : onPressed,
      icon: _isExporting ? const SizedBox.shrink() : Icon(icon, size: 18),
      label: Text(label),
      style: _buttonStyle(theme),
    );
  }

  ButtonStyle _buttonStyle(AppThemeController theme) {
    return ElevatedButton.styleFrom(
      backgroundColor: theme.primaryColor,
      foregroundColor: Colors.white,
      elevation: 0,
      padding: const EdgeInsets.symmetric(vertical: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }

  Widget _buildPreviewAvatar(Color accent) {
    final avatarUrl = _avatarUrl;
    return Container(
      width: 92,
      height: 92,
      padding: const EdgeInsets.all(4),
      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      child: CircleAvatar(
        backgroundColor: accent.withValues(alpha: 0.12),
        backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
        child: avatarUrl == null || avatarUrl.isEmpty
            ? Text(_avatarLetter, style: TextStyle(color: accent, fontSize: 36, fontWeight: FontWeight.bold))
            : null,
      ),
    );
  }

  Widget _buildContactGrid(AppThemeController theme) {
    final items = [
      (Icons.email_rounded, _emailController.text),
      (Icons.phone_rounded, _phoneController.text),
      (Icons.cake_rounded, _birthdayController.text),
      (Icons.location_on_rounded, _addressController.text),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.where((item) => item.$2.trim().isNotEmpty).map((item) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(color: theme.backgroundColor, borderRadius: BorderRadius.circular(12)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(item.$1, size: 15, color: theme.primaryColor),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 250),
                child: Text(
                  item.$2,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: theme.textColor, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCvSection(AppThemeController theme, String title, List<String> values, {bool chipMode = false}) {
    final cleaned = values.where((value) => value.trim().isNotEmpty).toList();
    if (cleaned.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(), style: TextStyle(color: theme.primaryColor, fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (chipMode)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: cleaned.map((value) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(color: theme.primaryColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                  child: Text(value, style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.w700, fontSize: 12)),
                );
              }).toList(),
            )
          else
            ...cleaned.map((value) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(value, style: TextStyle(color: theme.textColor, fontSize: 13, height: 1.35)),
              );
            }),
        ],
      ),
    );
  }
}
