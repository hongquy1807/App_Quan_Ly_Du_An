import 'package:flutter/material.dart';
import 'utils/color_utils.dart';
import 'task_detail_screen.dart'; // Import trang chi tiết task

class ProjectDetailScreen extends StatefulWidget {
  final Map<String, dynamic> project;

  const ProjectDetailScreen({super.key, required this.project});

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  // Biến sắp xếp
  bool _isAscending = true;

  // Filter: 'all_tasks', 'in_progress', 'my_tasks', 'completed'
  String _currentFilter = 'all_tasks';

  // Dữ liệu task mẫu
  List<Map<String, dynamic>> _allTasks = [];

  // Thông tin thành viên
  final List<Map<String, dynamic>> _members = [
    {'id': '1', 'name': 'Nguyễn Văn A', 'avatar': '', 'role': 'Trưởng nhóm'},
    {'id': '2', 'name': 'Trần Thị B', 'avatar': '', 'role': 'Thành viên'},
    {'id': '3', 'name': 'Lê Văn C', 'avatar': '', 'role': 'Thành viên'},
    {'id': '4', 'name': 'Phạm Thị D', 'avatar': '', 'role': 'Thành viên'},
  ];

  @override
  void initState() {
    super.initState();
    _initTaskData();
  }

  void _initTaskData() {
    final now = DateTime.now();
    _allTasks = [
      // Task của tôi (chưa hoàn thành)
      {
        'id': '1',
        'title': 'Thiết kế UI cho màn hình chính',
        'description':
            'Thiết kế giao diện người dùng cho màn hình chính của ứng dụng',
        'dueDate': now.add(const Duration(days: 2)),
        'assignee': 'Nguyễn Văn A',
        'assigneeId': '1',
        'priority': 'Cao',
        'status': 'Đang làm',
        'isCompleted': false,
        'createdAt': now.subtract(const Duration(days: 3)),
      },
      {
        'id': '2',
        'title': 'Xây dựng API đăng nhập',
        'description': 'Tạo API cho chức năng đăng nhập và đăng ký',
        'dueDate': now.add(const Duration(days: 5)),
        'assignee': 'Nguyễn Văn A',
        'assigneeId': '1',
        'priority': 'Trung bình',
        'status': 'Chưa bắt đầu',
        'isCompleted': false,
        'createdAt': now.subtract(const Duration(days: 1)),
      },
      {
        'id': '3',
        'title': 'Tối ưu hiệu suất ứng dụng',
        'description': 'Tối ưu hóa hiệu suất và giảm thời gian tải',
        'dueDate': now.subtract(const Duration(days: 1)),
        'assignee': 'Nguyễn Văn A',
        'assigneeId': '1',
        'priority': 'Cao',
        'status': 'Trễ hạn',
        'isCompleted': false,
        'createdAt': now.subtract(const Duration(days: 7)),
      },
      // Task của tôi (đã hoàn thành)
      {
        'id': '4',
        'title': 'Phân tích yêu cầu dự án',
        'description': 'Phân tích và document yêu cầu từ khách hàng',
        'dueDate': now.subtract(const Duration(days: 5)),
        'assignee': 'Nguyễn Văn A',
        'assigneeId': '1',
        'priority': 'Thấp',
        'status': 'Hoàn thành',
        'isCompleted': true,
        'createdAt': now.subtract(const Duration(days: 10)),
      },
      // Task của đồng đội (chưa hoàn thành)
      {
        'id': '5',
        'title': 'Thiết kế database',
        'description': 'Thiết kế cơ sở dữ liệu cho hệ thống',
        'dueDate': now.add(const Duration(days: 3)),
        'assignee': 'Trần Thị B',
        'assigneeId': '2',
        'priority': 'Cao',
        'status': 'Đang làm',
        'isCompleted': false,
        'createdAt': now.subtract(const Duration(days: 2)),
      },
      {
        'id': '6',
        'title': 'Viết unit test',
        'description': 'Viết unit test cho các module chính',
        'dueDate': now.add(const Duration(days: 7)),
        'assignee': 'Lê Văn C',
        'assigneeId': '3',
        'priority': 'Trung bình',
        'status': 'Chưa bắt đầu',
        'isCompleted': false,
        'createdAt': now.subtract(const Duration(days: 1)),
      },
      {
        'id': '7',
        'title': 'Deploy lên production',
        'description': 'Triển khai ứng dụng lên môi trường production',
        'dueDate': now.add(const Duration(days: 10)),
        'assignee': 'Phạm Thị D',
        'assigneeId': '4',
        'priority': 'Cao',
        'status': 'Chờ duyệt',
        'isCompleted': false,
        'createdAt': now.subtract(const Duration(days: 3)),
      },
      // Task của đồng đội (đã hoàn thành)
      {
        'id': '8',
        'title': 'Code review',
        'description': 'Review code của các thành viên trong team',
        'dueDate': now.subtract(const Duration(days: 2)),
        'assignee': 'Trần Thị B',
        'assigneeId': '2',
        'priority': 'Trung bình',
        'status': 'Hoàn thành',
        'isCompleted': true,
        'createdAt': now.subtract(const Duration(days: 8)),
      },
    ];
  }

