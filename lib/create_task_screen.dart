import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme_controller.dart';
import 'services/auth_service.dart';
import 'services/project_service.dart';

enum CreateTaskLanguage { vietnamese, english, chinese }

class CreateTaskScreen extends StatefulWidget {
  const CreateTaskScreen({
    super.key,
    this.project,
    this.members,
    this.initialTask,
    this.isEditing = false,
  });

  final Map<String, dynamic>? project;
  final List<Map<String, dynamic>>? members;
  final Map<String, dynamic>? initialTask;
  final bool isEditing;

  @override
  State<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends State<CreateTaskScreen> {
  final ProjectService _projectService = ProjectService();
  final ImagePicker _imagePicker = ImagePicker();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _subtaskController = TextEditingController();

  CreateTaskLanguage _language = CreateTaskLanguage.vietnamese;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isLoadingOptions = false;
  bool _isSaving = false;

  List<Map<String, dynamic>> _members = [];
  final Set<int> _selectedMemberIds = {};
  final List<String> _subtasks = [];
  final List<Map<String, dynamic>> _attachments = [];

  @override
  void initState() {
    super.initState();
    _members = List<Map<String, dynamic>>.from(widget.members ?? const []);
    _fillInitialTask();
    _loadLanguage();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadTaskOptions();
    });
  }

  void _fillInitialTask() {
    final task = widget.initialTask;
    if (task == null) return;

    _titleController.text = task['title']?.toString() ?? '';
    _descriptionController.text = task['description']?.toString() ?? '';
    _startDate = _parseDate(
      task['startDate'] ?? task['start_date'] ?? task['createdAt'],
    );
    _endDate = _parseDate(task['dueDate'] ?? task['due_date']);

    final assigneeIds = task['assignee_ids'];
    if (assigneeIds is List) {
      _selectedMemberIds.addAll(
        assigneeIds
            .map((value) => int.tryParse(value.toString()))
            .whereType<int>(),
      );
      return;
    }

    final assigneeId = int.tryParse(
      (task['assigneeId'] ?? task['assignee_id'] ?? '').toString(),
    );
    if (assigneeId != null) _selectedMemberIds.add(assigneeId);
  }

  DateTime? _parseDate(dynamic value) {
    if (value is DateTime) return value;
    final text = value?.toString();
    if (text == null || text.isEmpty || text == 'null') return null;
    if (text.contains('/')) {
      final parts = text.split('/');
      if (parts.length == 3) {
        final day = int.tryParse(parts[0]);
        final month = int.tryParse(parts[1]);
        final year = int.tryParse(parts[2]);
        if (day != null && month != null && year != null) {
          return DateTime(year, month, day);
        }
      }
    }
    return DateTime.tryParse(text);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _subtaskController.dispose();
    super.dispose();
  }

  String _t(String vi, String en, String zh) {
    switch (_language) {
      case CreateTaskLanguage.vietnamese:
        return vi;
      case CreateTaskLanguage.english:
        return en;
      case CreateTaskLanguage.chinese:
        return zh;
    }
  }

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final rawValue = prefs.getString('app_language');
    if (!mounted) return;
    setState(() {
      _language = CreateTaskLanguage.values.firstWhere(
        (language) => language.name == rawValue,
        orElse: () => CreateTaskLanguage.vietnamese,
      );
    });
  }

  Future<void> _loadTaskOptions() async {
    final projectId = widget.project?['id']?.toString() ?? '';
    if (projectId.isEmpty || _members.isNotEmpty) return;

    setState(() {
      _isLoadingOptions = true;
    });

    try {
      final options = await _projectService.getCreateTaskOptions(projectId);
      final rawMembers = options['assignee_options'] ?? options['members'];
      if (!mounted) return;
      setState(() {
        _members = rawMembers is List
            ? rawMembers
                .whereType<Map>()
                .map((member) => Map<String, dynamic>.from(member))
                .toList()
            : [];
        _isLoadingOptions = false;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _isLoadingOptions = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showMessage(err.toString(), isError: true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = appThemeController;

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
                      label: _t('TĂªn nhiá»‡m vá»¥', 'Task name', 'ä»»å¡åç§°'),
                      hintText: _t(
                        'Nháº­p tĂªn nhiá»‡m vá»¥',
                        'Enter task name',
                        'è¯·è¾“å…¥ä»»å¡åç§°',
                      ),
                      controller: _titleController,
                      icon: Icons.task_alt_rounded,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDatePicker(
                            label: _t('NgĂ y báº¯t Ä‘áº§u', 'Start date', 'å¼€å§‹æ—¥æœŸ'),
                            date: _startDate,
                            onTap: () => _pickDate(isStartDate: true),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildDatePicker(
                            label: _t('NgĂ y káº¿t thĂºc', 'End date', 'ç»“æŸæ—¥æœŸ'),
                            date: _endDate,
                            onTap: () => _pickDate(isStartDate: false),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildMemberPicker(),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: _t('MĂ´ táº£ nhiá»‡m vá»¥', 'Task description', 'ä»»å¡æè¿°'),
                      hintText: _t(
                        'Nháº­p mĂ´ táº£ cho nhiá»‡m vá»¥',
                        'Enter task description',
                        'è¯·è¾“å…¥ä»»å¡æè¿°',
                      ),
                      controller: _descriptionController,
                      icon: Icons.notes_rounded,
                      maxLines: 4,
                    ),
                    const SizedBox(height: 16),
                    _buildAttachmentSection(),
                    const SizedBox(height: 16),
                    _buildSubtaskSection(),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _submitTask,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(
                                widget.isEditing
                                    ? Icons.save_rounded
                                    : Icons.add_task_rounded,
                              ),
                        label: Text(
                          _isSaving
                              ? widget.isEditing
                                  ? _t('\u0110ang l\u01b0u...', 'Saving...', '\u6b63\u5728\u4fdd\u5b58...')
                                  : _t('Äang táº¡o...', 'Creating...', 'æ­£åœ¨åˆ›å»º...')
                              : widget.isEditing
                                  ? _t('L\u01b0u thay \u0111\u1ed5i', 'Save changes', '\u4fdd\u5b58\u66f4\u6539')
                                  : _t('Táº¡o nhiá»‡m vá»¥', 'Create task', 'åˆ›å»ºä»»å¡'),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.primaryColor,
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
              widget.isEditing
                  ? _t('S\u1eeda nhi\u1ec7m v\u1ee5', 'Edit task', '\u7f16\u8f91\u4efb\u52a1')
                  : _t('Táº¡o nhiá»‡m vá»¥', 'Create task', 'åˆ›å»ºä»»å¡'),
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

  Widget _buildDatePicker({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    final theme = appThemeController;
    return _buildSectionCard(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionLabel(label, Icons.calendar_month_rounded),
            const SizedBox(height: 10),
            Text(
              date == null
                  ? _t('Chá»n ngĂ y', 'Choose date', 'é€‰æ‹©æ—¥æœŸ')
                  : _formatDate(date),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: date == null ? theme.mutedTextColor : theme.textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberPicker() {
    final theme = appThemeController;
    return _buildSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionLabel(
            _t('NgÆ°á»i nháº­n nhiá»‡m vá»¥', 'Task assignees', 'ä»»å¡è´Ÿè´£äºº'),
            Icons.group_rounded,
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 156,
            child: _isLoadingOptions
                ? Center(
                    child: CircularProgressIndicator(color: theme.primaryColor),
                  )
                : _members.isEmpty
                    ? Center(
                        child: Text(
                          _t(
                            'ChÆ°a cĂ³ thĂ nh viĂªn trong dá»± Ă¡n',
                            'No members in this project yet',
                            'é¡¹ç›®æ‚æ— æˆå‘˜',
                          ),
                          style: TextStyle(color: theme.mutedTextColor),
                        ),
                      )
                    : ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        itemCount: _members.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final member = _members[index];
                          final memberId = _memberId(member);
                          final selected =
                              _selectedMemberIds.contains(memberId);
                          return InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: memberId == null
                                ? null
                                : () {
                                    setState(() {
                                      selected
                                          ? _selectedMemberIds.remove(memberId)
                                          : _selectedMemberIds.add(memberId);
                                    });
                                  },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: selected
                                    ? theme.primaryColor.withValues(alpha: 0.12)
                                    : theme.backgroundColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: selected
                                      ? theme.primaryColor
                                      : theme.mutedTextColor.withValues(
                                          alpha: 0.18,
                                        ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    selected
                                        ? Icons.check_circle_rounded
                                        : Icons.person_outline_rounded,
                                    color: selected
                                        ? theme.primaryColor
                                        : theme.mutedTextColor,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _memberName(member),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: theme.textColor,
                                          ),
                                        ),
                                        Text(
                                          _memberRole(member),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: theme.mutedTextColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentSection() {
    final theme = appThemeController;
    return _buildSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionLabel(
            _t('TĂ i liá»‡u Ä‘Ă­nh kĂ¨m', 'Attachments', 'é™„ä»¶'),
            Icons.attach_file_rounded,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildUploadButton(
                  Icons.image_rounded,
                  _t('áº¢nh', 'Image', 'å›¾ç‰‡'),
                  () => _pickImageOrVideo(isVideo: false),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildUploadButton(
                  Icons.videocam_rounded,
                  'Video',
                  () => _pickImageOrVideo(isVideo: true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildUploadButton(
                  Icons.insert_drive_file_rounded,
                  _t('TĂ i liá»‡u', 'Document', 'æ–‡æ¡£'),
                  _pickDocument,
                ),
              ),
            ],
          ),
          if (_attachments.isNotEmpty) ...[
            const SizedBox(height: 12),
            ..._attachments.asMap().entries.map(
                  (entry) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: theme.backgroundColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: theme.mutedTextColor.withValues(alpha: 0.16),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _attachmentIcon(entry.value['file_type']?.toString()),
                          size: 18,
                          color: theme.primaryColor,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            entry.value['file_name']?.toString() ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: theme.textColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => _removeAttachment(entry.key),
                          icon: const Icon(Icons.close_rounded),
                          color: const Color(0xFFEF4444),
                          iconSize: 18,
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ],
      ),
    );
  }

  Widget _buildSubtaskSection() {
    final theme = appThemeController;
    return _buildSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionLabel(
            _t('Táº¡o nhiá»‡m vá»¥ con', 'Create subtasks', 'åˆ›å»ºå­ä»»å¡'),
            Icons.checklist_rounded,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _subtaskController,
                  style: TextStyle(color: theme.textColor),
                  decoration: _inputDecoration(
                    _t(
                      'Nháº­p tĂªn nhiá»‡m vá»¥ con',
                      'Enter subtask name',
                      'è¯·è¾“å…¥å­ä»»å¡åç§°',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _addSubtask,
                icon: const Icon(Icons.add_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._subtasks.asMap().entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_box_outline_blank_rounded,
                        color: theme.primaryColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _subtaskLabel(entry.value),
                          style: TextStyle(
                            fontSize: 14,
                            color: theme.textColor,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => _removeSubtask(entry.key),
                        icon: const Icon(Icons.close_rounded),
                        color: const Color(0xFFEF4444),
                        iconSize: 20,
                        visualDensity: VisualDensity.compact,
                        tooltip: _t(
                          'XĂ³a nhiá»‡m vá»¥ con',
                          'Remove subtask',
                          'åˆ é™¤å­ä»»å¡',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildUploadButton(
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    final theme = appThemeController;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          color: theme.backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.mutedTextColor.withValues(alpha: 0.18),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: theme.primaryColor),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: theme.textColor,
              ),
            ),
          ],
        ),
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
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: theme.textColor,
            ),
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
        borderSide: BorderSide(color: theme.primaryColor, width: 1.5),
      ),
    );
  }

  String _subtaskLabel(String value) {
    switch (value) {
      case 'PhĂ¢n tĂ­ch yĂªu cáº§u':
        return _t('PhĂ¢n tĂ­ch yĂªu cáº§u', 'Analyze requirements', 'åˆ†æéœ€æ±‚');
      case 'Thiáº¿t káº¿ giao diá»‡n':
        return _t('Thiáº¿t káº¿ giao diá»‡n', 'Design interface', 'è®¾è®¡ç•Œé¢');
      default:
        return value;
    }
  }

  int? _memberId(Map<String, dynamic> member) {
    final value = member['id'] ?? member['user_id'];
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  String _memberName(Map<String, dynamic> member) {
    return member['name']?.toString() ??
        member['email']?.toString() ??
        _t('ThĂ nh viĂªn', 'Member', 'æˆå‘˜');
  }

  String _memberRole(Map<String, dynamic> member) {
    return member['role']?.toString() ??
        member['role_name']?.toString() ??
        _t('ThĂ nh viĂªn', 'Member', 'æˆå‘˜');
  }

  Future<void> _pickImageOrVideo({required bool isVideo}) async {
    final picked = isVideo
        ? await _imagePicker.pickVideo(source: ImageSource.gallery)
        : await _imagePicker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final size = await picked.length();
    final fileBase64 = base64Encode(await picked.readAsBytes());
    _addAttachment(
      fileName: picked.name,
      fileUrl: '',
      fileType: isVideo ? 'video' : 'image',
      mimeType: picked.mimeType,
      fileSize: size,
      fileBase64: fileBase64,
    );
  }

  Future<void> _pickDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowMultiple: false,
      allowedExtensions: const [
        'pdf',
        'doc',
        'docx',
        'xls',
        'xlsx',
        'ppt',
        'pptx',
        'txt',
        'zip',
        'rar',
      ],
    );
    final file = result?.files.single;
    if (file == null) return;
    final path = file.path;
    final bytes = file.bytes ??
        (path == null || path.isEmpty ? null : await File(path).readAsBytes());
    if (bytes == null || bytes.isEmpty) {
      _showMessage(
        _t(
          'KhĂ´ng thá»ƒ Ä‘á»c file Ä‘Ă£ chá»n',
          'Unable to read the selected file',
          'Unable to read the selected file',
        ),
        isError: true,
      );
      return;
    }

    _addAttachment(
      fileName: file.name,
      fileUrl: '',
      fileType: 'document',
      mimeType: null,
      fileSize: file.size,
      fileBase64: base64Encode(bytes),
    );
  }

  void _addAttachment({
    required String fileName,
    required String fileUrl,
    required String fileType,
    String? mimeType,
    int? fileSize,
    String? fileBase64,
  }) {
    setState(() {
      _attachments.add({
        'file_name': fileName,
        'file_url': fileUrl,
        'file_type': fileType,
        'mime_type': mimeType,
        'file_size': fileSize,
        if (fileBase64 != null && fileBase64.isNotEmpty)
          'file_base64': fileBase64,
      });
    });
  }

  void _removeAttachment(int index) {
    setState(() {
      _attachments.removeAt(index);
    });
  }

  IconData _attachmentIcon(String? fileType) {
    switch (fileType) {
      case 'image':
        return Icons.image_rounded;
      case 'video':
        return Icons.videocam_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  Future<void> _submitTask() async {
    final navigator = Navigator.of(context);
    final projectId = widget.project?['id']?.toString() ?? '';
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();

    if (projectId.isEmpty) {
      _showMessage(
        _t(
          'KhĂ´ng xĂ¡c Ä‘á»‹nh Ä‘Æ°á»£c dá»± Ă¡n cáº§n táº¡o nhiá»‡m vá»¥',
          'Unable to identify the project',
          'æ— æ³•ç¡®å®é¡¹ç›®',
        ),
        isError: true,
      );
      return;
    }

    if (title.isEmpty) {
      _showMessage(
        _t(
          'Vui lĂ²ng nháº­p tĂªn nhiá»‡m vá»¥',
          'Please enter task name',
          'è¯·è¾“å…¥ä»»å¡åç§°',
        ),
        isError: true,
      );
      return;
    }

    if (_startDate != null &&
        _endDate != null &&
        _endDate!.isBefore(_startDate!)) {
      _showMessage(
        _t(
          'NgĂ y káº¿t thĂºc khĂ´ng Ä‘Æ°á»£c trÆ°á»›c ngĂ y báº¯t Ä‘áº§u',
          'End date cannot be before start date',
          'ç»“æŸæ—¥æœŸä¸èƒ½æ—©äºå¼€å§‹æ—¥æœŸ',
        ),
        isError: true,
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      if (widget.isEditing) {
        final taskId = widget.initialTask?['id']?.toString() ?? '';
        if (taskId.isEmpty) {
          throw ApiException(
            _t(
              'Kh\u00f4ng x\u00e1c \u0111\u1ecbnh \u0111\u01b0\u1ee3c nhi\u1ec7m v\u1ee5 c\u1ea7n s\u1eeda',
              'Unable to identify the task',
              '\u65e0\u6cd5\u786e\u5b9a\u4efb\u52a1',
            ),
          );
        }
        await _projectService.updateTask(
          taskId: taskId,
          title: title,
          description: description,
          dueDate: _endDate,
          assigneeIds: _selectedMemberIds.toList(),
          assigneeId: _selectedMemberIds.isEmpty
              ? ''
              : _selectedMemberIds.first.toString(),
        );
      } else {
        await _projectService.createTask(
          projectId: projectId,
          title: title,
          description: description.isEmpty ? null : description,
          startDate: _startDate,
          endDate: _endDate,
          assigneeIds: _selectedMemberIds.toList(),
          subtasks: _subtasks,
          attachments: _attachments,
        );
      }

      if (!mounted) return;
      navigator.pop(true);
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });
      _showMessage(err.toString(), isError: true);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? const Color(0xFFEF4444) : null,
      ),
    );
  }

  Future<void> _pickDate({required bool isStartDate}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isStartDate
          ? (_startDate ?? now)
          : (_endDate ?? _startDate ?? now),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );

    if (picked == null) return;
    if (!mounted) return;
    setState(() {
      if (isStartDate) {
        _startDate = picked;
      } else {
        _endDate = picked;
      }
    });
  }

  void _addSubtask() {
    final value = _subtaskController.text.trim();
    if (value.isEmpty) return;
    setState(() {
      _subtasks.add(value);
      _subtaskController.clear();
    });
  }

  void _removeSubtask(int index) {
    setState(() {
      _subtasks.removeAt(index);
    });
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
