import 'package:flutter/material.dart';
import 'project_detail_screen.dart';
import 'utils/color_utils.dart';

class ProjectScreen extends StatefulWidget {
  const ProjectScreen({super.key});

  @override
  State<ProjectScreen> createState() => _ProjectScreenState();
}

class _ProjectScreenState extends State<ProjectScreen> {
  // Biến sắp xếp
  bool _isAscending = true;
  int _currentIndex = 2;

  final List<Map<String, String>> _projectInvitations = [
    {
      'projectName': 'Dashboard quản lý',
      'inviterName': 'Trần Thị B',
      'inviterEmail': 'tranthib@email.com',
    },
    {
      'projectName': 'Ứng dụng đặt lịch',
      'inviterName': 'Lê Văn C',
      'inviterEmail': 'levanc@email.com',
    },
    {
      'projectName': 'Hệ thống báo cáo',
      'inviterName': 'Phạm Thị D',
      'inviterEmail': 'phamthid@email.com',
    },
  ];

  // Danh sách dự án
  final List<Map<String, dynamic>> _projects = [
    {
      'id': '1',
      'name': 'App di động',
      'description': 'Phát triển ứng dụng Flutter',
      'color': '#6366F1',
      'icon': Icons.folder_open_rounded,
      'totalTasks': 10,
      'completedTasks': 6,
      'members': 5,
      'createdAt': DateTime(2024, 1, 15),
    },
    {
      'id': '2',
      'name': 'Website bán hàng',
      'description': 'E-commerce platform',
      'color': '#EC4899',
      'icon': Icons.folder_open_rounded,
      'totalTasks': 8,
      'completedTasks': 3,
      'members': 3,
      'createdAt': DateTime(2024, 2, 20),
    },
    {
      'id': '3',
      'name': 'Dự án AI',
      'description': 'Machine Learning model',
      'color': '#F59E0B',
      'icon': Icons.folder_open_rounded,
      'totalTasks': 5,
      'completedTasks': 1,
      'members': 4,
      'createdAt': DateTime(2024, 3, 10),
    },
    {
      'id': '4',
      'name': 'Hệ thống CRM',
      'description': 'Customer Relationship Management',
      'color': '#10B981',
      'icon': Icons.folder_open_rounded,
      'totalTasks': 12,
      'completedTasks': 8,
      'members': 6,
      'createdAt': DateTime(2024, 4, 5),
    },
    {
      'id': '5',
      'name': 'App IoT',
      'description': 'Internet of Things platform',
      'color': '#8B5CF6',
      'icon': Icons.folder_open_rounded,
      'totalTasks': 7,
      'completedTasks': 2,
      'members': 3,
      'createdAt': DateTime(2024, 5, 1),
    },
  ];

  // HĂ m thĂªm dá»± Ă¡n má»›i
  void _addProject(Map<String, dynamic> newProject) {
    setState(() {
      _projects.add(newProject);
      _sortProjects();
    });
  }