  List<Map<String, dynamic>> _getFilteredTasks() {
    List<Map<String, dynamic>> filtered = [];

    switch (_currentFilter) {
      case 'my_tasks':
        // Tất cả task của tôi
        filtered = _allTasks
            .where((task) => task['assigneeId'] == '1')
            .toList();
        break;

      case 'in_progress':
        // Tất cả task đang được thực hiện
        filtered = _allTasks
            .where((task) => task['status'] == 'Đang làm' && !task['isCompleted'])
            .toList();
        break;

      case 'all_tasks':
        // Tất cả task của các thành viên ở mọi trạng thái
        filtered = List<Map<String, dynamic>>.from(_allTasks);
        break;

      case 'completed':
        // Tất cả task đã hoàn thành của mọi thành viên
        filtered = _allTasks
            .where((task) => task['isCompleted'])
            .toList();
        break;

      default:
        filtered = [];
    }

    // Sắp xếp theo tên, riêng "Nhiệm vụ của tôi" đưa task hoàn thành xuống cuối.
    filtered.sort((a, b) {
      if (_currentFilter == 'my_tasks') {
        final aCompleted = a['isCompleted'] == true;
        final bCompleted = b['isCompleted'] == true;
        if (aCompleted != bCompleted) {
          return aCompleted ? 1 : -1;
        }
      }

      final nameA = a['title'].toLowerCase();
      final nameB = b['title'].toLowerCase();
      return _isAscending ? nameA.compareTo(nameB) : nameB.compareTo(nameA);
    });

    return filtered;
  }

