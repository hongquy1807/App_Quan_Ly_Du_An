import 'package:flutter/material.dart';
import 'utils/color_utils.dart';

class TaskDetailScreen extends StatefulWidget {
  final Map<String, dynamic> task;
  final Map<String, dynamic> project;

  const TaskDetailScreen({
    super.key,
    required this.task,
    required this.project,
  });

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  // Danh sách comment mẫu
  final List<Map<String, dynamic>> _comments = [
    {
      'id': '1',
      'user': 'Nguyễn Văn A',
      'avatar': '',
      'content':
          'Tôi đã bắt đầu làm task này. Dự kiến hoàn thành trong 2 ngày tới.',
      'time': DateTime.now().subtract(const Duration(hours: 2)),
      'isMine': true,
    },
    {
      'id': '2',
      'user': 'Trần Thị B',
      'avatar': '',
      'content': 'OK, tôi đã gửi tài liệu tham khảo qua email cho bạn.',
      'time': DateTime.now().subtract(const Duration(hours: 1)),
      'isMine': false,
    },
  ];

  final TextEditingController _commentController = TextEditingController();
  bool _isSubmittingComment = false;
  late String _taskStatus;

  @override
  void initState() {
    super.initState();
    _taskStatus = widget.task['status']?.toString() ?? 'Chưa nhận';
  }

  // Danh sách file đính kèm mẫu
  final List<Map<String, dynamic>> _attachments = [
    {
      'name': 'UI_Design.fig',
      'size': '2.4 MB',
      'icon': Icons.design_services,
      'color': Color(0xFF6366F1),
    },
    {
      'name': 'API_Document.pdf',
      'size': '1.1 MB',
      'icon': Icons.picture_as_pdf,
      'color': Color(0xFFEF4444),
    },
    {
      'name': 'Database_Schema.sql',
      'size': '856 KB',
      'icon': Icons.data_usage,
      'color': Color(0xFF10B981),
    },
  ];

