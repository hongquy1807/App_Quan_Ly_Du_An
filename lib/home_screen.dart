import 'package:flutter/material.dart';
import 'services/home_service.dart';
import 'services/auth_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final _homeService = HomeService();

  // notifications state
  List<Map<String, dynamic>> notifications = [];

  // state populated from API
  String userName = '';
  String avatarUrl = '';
  List<Map<String, dynamic>> projects = [];
  List<Map<String, dynamic>> _tasks = [];
  int unreadNotifications = 0;
  bool _loading = true;

  List<Map<String, dynamic>> get tasks => _tasks;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _loading = true;
    });

    try {
      final data = await _homeService.getDashboard();

      final user = data['user'] as Map<String, dynamic>?;
      final stats = data['stats'] as Map<String, dynamic>?;
      final apiProjects = (data['projects'] as List<dynamic>?) ?? [];
      final apiTasks = (data['tasks'] as List<dynamic>?) ?? [];
      final apiNotifications = (data['notifications'] as List<dynamic>?) ?? [];

      setState(() {
        userName = user?['name']?.toString() ?? '';
        avatarUrl = '';
        unreadNotifications = (() {
          final val = stats?['unreadNotifications'];
          if (val is int) return val;
          if (val is String) return int.tryParse(val) ?? 0;
          return 0;
        })();

        projects = apiProjects.map<Map<String, dynamic>>((p) {
          final map = Map<String, dynamic>.from(p as Map);
          return {
            'id': map['id']?.toString() ?? '',
            'name': map['name'] ?? '',
            'description': map['description'] ?? '',
            'color': map['color'] ?? '#6366F1',
            'icon': Icons.folder_open_rounded,
            'totalTasks': map['totalTasks'] ?? map['total_tasks'] ?? 0,
            'completedTasks': map['completedTasks'] ?? map['completed_tasks'] ?? 0,
          };
        }).toList();

        _tasks = apiTasks.map<Map<String, dynamic>>((t) {
          final map = Map<String, dynamic>.from(t as Map);
          DateTime? due;
          try {
            due = map['due_date'] != null
                ? DateTime.parse(map['due_date'].toString())
                : null;
          } catch (_) {
            due = null;
          }

          return {
            'id': map['id']?.toString() ?? '',
            'title': map['title'] ?? '',
            'dueDate': due ?? DateTime.now().add(const Duration(days: 7)),
            'projectName': map['projectName'] ?? map['project_name'] ?? '',
            'projectColor': map['projectColor'] ?? map['project_color'] ?? '#6366F1',
            'isCompleted': map['isCompleted'] ?? map['is_completed'] ?? false,
          };
        }).toList();

        notifications = apiNotifications.map<Map<String, dynamic>>((n) {
          final map = Map<String, dynamic>.from(n as Map);
          return {
            'id': map['id']?.toString() ?? '',
            'type': map['type'] ?? 'general',
            'content': map['content'] ?? '',
            'data': map['data'],
            'read': map['read'] == true || map['read'] == 1,
            'created_at': map['created_at'] ?? '',
          };
        }).toList();

        _loading = false;
      });
    } on ApiException catch (err) {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err.message)),
      );
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể tải dữ liệu trang chủ.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final incompleteTasks = tasks.where((t) => !t['isCompleted']).toList();
    incompleteTasks.sort(
      (a, b) => (a['dueDate'] as DateTime).compareTo(b['dueDate'] as DateTime),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // ============ HEADER ============
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 20,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Avatar với gradient border
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: CircleAvatar(
                      radius: 25,
                      backgroundColor: const Color(0xFFE5E7EB),
                      child: Text(
                        userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF6366F1),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.wb_sunny,
                              size: 14,
                              color: Color(0xFFF59E0B),
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Chúc bạn làm việc hiệu quả!',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF6B7280),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Icon thông báo với badge
                  Stack(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(14),
                        ),
                          child: IconButton(
                            icon: const Icon(Icons.notifications_none),
                            color: const Color(0xFF1F2937),
                            onPressed: _showNotificationsPanel,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                      ),
                      if (unreadNotifications > 0)
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            height: 18,
                            decoration: const BoxDecoration(
                              color: Color(0xFFEF4444),
                              borderRadius: BorderRadius.all(Radius.circular(9)),
                            ),
                            child: Center(
                              child: Text(
                                unreadNotifications > 99 ? '99+' : unreadNotifications.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // ============ NỘI DUNG CHÍNH ============
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ----- THÔNG TIN NHANH -----
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF6366F1),
                            Color(0xFF8B5CF6),
                            Color(0xFFA78BFA),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF6366F1,
                            ).withValues(alpha: 0.3),
                            spreadRadius: 2,
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildStatItem(
                            icon: Icons.folder_open_rounded,
                            value: projects.length.toString(),
                            label: 'Dự án đã tham gia',
                          ),
                          Container(
                            width: 1,
                            height: 50,
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                          _buildStatItem(
                            icon: Icons.pending_actions_rounded,
                            value: incompleteTasks.length.toString(),
                            label: 'Task chưa hoàn thành',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ----- DỰ ÁN CỦA BẠN -----
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Text(
                              '📁 Dự án của bạn',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6366F1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                projects.length.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        TextButton(
                          onPressed: () {},
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'Xem tất cả →',
                            style: TextStyle(
                              color: Color(0xFF6366F1),
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 140,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: projects.length,
                        itemBuilder: (context, index) {
                          final project = projects[index];
                          final projectColorHex =
                              'FF${project['color']!.substring(1)}';
                          final progress = project['totalTasks'] > 0
                              ? project['completedTasks'] /
                                    project['totalTasks']
                              : 0.0;

                          return Container(
                            width: 180,
                            margin: const EdgeInsets.only(right: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withValues(alpha: 0.08),
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
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Color(
                                          int.parse(projectColorHex, radix: 16),
                                        ).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        project['icon'],
                                        size: 18,
                                        color: Color(
                                          int.parse(projectColorHex, radix: 16),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        project['name'],
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                          color: Color(0xFF1F2937),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const Spacer(),
                                Text(
                                  project['description'],
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF6B7280),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: LinearProgressIndicator(
                                          value: progress,
                                          backgroundColor: const Color(
                                            0xFFF3F4F6,
                                          ),
                                          color: Color(
                                            int.parse(
                                              projectColorHex,
                                              radix: 16,
                                            ),
                                          ),
                                          minHeight: 6,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${(progress * 100).round()}%',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF6B7280),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ----- NHIỆM VỤ CỦA BẠN -----
                    Row(
                      children: [
                        const Text(
                          '📋  Nhiệm vụ của bạn',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            incompleteTasks.length.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (incompleteTasks.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              size: 56,
                              color: const Color(
                                0xFF6B7280,
                              ).withValues(alpha: 0.3),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              '🎉 Không có nhiệm vụ nào!',
                              style: TextStyle(
                                color: Color(0xFF6B7280),
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Column(
                        children: incompleteTasks.map((task) {
                          final dueDate = task['dueDate'] as DateTime;
                          final isOverdue = dueDate.isBefore(DateTime.now());
                          final projectColor = Color(
                            int.parse(
                              'FF${task['projectColor']!.substring(1)}',
                              radix: 16,
                            ),
                          );

                          return Container(
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
                            child: Row(
                              children: [
                                // Trạng thái
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color:
                                        (isOverdue
                                                ? const Color(0xFFEF4444)
                                                : const Color(0xFF10B981))
                                            .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    isOverdue
                                        ? Icons.warning_amber_rounded
                                        : Icons.hourglass_top_rounded,
                                    color: isOverdue
                                        ? const Color(0xFFEF4444)
                                        : const Color(0xFF10B981),
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                // Thông tin
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        task['title'],
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF1F2937),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 6),

                                      // Tên dự án
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: projectColor.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          task['projectName'],
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w500,
                                            color: projectColor,
                                          ),
                                        ),
                                      ),

                                      const SizedBox(height: 6),

                                      // Thời gian
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.access_time_rounded,
                                            size: 14,
                                            color: Color(0xFF6B7280),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${dueDate.day.toString().padLeft(2, '0')}/${dueDate.month.toString().padLeft(2, '0')}',
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
                                ),
                                // Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: isOverdue
                                          ? [
                                              const Color(0xFFEF4444),
                                              const Color(0xFFDC2626),
                                            ]
                                          : [
                                              const Color(0xFF10B981),
                                              const Color(0xFF059669),
                                            ],
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            (isOverdue
                                                    ? const Color(0xFFEF4444)
                                                    : const Color(0xFF10B981))
                                                .withValues(alpha: 0.3),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    isOverdue ? 'Quá hạn' : 'Đang làm',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 20),
                  ],
                      ),
                    ),
            ),
          ],
        ),
      ),
      // ============ BOTTOM NAVIGATION ============
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });

            // Xử lý điều hướng
            switch (index) {
              case 0:
                Navigator.pushReplacementNamed(context, '/home');
                break;
              case 1:
                Navigator.pushReplacementNamed(context, '/projects');
                break;
              case 2:
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('📩 Tin nhắn')),
                );
                break;
              case 3:
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('👤 Profile')),
                );
                break;
            }
          },
          type: BottomNavigationBarType.fixed,
          selectedItemColor: const Color(0xFF6366F1),
          unselectedItemColor: const Color(0xFF9CA3AF),
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded),
              activeIcon: Icon(Icons.home_rounded),
              label: 'Trang chủ',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.folder_rounded),
              activeIcon: Icon(Icons.folder_rounded),
              label: 'Dự án',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.chat_rounded),
              activeIcon: Icon(Icons.chat_rounded),
              label: 'Tin nhắn',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_rounded),
              activeIcon: Icon(Icons.person_rounded),
              label: 'Tôi',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showNotificationsPanel() async {
    try {
      // Fetch latest notifications from API
      final svc = _homeService;
      final resp = await svc.getNotifications(page: 1, limit: 20);
      final fetched = resp['data']?['notifications'] as List<dynamic>?;
      if (fetched != null) {
        setState(() {
          notifications = fetched.map<Map<String, dynamic>>((n) {
            final map = Map<String, dynamic>.from(n as Map);
            return {
              'id': map['id']?.toString() ?? '',
              'type': map['type'] ?? 'general',
              'content': map['content'] ?? '',
              'data': map['data'],
              'read': map['read'] == true || map['read'] == 1,
              'created_at': map['created_at'] ?? '',
            };
          }).toList();
        });
      }

      // Show a top-right aligned dialog panel
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (ctx) => Dialog(
          elevation: 0,
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.only(top: 60, right: 12, left: 12),
          child: Align(
            alignment: Alignment.topRight,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360, maxHeight: 420),
              child: Material(
                borderRadius: BorderRadius.circular(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                        color: Color(0xFFF9FAFB),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Thông báo', style: TextStyle(fontWeight: FontWeight.bold)),
                          IconButton(
                            icon: const Icon(Icons.mark_email_read_rounded),
                            onPressed: () async {
                              await svc.markAllNotificationsRead();
                              setState(() {
                                for (var n in notifications) {
                                  n['read'] = true;
                                }
                                unreadNotifications = 0;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: notifications.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(20),
                              child: Text('Không có thông báo.'),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              padding: const EdgeInsets.all(8),
                              itemCount: notifications.length,
                              separatorBuilder: (context, index) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final n = notifications[index];
                                return ListTile(
                                  tileColor: n['read'] ? null : const Color(0xFFF5F3FF),
                                  title: Text(n['content'] ?? ''),
                                  subtitle: Text(n['created_at']?.toString() ?? ''),
                                  onTap: () async {
                                    if (n['read'] == false) {
                                      try {
                                        await svc.markNotificationRead(int.parse(n['id'].toString()), true);
                                        setState(() {
                                          n['read'] = true;
                                          if (unreadNotifications > 0) unreadNotifications -= 1;
                                        });
                                      } catch (_) {}
                                    }
                                  },
                                );
                              },
                            ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Đóng'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    } on ApiException catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err.message)));
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không thể tải thông báo.')));
    }
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.9),
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}
