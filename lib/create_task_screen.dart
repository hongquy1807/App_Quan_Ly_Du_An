import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme_controller.dart';
import 'services/project_service.dart';

enum CreateTaskLanguage { vietnamese, english, chinese }

class CreateTaskScreen extends StatefulWidget {
  const CreateTaskScreen({super.key, this.project, this.members});

  final Map<String, dynamic>? project;
  final List<Map<String, dynamic>>? members;

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
    _loadLanguage();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadTaskOptions();
    });
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
                      label: _t('Tên nhiệm vụ', 'Task name', '任务名称'),
                      hintText: _t(
                        'Nhập tên nhiệm vụ',
                        'Enter task name',
                        '请输入任务名称',
                      ),
                      controller: _titleController,
                      icon: Icons.task_alt_rounded,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDatePicker(
                            label: _t('Ngày bắt đầu', 'Start date', '开始日期'),
                            date: _startDate,
                            onTap: () => _pickDate(isStartDate: true),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildDatePicker(
                            label: _t('Ngày kết thúc', 'End date', '结束日期'),
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
                      label: _t('Mô tả nhiệm vụ', 'Task description', '任务描述'),
                      hintText: _t(
                        'Nhập mô tả cho nhiệm vụ',
                        'Enter task description',
                        '请输入任务描述',
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
                            : const Icon(Icons.add_task_rounded),
                        label: Text(
                          _isSaving
                              ? _t('Đang tạo...', 'Creating...', '正在创建...')
                              : _t('Tạo nhiệm vụ', 'Create task', '创建任务'),
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
              _t('Tạo nhiệm vụ', 'Create task', '创建任务'),
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
                  ? _t('Chọn ngày', 'Choose date', '选择日期')
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
            _t('Người nhận nhiệm vụ', 'Task assignees', '任务负责人'),
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
                            'Chưa có thành viên trong dự án',
                            'No members in this project yet',
                            '项目暂无成员',
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
            _t('Tài liệu đính kèm', 'Attachments', '附件'),
            Icons.attach_file_rounded,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildUploadButton(
                  Icons.image_rounded,
                  _t('Ảnh', 'Image', '图片'),
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
                  _t('Tài liệu', 'Document', '文档'),
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
            _t('Tạo nhiệm vụ con', 'Create subtasks', '创建子任务'),
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
                      'Nhập tên nhiệm vụ con',
                      'Enter subtask name',
                      '请输入子任务名称',
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
                          'Xóa nhiệm vụ con',
                          'Remove subtask',
                          '删除子任务',
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
      case 'Phân tích yêu cầu':
        return _t('Phân tích yêu cầu', 'Analyze requirements', '分析需求');
      case 'Thiết kế giao diện':
        return _t('Thiết kế giao diện', 'Design interface', '设计界面');
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
        _t('Thành viên', 'Member', '成员');
  }

  String _memberRole(Map<String, dynamic> member) {
    return member['role']?.toString() ??
        member['role_name']?.toString() ??
        _t('Thành viên', 'Member', '成员');
  }

  Future<void> _pickImageOrVideo({required bool isVideo}) async {
    final picked = isVideo
        ? await _imagePicker.pickVideo(source: ImageSource.gallery)
        : await _imagePicker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final size = await picked.length();
    _addAttachment(
      fileName: picked.name,
      fileUrl: picked.path,
      fileType: isVideo ? 'video' : 'image',
      mimeType: picked.mimeType,
      fileSize: size,
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

    _addAttachment(
      fileName: file.name,
      fileUrl: file.path ?? file.name,
      fileType: 'document',
      mimeType: null,
      fileSize: file.size,
    );
  }

  void _addAttachment({
    required String fileName,
    required String fileUrl,
    required String fileType,
    String? mimeType,
    int? fileSize,
  }) {
    setState(() {
      _attachments.add({
        'file_name': fileName,
        'file_url': fileUrl,
        'file_type': fileType,
        'mime_type': mimeType,
        'file_size': fileSize,
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
          'Không xác định được dự án cần tạo nhiệm vụ',
          'Unable to identify the project',
          '无法确定项目',
        ),
        isError: true,
      );
      return;
    }

    if (title.isEmpty) {
      _showMessage(
        _t(
          'Vui lòng nhập tên nhiệm vụ',
          'Please enter task name',
          '请输入任务名称',
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
          'Ngày kết thúc không được trước ngày bắt đầu',
          'End date cannot be before start date',
          '结束日期不能早于开始日期',
        ),
        isError: true,
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
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