  // Danh sách subtask mẫu
  final List<Map<String, dynamic>> _subtasks = [
    {'id': '1', 'title': 'Phân tích yêu cầu', 'isCompleted': true},
    {'id': '2', 'title': 'Thiết kế giao diện', 'isCompleted': true},
    {'id': '3', 'title': 'Xây dựng API', 'isCompleted': false},
    {'id': '4', 'title': 'Kiểm thử', 'isCompleted': false},
  ];

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _handleAddComment() {
    if (_commentController.text.trim().isEmpty) return;

    setState(() {
      _isSubmittingComment = true;
    });

    // Giả lập gửi comment
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;

      setState(() {
        _comments.insert(0, {
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
          'user': 'Nguyễn Văn A',
          'avatar': '',
          'content': _commentController.text.trim(),
          'time': DateTime.now(),
          'isMine': true,
        });
        _commentController.clear();
        _isSubmittingComment = false;
      });
    });
  }

  void _handleToggleSubtask(String id) {
    setState(() {
      final index = _subtasks.indexWhere((st) => st['id'] == id);
      if (index != -1) {
        _subtasks[index]['isCompleted'] = !_subtasks[index]['isCompleted'];
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final project = widget.project;
    final projectColor = parseHexColor(project['color']);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
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
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 20,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Chi tiết nhiệm vụ',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                        Text(
                          task['title'],
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1F2937),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Nội dung chính
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Thông tin cơ bản
                    _buildInfoSection(projectColor),
                    const SizedBox(height: 16),

                    // Subtasks
                    _buildSubtaskSection(),
                    const SizedBox(height: 16),

                    // Tài liệu của người nhận
                    _buildMyAttachmentSection(),
                    const SizedBox(height: 16),

                    // Comments
                    _buildCommentSection(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(Color projectColor) {
    final task = widget.task;
    final dueDate = task['dueDate'] as DateTime;
    final createdAt = task['createdAt'] as DateTime;
    final isOverdue = dueDate.isBefore(DateTime.now()) && !task['isCompleted'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const Text(
            'Thông tin nhiệm vụ',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 16),

          // Grid thông tin
          Row(
            children: [
              Expanded(
                child: _buildInfoItem(
                  icon: Icons.calendar_today_rounded,
                  label: 'Ngày giao',
                  value:
                      '${createdAt.day.toString().padLeft(2, '0')}/${createdAt.month.toString().padLeft(2, '0')}/${createdAt.year}',
                  color: const Color(0xFF6366F1),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInfoItem(
                  icon: Icons.access_time_rounded,
                  label: 'Hạn chót',
                  value:
                      '${dueDate.day.toString().padLeft(2, '0')}/${dueDate.month.toString().padLeft(2, '0')}/${dueDate.year}',
                  color: isOverdue
                      ? const Color(0xFFEF4444)
                      : const Color(0xFF10B981),
                  isOverdue: isOverdue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _buildInfoItem(
                  icon: Icons.person_rounded,
                  label: 'Người thực hiện',
                  value: task['assignee'],
                  color: const Color(0xFF8B5CF6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Dự án
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: projectColor.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: projectColor.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 30,
                  decoration: BoxDecoration(
                    color: projectColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Thuộc dự án',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      Text(
                        widget.project['name'],
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: projectColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: projectColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.folder_rounded,
                    size: 20,
                    color: projectColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Mô tả
          const Text(
            'Mô tả',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              task['description'] ?? 'Chưa có mô tả cho nhiệm vụ này.',
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF4B5563),
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildTaskAttachmentSection(),
          const SizedBox(height: 16),
          const Text(
            'Trạng thái',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 8),
          _buildStatusSelector(),
        ],
      ),
    );
  }

  Widget _buildStatusSelector() {
    return Column(
      children: [
        _buildStatusOption('Chưa nhận', Icons.inbox_rounded),
        const SizedBox(height: 8),
        _buildStatusOption('Đã nhận nhiệm vụ', Icons.assignment_ind_rounded),
        const SizedBox(height: 8),
        _buildStatusOption('Hoàn thành', Icons.check_circle_rounded),
      ],
    );
  }

  Widget _buildStatusOption(String status, IconData icon) {
    final isSelected = _taskStatus == status ||
        (status == 'Đã nhận nhiệm vụ' && _taskStatus == 'Đang làm') ||
        (status == 'Chưa nhận' && _taskStatus == 'Chưa bắt đầu');
    final color = status == 'Hoàn thành'
        ? const Color(0xFF10B981)
        : status == 'Đã nhận nhiệm vụ'
        ? const Color(0xFF6366F1)
        : const Color(0xFF6B7280);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        setState(() {
          _taskStatus = status;
          widget.task['status'] = status;
          widget.task['isCompleted'] = status == 'Hoàn thành';
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.1)
              : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? color.withValues(alpha: 0.35)
                : const Color(0xFFE5E7EB),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                status,
                style: TextStyle(
                  color: isSelected ? color : const Color(0xFF1F2937),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (isSelected) Icon(Icons.check_rounded, color: color, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    bool isOverdue = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isOverdue ? const Color(0xFFEF4444) : Color(0xFF1F2937),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubtaskSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '📋 Subtask',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
              Text(
                '${_subtasks.where((st) => st['isCompleted']).length}/${_subtasks.length}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6366F1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._subtasks.map((subtask) {
            return _buildSubtaskItem(subtask);
          }),
          // Nút thêm subtask
          GestureDetector(
            onTap: () {
              _showAddSubtaskDialog();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_rounded, size: 20, color: Color(0xFF6B7280)),
                  SizedBox(width: 4),
                  Text(
                    'Thêm subtask',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w500,
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

  Widget _buildSubtaskItem(Map<String, dynamic> subtask) {
    return CheckboxListTile(
      value: subtask['isCompleted'],
      onChanged: (value) {
        _handleToggleSubtask(subtask['id']);
      },
      title: Text(
        subtask['title'],
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: subtask['isCompleted']
              ? const Color(0xFF6B7280)
              : const Color(0xFF1F2937),
          decoration: subtask['isCompleted']
              ? TextDecoration.lineThrough
              : null,
        ),
      ),
      controlAffinity: ListTileControlAffinity.leading,
      activeColor: const Color(0xFF6366F1),
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }

  Widget _buildTaskAttachmentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Tài liệu đính kèm',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1F2937),
              ),
            ),
            Text(
              '${_attachments.length} file',
              style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ..._attachments.map((file) => _buildAttachmentItem(file)),
      ],
    );
  }

  Widget _buildMyAttachmentSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tài liệu của bạn',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildUploadTypeButton(
                  icon: Icons.image_rounded,
                  label: 'Ảnh',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildUploadTypeButton(
                  icon: Icons.videocam_rounded,
                  label: 'Video',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildUploadTypeButton(
                  icon: Icons.insert_drive_file_rounded,
                  label: 'Tài liệu',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: _handleCompleteTask,
              icon: const Icon(Icons.check_circle_rounded),
              label: const Text('Hoàn thành'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadTypeButton({
    required IconData icon,
    required String label,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chọn $label đang được phát triển')),
        );
      },
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFF6366F1)),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleCompleteTask() {
    setState(() {
      _taskStatus = 'Hoàn thành';
      widget.task['status'] = 'Hoàn thành';
      widget.task['isCompleted'] = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Nhiệm vụ đã được đánh dấu hoàn thành'),
        backgroundColor: Color(0xFF10B981),
      ),
    );
  }

  Widget _buildAttachmentItem(Map<String, dynamic> file) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: file['color'].withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: file['color'].withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: file['color'].withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(file['icon'], size: 20, color: file['color']),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file['name'],
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1F2937),
                  ),
                ),
                Text(
                  file['size'],
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('⬇️ Đang tải xuống...'),
                  backgroundColor: Color(0xFF6366F1),
                ),
              );
            },
            icon: const Icon(
              Icons.download_rounded,
              color: Color(0xFF6B7280),
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '💬 Bình luận',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
              Text(
                '${_comments.length} bình luận',
                style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Input comment
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFF6366F1),
                child: const Text(
                  'A',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _commentController,
                          decoration: const InputDecoration(
                            hintText: 'Viết bình luận...',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                          ),
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF1F2937),
                          ),
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _handleAddComment(),
                        ),
                      ),
                      IconButton(
                        onPressed: _isSubmittingComment
                            ? null
                            : _handleAddComment,
                        icon: _isSubmittingComment
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.send_rounded,
                                color: Color(0xFF6366F1),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Danh sách comment
          ..._comments.map((comment) {
            return _buildCommentItem(comment);
          }),
        ],
      ),
    );
  }

  Widget _buildCommentItem(Map<String, dynamic> comment) {
    final time = comment['time'] as DateTime;
    final diff = DateTime.now().difference(time);
    String timeText;
    if (diff.inMinutes < 1) {
      timeText = 'Vừa xong';
    } else if (diff.inHours < 1) {
      timeText = '${diff.inMinutes} phút trước';
    } else if (diff.inDays < 1) {
      timeText = '${diff.inHours} giờ trước';
    } else {
      timeText = '${diff.inDays} ngày trước';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: comment['isMine']
            ? const Color(0xFF6366F1).withValues(alpha: 0.05)
            : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: comment['isMine']
              ? const Color(0xFF6366F1).withValues(alpha: 0.1)
              : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: comment['isMine']
                    ? const Color(0xFF6366F1)
                    : const Color(0xFF8B5CF6),
                child: Text(
                  comment['user'][0],
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      comment['user'],
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    Text(
                      timeText,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              if (comment['isMine'])
                IconButton(
                  onPressed: () {
                    setState(() {
                      _comments.removeWhere((c) => c['id'] == comment['id']);
                    });
                  },
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: Color(0xFF6B7280),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            comment['content'],
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF4B5563),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  void _showAddSubtaskDialog() {
    final TextEditingController controller = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Thêm subtask mới',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Nhập tên subtask',
                style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Nhập tên subtask...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                ),
                onSubmitted: (_) {
                  if (controller.text.trim().isNotEmpty) {
                    setState(() {
                      _subtasks.add({
                        'id': DateTime.now().millisecondsSinceEpoch.toString(),
                        'title': controller.text.trim(),
                        'isCompleted': false,
                      });
                    });
                    Navigator.pop(context);
                  }
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    if (controller.text.trim().isNotEmpty) {
                      setState(() {
                        _subtasks.add({
                          'id': DateTime.now().millisecondsSinceEpoch
                              .toString(),
                          'title': controller.text.trim(),
                          'isCompleted': false,
                        });
                      });
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Thêm subtask',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