  int _getTaskCount(String filter) {
    switch (filter) {
      case 'my_tasks':
        return _allTasks.where((t) => t['assigneeId'] == '1').length;
      case 'in_progress':
        return _allTasks
            .where((t) => t['status'] == 'Đang làm' && !t['isCompleted'])
            .length;
      case 'all_tasks':
        return _allTasks.length;
      case 'completed':
        return _allTasks.where((t) => t['isCompleted']).length;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final project = widget.project;
    final color = parseHexColor(project['color']);
    final filteredTasks = _getFilteredTasks();
    final incompleteTasks = _allTasks.where((t) => !t['isCompleted']).length;

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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back button và tên dự án
                  Row(
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
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 32,
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                project['name'],
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1F2937),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Thông tin nhanh
                  Row(
                    children: [
                      _buildQuickInfo(
                        icon: Icons.task_rounded,
                        label: 'Task chưa hoàn thành',
                        value: incompleteTasks.toString(),
                        color: color,
                      ),
                      const SizedBox(width: 12),
                      _buildQuickInfo(
                        icon: Icons.people_rounded,
                        label: 'Thành viên',
                        value: _members.length.toString(),
                        color: color,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            _buildActionButtons(color),
            const SizedBox(height: 12),

            // Filter và Sort
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  // Filter buttons
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip(
                            label: 'Tất cả',
                            value: 'all_tasks',
                            count: _getTaskCount('all_tasks'),
                            icon: Icons.list_rounded,
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            label: 'Đang tiến hành',
                            value: 'in_progress',
                            count: _getTaskCount('in_progress'),
                            icon: Icons.play_circle_rounded,
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            label: 'Nhiệm vụ của tôi',
                            value: 'my_tasks',
                            count: _getTaskCount('my_tasks'),
                            icon: Icons.person_rounded,
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            label: 'Hoàn thành',
                            value: 'completed',
                            count: _getTaskCount('completed'),
                            icon: Icons.check_circle_rounded,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Sort button
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      onPressed: () {
                        setState(() {
                          _isAscending = !_isAscending;
                        });
                      },
                      icon: Icon(
                        _isAscending
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
                        color: const Color(0xFF6366F1),
                        size: 22,
                      ),
                      tooltip: _isAscending ? 'A → Z' : 'Z → A',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Danh sách task
            Expanded(
              child: filteredTasks.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle_outline_rounded,
                            size: 80,
                            color: const Color(
                              0xFF6B7280,
                            ).withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Không có task nào',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _currentFilter == 'my_tasks'
                                ? 'Bạn chưa có task nào trong dự án này'
                                : 'Không có task nào phù hợp',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF9CA3AF),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      itemCount: filteredTasks.length,
                      itemBuilder: (context, index) {
                        final task = filteredTasks[index];
                        return _buildTaskCard(task);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickInfo({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.1)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, '/create-task');
              },
              icon: const Icon(Icons.add_task_rounded, size: 18),
              label: const Text(
                'Thêm nhiệm vụ',
                overflow: TextOverflow.ellipsis,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _showAddMemberSheet(color),
              icon: Icon(Icons.person_add_rounded, size: 18, color: color),
              label: Text(
                'Thêm thành viên',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: color, fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                side: BorderSide(color: color.withValues(alpha: 0.35)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddTaskSheet(Color color) {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ProjectActionSheet(
        title: 'Thêm nhiệm vụ',
        buttonText: 'Tạo nhiệm vụ',
        color: color,
        children: [
          _ActionTextField(
            controller: titleController,
            label: 'Tên nhiệm vụ',
            hintText: 'Nhập tên nhiệm vụ',
          ),
          const SizedBox(height: 12),
          _ActionTextField(
            controller: descriptionController,
            label: 'Mô tả',
            hintText: 'Nhập mô tả nhiệm vụ',
            maxLines: 3,
          ),
        ],
        onSubmit: () {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã tạo nhiệm vụ mới')),
          );
        },
      ),
    ).whenComplete(() {
      titleController.dispose();
      descriptionController.dispose();
    });
  }

  void _showAddMemberSheet(Color color) {
    final emailController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ProjectActionSheet(
        title: 'Thêm thành viên',
        buttonText: 'Gửi lời mời',
        color: color,
        children: [
          _ActionTextField(
            controller: emailController,
            label: 'Email thành viên',
            hintText: 'Nhập email',
          ),
        ],
        onSubmit: () {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã gửi lời mời thành viên')),
          );
        },
      ),
    ).whenComplete(() {
      emailController.dispose();
    });
  }

  Widget _buildFilterChip({
    required String label,
    required String value,
    required int count,
    required IconData icon,
  }) {
    final isSelected = _currentFilter == value;

    return FilterChip(
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _currentFilter = value;
        });
      },
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: isSelected ? Colors.white : const Color(0xFF6B7280),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isSelected ? Colors.white : const Color(0xFF4B5563),
            ),
          ),
          if (count > 0) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.2)
                    : const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : const Color(0xFF6B7280),
                ),
              ),
            ),
          ],
        ],
      ),
      backgroundColor: const Color(0xFFF3F4F6),
      selectedColor: const Color(0xFF6366F1),
      checkmarkColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> task) {
    final dueDate = task['dueDate'] as DateTime;
    final isOverdue = dueDate.isBefore(DateTime.now()) && !task['isCompleted'];
    final isCompleted = task['isCompleted'];
    final isMyTask = task['assigneeId'] == '1';

    return GestureDetector(
      onTap: () {
        // Điều hướng đến trang chi tiết task đã tạo riêng
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                TaskDetailScreen(task: task, project: widget.project),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
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
              children: [
                // Status indicator
                Container(
                  width: 4,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? const Color(0xFF10B981)
                        : isOverdue
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF6366F1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                // Task info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task['title'],
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isCompleted
                              ? const Color(0xFF6B7280)
                              : const Color(0xFF1F2937),
                          decoration: isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        task['description'],
                        style: TextStyle(
                          fontSize: 12,
                          color: const Color(0xFF6B7280),
                          decoration: isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Bottom row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    // Assignee
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isMyTask
                            ? const Color(0xFF6366F1).withValues(alpha: 0.1)
                            : const Color(0xFF10B981).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isMyTask
                                ? Icons.person_rounded
                                : Icons.people_rounded,
                            size: 12,
                            color: isMyTask
                                ? const Color(0xFF6366F1)
                                : const Color(0xFF10B981),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isMyTask ? 'Tôi' : task['assignee'],
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: isMyTask
                                  ? const Color(0xFF6366F1)
                                  : const Color(0xFF10B981),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Due date
                    Row(
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 14,
                          color: isOverdue
                              ? const Color(0xFFEF4444)
                              : const Color(0xFF6B7280),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${dueDate.day.toString().padLeft(2, '0')}/${dueDate.month.toString().padLeft(2, '0')}/${dueDate.year}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isOverdue
                                ? const Color(0xFFEF4444)
                                : const Color(0xFF6B7280),
                            fontWeight: isOverdue
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? const Color(0xFF10B981).withValues(alpha: 0.1)
                        : isOverdue
                        ? const Color(0xFFEF4444).withValues(alpha: 0.1)
                        : const Color(0xFF6366F1).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isCompleted
                          ? const Color(0xFF10B981).withValues(alpha: 0.2)
                          : isOverdue
                          ? const Color(0xFFEF4444).withValues(alpha: 0.2)
                          : const Color(0xFF6366F1).withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    isCompleted
                        ? '✅ Hoàn thành'
                        : isOverdue
                        ? '⏰ Trễ hạn'
                        : '🔄 ${task['status']}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isCompleted
                          ? const Color(0xFF10B981)
                          : isOverdue
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF6366F1),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectActionSheet extends StatelessWidget {
  final String title;
  final String buttonText;
  final Color color;
  final List<Widget> children;
  final VoidCallback onSubmit;

  const _ProjectActionSheet({
    required this.title,
    required this.buttonText,
    required this.color,
    required this.children,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 16),
              ...children,
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: onSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    buttonText,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
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

class _ActionTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hintText;
  final int maxLines;

  const _ActionTextField({
    required this.controller,
    required this.label,
    required this.hintText,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
        ),
      ),
    );
  }
}
