import 'package:flutter/material.dart';
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

  // Filter: 'my_tasks', 'team_tasks', 'all_tasks', 'my_all_tasks'
  String _currentFilter = 'my_tasks';

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
        // Task của tôi, chưa hoàn thành
        filtered = _allTasks
            .where((task) => task['assigneeId'] == '1' && !task['isCompleted'])
            .toList();
        break;

      case 'team_tasks':
        // Task của đồng đội, chưa hoàn thành
        filtered = _allTasks
            .where((task) => task['assigneeId'] != '1' && !task['isCompleted'])
            .toList();
        break;

      case 'all_tasks':
        // Tất cả task chưa hoàn thành (của tôi + đồng đội)
        filtered = _allTasks.where((task) => !task['isCompleted']).toList();
        break;

      case 'my_all_tasks':
        // Tất cả task của tôi (đã hoàn thành + chưa hoàn thành)
        filtered = _allTasks
            .where((task) => task['assigneeId'] == '1')
            .toList();
        break;

      default:
        filtered = [];
    }

    // Sắp xếp theo tên
    filtered.sort((a, b) {
      final nameA = a['title'].toLowerCase();
      final nameB = b['title'].toLowerCase();
      return _isAscending ? nameA.compareTo(nameB) : nameB.compareTo(nameA);
    });

    return filtered;
  }

  int _getTaskCount(String filter) {
    switch (filter) {
      case 'my_tasks':
        return _allTasks
            .where((t) => t['assigneeId'] == '1' && !t['isCompleted'])
            .length;
      case 'team_tasks':
        return _allTasks
            .where((t) => t['assigneeId'] != '1' && !t['isCompleted'])
            .length;
      case 'all_tasks':
        return _allTasks.where((t) => !t['isCompleted']).length;
      case 'my_all_tasks':
        return _allTasks.where((t) => t['assigneeId'] == '1').length;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final project = widget.project;
    final color = Color(
      int.parse('FF${project['color']!.substring(1)}', radix: 16),
    );
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
                      const SizedBox(width: 12),
                      _buildQuickInfo(
                        icon: Icons.trending_up_rounded,
                        label: 'Tiến độ',
                        value:
                            '${_allTasks.where((t) => t['isCompleted']).length}/${_allTasks.length}',
                        color: color,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

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
                            label: 'Của tôi',
                            value: 'my_tasks',
                            count: _getTaskCount('my_tasks'),
                            icon: Icons.person_rounded,
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            label: 'Đồng đội',
                            value: 'team_tasks',
                            count: _getTaskCount('team_tasks'),
                            icon: Icons.people_rounded,
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            label: 'Tất cả',
                            value: 'all_tasks',
                            count: _getTaskCount('all_tasks'),
                            icon: Icons.list_rounded,
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            label: 'Task của tôi',
                            value: 'my_all_tasks',
                            count: _getTaskCount('my_all_tasks'),
                            icon: Icons.folder_rounded,
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

    Color priorityColor;
    switch (task['priority']) {
      case 'Cao':
        priorityColor = const Color(0xFFEF4444);
        break;
      case 'Trung bình':
        priorityColor = const Color(0xFFF59E0B);
        break;
      default:
        priorityColor = const Color(0xFF10B981);
    }

    return GestureDetector(
      onTap: () {
        // Điều hướng đến trang chi tiết task đã tạo riêng
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TaskDetailScreen(
              task: task,
              project: widget.project,
            ),
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
                      Row(
                        children: [
                          Expanded(
                            child: Text(
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
                          ),
                          // Priority badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: priorityColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              task['priority'],
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: priorityColor,
                              ),
                            ),
                          ),
                        ],
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