  // HĂ m xĂ³a dá»± Ă¡n
  void _deleteProject(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Xóa dự án',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
          ),
        ),
        content: const Text(
          'Bạn có chắc chắn muốn xóa dự án này không?',
          style: TextStyle(color: Color(0xFF6B7280)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Hủy',
              style: TextStyle(color: Color(0xFF6B7280)),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _projects.removeWhere((project) => project['id'] == id);
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Đã xóa dự án thành công'),
                  backgroundColor: Color(0xFFEF4444),
                ),
              );
            },
            child: const Text(
              'Xóa',
              style: TextStyle(color: Color(0xFFEF4444)),
            ),
          ),
        ],
      ),
    );
  }

  // HĂ m sáº¯p xáº¿p dá»± Ă¡n
  void _sortProjects() {
    _projects.sort((a, b) {
      final nameA = a['name'].toLowerCase();
      final nameB = b['name'].toLowerCase();
      return _isAscending ? nameA.compareTo(nameB) : nameB.compareTo(nameA);
    });
  }

  // HĂ m hiá»ƒn thá»‹ dialog táº¡o dá»± Ă¡n
  void _showCreateProjectDialog() {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final List<Color> colors = [
      const Color(0xFF6366F1),
      const Color(0xFFEC4899),
      const Color(0xFFF59E0B),
      const Color(0xFF10B981),
      const Color(0xFF8B5CF6),
      const Color(0xFFEF4444),
      const Color(0xFF3B82F6),
    ];
    int selectedColorIndex = 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateBottomSheet) {
          return Container(
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Tạo dự án mới',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Điền thông tin để tạo dự án mới',
                      style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
                    ),
                    const SizedBox(height: 24),

                    // TĂªn dá»± Ă¡n
                    const Text(
                      'Tên dự án',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF374151),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: nameController,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Color(0xFF1F2937),
                      ),
                      decoration: InputDecoration(
                        hintText: 'Nhập tên dự án',
                        hintStyle: const TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Color(0xFFE5E7EB),
                            width: 1.5,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Color(0xFFE5E7EB),
                            width: 1.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Color(0xFF6366F1),
                            width: 2,
                          ),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF9FAFB),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Vui lòng nhập tên dự án';
                        }
                        if (value.length < 3) {
                          return 'Tên dự án phải có ít nhất 3 ký tự';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // MĂ´ táº£
                    const Text(
                      'Mô tả',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF374151),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: descriptionController,
                      maxLines: 3,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Color(0xFF1F2937),
                      ),
                      decoration: InputDecoration(
                        hintText: 'Nhập mô tả dự án',
                        hintStyle: const TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Color(0xFFE5E7EB),
                            width: 1.5,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Color(0xFFE5E7EB),
                            width: 1.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Color(0xFF6366F1),
                            width: 2,
                          ),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF9FAFB),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Vui lòng nhập mô tả';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Chá»n mĂ u
                    const Text(
                      'Màu sắc',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF374151),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 40,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: colors.length,
                        itemBuilder: (context, index) {
                          final isSelected = selectedColorIndex == index;
                          return GestureDetector(
                            onTap: () {
                              setStateBottomSheet(() {
                                selectedColorIndex = index;
                              });
                            },
                            child: Container(
                              width: 40,
                              height: 40,
                              margin: const EdgeInsets.only(right: 10),
                              decoration: BoxDecoration(
                                color: colors[index],
                                shape: BoxShape.circle,
                                border: isSelected
                                    ? Border.all(
                                        color: const Color(0xFF1F2937),
                                        width: 3,
                                      )
                                    : null,
                              ),
                              child: isSelected
                                  ? const Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 20,
                                    )
                                  : null,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Button táº¡o
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: () {
                          if (formKey.currentState?.validate() ?? false) {
                            final colorObj = colors[selectedColorIndex];
                            final rVal = (colorObj.r * 255).round().clamp(
                              0,
                              255,
                            );
                            final gVal = (colorObj.g * 255).round().clamp(
                              0,
                              255,
                            );
                            final bVal = (colorObj.b * 255).round().clamp(
                              0,
                              255,
                            );
                            final colorHex =
                                '${rVal.toRadixString(16).padLeft(2, '0')}${gVal.toRadixString(16).padLeft(2, '0')}${bVal.toRadixString(16).padLeft(2, '0')}';
                            final newProject = {
                              'id': DateTime.now().millisecondsSinceEpoch
                                  .toString(),
                              'name': nameController.text.trim(),
                              'description': descriptionController.text.trim(),
                              'color': '#$colorHex',
                              'icon': Icons.folder_open_rounded,
                              'totalTasks': 0,
                              'completedTasks': 0,
                              'members': 1,
                              'createdAt': DateTime.now(),
                            };

                            _addProject(newProject);
                            Navigator.pop(context);

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Đã tạo dự án "${nameController.text}" thành công!',
                                ),
                                backgroundColor: const Color(0xFF10B981),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_rounded, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Tạo dự án',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _sortProjects();
  }

  @override
  Widget build(BuildContext context) {
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
                  const Text(
                    'Dự án',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Quản lý tất cả dự án của bạn',
                    style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            _buildBodyActions(),
            const SizedBox(height: 16),

            // Danh sĂ¡ch dá»± Ă¡n
            Expanded(
              child: _projects.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.folder_open_rounded,
                            size: 80,
                            color: const Color(
                              0xFF6B7280,
                            ).withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Chưa có dự án nào',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Nhấn nút "+" để tạo dự án mới',
                            style: TextStyle(
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
                      itemCount: _projects.length,
                      itemBuilder: (context, index) {
                        final project = _projects[index];
                        return _buildProjectCard(project);
                      },
                    ),
            ),
          ],
        ),
      ),
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

            switch (index) {
              case 0:
                Navigator.pushReplacementNamed(context, '/home');
                break;
              case 1:
                Navigator.pushReplacementNamed(context, '/timeline');
                break;
              case 2:
                Navigator.pushReplacementNamed(context, '/projects');
                break;
              case 3:
                Navigator.pushReplacementNamed(context, '/chat');
                break;
              case 4:

                Navigator.pushReplacementNamed(context, '/profile');

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
              icon: Icon(Icons.calendar_month_rounded),
              activeIcon: Icon(Icons.calendar_month_rounded),
              label: 'Lịch',
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

  Widget _buildBodyActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _buildActionTile(
            icon: Icons.folder_open_rounded,
            title: _projects.length.toString(),
            subtitle: 'Tổng dự án',
            onTap: () {},
            emphasizeTitle: true,
          ),
          const SizedBox(width: 8),
          _buildActionTile(
            icon: Icons.person_add_alt_1_rounded,
            title: '',
            subtitle: 'Lời mời',
            onTap: _showProjectInvitationsDialog,
          ),
          const SizedBox(width: 8),
          _buildActionTile(
            icon: Icons.add_rounded,
            title: '',
            subtitle: 'Thêm dự án',
            onTap: () {},
          ),
          const SizedBox(width: 8),
          _buildActionTile(
            icon: _isAscending
                ? Icons.arrow_upward_rounded
                : Icons.arrow_downward_rounded,
            title: '',
            subtitle: 'Sắp xếp',
            onTap: () {
              setState(() {
                _isAscending = !_isAscending;
                _sortProjects();
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool emphasizeTitle = false,
  }) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          height: 82,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
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
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (title.isNotEmpty)
                Text(
                  title,
                  style: TextStyle(
                    fontSize: emphasizeTitle ? 22 : 16,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF6366F1),
                  ),
                )
              else
                Icon(icon, color: const Color(0xFF6366F1), size: 24),
              const SizedBox(height: 6),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showProjectInvitationsDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420, maxHeight: 560),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.person_add_alt_1_rounded,
                      color: Color(0xFF6366F1),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Lời mời tham gia',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    color: const Color(0xFF6B7280),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Flexible(
                child: _projectInvitations.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 36),
                          child: Text(
                            'Chưa có lời mời mới',
                            style: TextStyle(color: Color(0xFF6B7280)),
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        physics: const BouncingScrollPhysics(),
                        itemCount: _projectInvitations.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          return _buildInvitationCard(
                            _projectInvitations[index],
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInvitationCard(Map<String, String> invitation) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.folder_shared_rounded,
              color: Color(0xFF6366F1),
              size: 26,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  invitation['projectName'] ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  invitation['inviterName'] ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF4B5563),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  invitation['inviterEmail'] ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Row(
            children: [
              _buildInvitationActionButton(
                icon: Icons.close_rounded,
                color: const Color(0xFFEF4444),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đã từ chối lời mời')),
                  );
                },
              ),
              const SizedBox(width: 8),
              _buildInvitationActionButton(
                icon: Icons.check_rounded,
                color: const Color(0xFF10B981),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đã xác nhận lời mời')),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInvitationActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  Widget _buildProjectCard(Map<String, dynamic> project) {
    final color = parseHexColor(project['color']);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProjectDetailScreen(project: project),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
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
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(project['icon'], color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        project['name'],
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        project['description'],
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF6B7280),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                PopupMenuButton(
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    color: Color(0xFF6B7280),
                  ),
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(
                            Icons.edit_rounded,
                            color: Color(0xFF6366F1),
                            size: 20,
                          ),
                          SizedBox(width: 10),
                          Text('Sửa'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_rounded,
                            color: Color(0xFFEF4444),
                            size: 20,
                          ),
                          SizedBox(width: 10),
                          Text('Xóa'),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (value) {
                    if (value == 'delete') {
                      _deleteProject(project['id']);
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
