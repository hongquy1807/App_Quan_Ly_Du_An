import 'package:flutter/material.dart';
import 'utils/color_utils.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  // Danh sách dự án
  final List<Map<String, dynamic>> _projects = [
    {
      'id': '1',
      'name': 'App di động',
      'color': '#6366F1',
      'icon': Icons.phone_android,
      'members': [
        {'id': '1', 'name': 'Nguyễn Văn A', 'avatar': '', 'online': true},
        {'id': '2', 'name': 'Trần Thị B', 'avatar': '', 'online': true},
        {'id': '3', 'name': 'Lê Văn C', 'avatar': '', 'online': false},
        {'id': '4', 'name': 'Phạm Thị D', 'avatar': '', 'online': true},
      ],
      'lastMessage': 'Đã nhận được file thiết kế, cảm ơn bạn!',
      'lastTime': DateTime.now().subtract(const Duration(minutes: 5)),
      'unreadCount': 3,
    },
    {
      'id': '2',
      'name': 'Website bán hàng',
      'color': '#EC4899',
      'icon': Icons.shopping_cart,
      'members': [
        {'id': '5', 'name': 'Nguyễn Văn E', 'avatar': '', 'online': false},
        {'id': '6', 'name': 'Trần Thị F', 'avatar': '', 'online': true},
        {'id': '7', 'name': 'Lê Văn G', 'avatar': '', 'online': false},
      ],
      'lastMessage': 'Khi nào deploy lên production?',
      'lastTime': DateTime.now().subtract(const Duration(hours: 2)),
      'unreadCount': 0,
    },
    {
      'id': '3',
      'name': 'Dự án AI',
      'color': '#F59E0B',
      'icon': Icons.psychology,
      'members': [
        {'id': '8', 'name': 'Phạm Thị H', 'avatar': '', 'online': true},
        {'id': '9', 'name': 'Hoàng Văn I', 'avatar': '', 'online': false},
        {'id': '10', 'name': 'Ngô Thị K', 'avatar': '', 'online': true},
      ],
      'lastMessage': 'Model đã đạt accuracy 95%',
      'lastTime': DateTime.now().subtract(const Duration(days: 1)),
      'unreadCount': 5,
    },
  ];

  // Trạng thái hiện tại
  Map<String, dynamic>? _selectedProject;
  List<Map<String, dynamic>> _messages = [];
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;

  // Danh sách file đính kèm
  final List<Map<String, dynamic>> _attachments = [];

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  void _loadMessages() {
    // Giả lập dữ liệu tin nhắn
    _messages = [
      {
        'id': '1',
        'sender': 'Nguyễn Văn A',
        'senderId': '1',
        'content':
            'Chào mọi người! Hôm nay chúng ta sẽ bàn về thiết kế UI nhé.',
        'time': DateTime.now().subtract(const Duration(hours: 3)),
        'isMine': true,
        'type': 'text',
      },
      {
        'id': '2',
        'sender': 'Trần Thị B',
        'senderId': '2',
        'content': 'Tôi đã có bản thiết kế sơ bộ, mọi người xem thử nhé.',
        'time': DateTime.now().subtract(const Duration(hours: 2, minutes: 30)),
        'isMine': false,
        'type': 'text',
      },
      {
        'id': '3',
        'sender': 'Trần Thị B',
        'senderId': '2',
        'content': 'file_design.png',
        'time': DateTime.now().subtract(const Duration(hours: 2, minutes: 25)),
        'isMine': false,
        'type': 'image',
      },
      {
        'id': '4',
        'sender': 'Lê Văn C',
        'senderId': '3',
        'content':
            'Giao diện đẹp quá! Tôi thấy phần header hơi to, có thể chỉnh lại được không?',
        'time': DateTime.now().subtract(const Duration(hours: 2)),
        'isMine': false,
        'type': 'text',
      },
      {
        'id': '5',
        'sender': 'Nguyễn Văn A',
        'senderId': '1',
        'content': 'Đã nhận được file thiết kế, cảm ơn bạn!',
        'time': DateTime.now().subtract(const Duration(minutes: 5)),
        'isMine': true,
        'type': 'text',
      },
      {
        'id': '6',
        'sender': 'Phạm Thị D',
        'senderId': '4',
        'content': 'Tôi sẽ điều chỉnh lại phần header theo góp ý.',
        'time': DateTime.now().subtract(const Duration(minutes: 2)),
        'isMine': false,
        'type': 'text',
      },
    ];
  }

  void _sendMessage({String? filePath, String? fileType}) {
    final content = _messageController.text.trim();
    if (content.isEmpty && _attachments.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    // Giả lập gửi tin nhắn
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;

      final newMessage = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'sender': 'Nguyễn Văn A',
        'senderId': '1',
        'content': content.isNotEmpty ? content : 'Đã gửi một file đính kèm',
        'time': DateTime.now(),
        'isMine': true,
        'type': content.isNotEmpty ? 'text' : 'file',
      };

      setState(() {
        _messages.add(newMessage);
        _messageController.clear();
        _attachments.clear();
        _isLoading = false;
      });

      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Đính kèm file',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildAttachmentOption(
                  icon: Icons.image_rounded,
                  label: 'Hình ảnh',
                  color: const Color(0xFF6366F1),
                  onTap: () {
                    Navigator.pop(context);
                    _showSnackbar('Chọn hình ảnh từ thư viện');
                  },
                ),
                _buildAttachmentOption(
                  icon: Icons.video_camera_back_rounded,
                  label: 'Video',
                  color: const Color(0xFFEC4899),
                  onTap: () {
                    Navigator.pop(context);
                    _showSnackbar('Chọn video từ thư viện');
                  },
                ),
                _buildAttachmentOption(
                  icon: Icons.insert_drive_file_rounded,
                  label: 'Tài liệu',
                  color: const Color(0xFFF59E0B),
                  onTap: () {
                    Navigator.pop(context);
                    _showSnackbar('Chọn tài liệu từ thiết bị');
                  },
                ),
                _buildAttachmentOption(
                  icon: Icons.mic_rounded,
                  label: 'Ghi âm',
                  color: const Color(0xFF10B981),
                  onTap: () {
                    Navigator.pop(context);
                    _showSnackbar('Bắt đầu ghi âm');
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, size: 28, color: color),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF6366F1),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) {
      return 'Vừa xong';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes} phút';
    } else if (diff.inDays < 1) {
      return '${diff.inHours} giờ';
    } else {
      return '${diff.inDays} ngày';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            if (_selectedProject == null)
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
                  const Icon(
                    Icons.chat_rounded,
                    color: Color(0xFF6366F1),
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tin nhắn',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                        Text(
                          'Nhắn tin theo dự án',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // N?t t?m ki?m
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.search_rounded,
                      color: Color(0xFF6B7280),
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
            if (_selectedProject == null) const SizedBox(height: 16),

            // N?i dung ch?nh
            Expanded(
              child: _selectedProject == null
                  ? _buildProjectList()
                  : _buildChatDetail(),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _selectedProject == null
          ? _buildBottomNavigationBar()
          : null,
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
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
        currentIndex: 3,
        onTap: (index) {
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
    );
  }

  Widget _buildProjectList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _projects.length,
      itemBuilder: (context, index) {
        final project = _projects[index];
        final color = parseHexColor(project['color']);
        final onlineCount = (project['members'] as List)
            .where((m) => m['online'])
            .length;

        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedProject = project;
              _loadMessages();
            });
            _scrollToBottom();
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
            child: Row(
              children: [
                // Icon d? ?n
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(project['icon'], color: color, size: 28),
                ),
                const SizedBox(width: 14),
                // Th?ng tin
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              project['name'],
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                          ),
                          if (project['unreadCount'] > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                project['unreadCount'].toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        project['lastMessage'],
                        style: TextStyle(
                          fontSize: 13,
                          color: project['unreadCount'] > 0
                              ? const Color(0xFF1F2937)
                              : const Color(0xFF6B7280),
                          fontWeight: project['unreadCount'] > 0
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.people_rounded,
                            size: 14,
                            color: const Color(0xFF6B7280),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$onlineCount/${project['members'].length} online',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _formatTime(project['lastTime']),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF9CA3AF),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF9CA3AF),
                  size: 24,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildChatDetail() {
    final project = _selectedProject!;
    final color = parseHexColor(project['color']);
    final onlineCount = (project['members'] as List)
        .where((m) => m['online'])
        .length;

    return Column(
      children: [
        // Header chat
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedProject = null;
                  });
                },
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Color(0xFF1F2937),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 40,
                height: 40,
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
                    Text(
                      '$onlineCount thành viên online',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
              ),
              // N?t th?ng tin d? ?n
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.info_outline_rounded,
                  color: Color(0xFF6B7280),
                  size: 22,
                ),
              ),
            ],
          ),
        ),

        // Danh s?ch tin nh?n
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final message = _messages[index];
              final isMine = message['isMine'];
              final time = message['time'] as DateTime;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  mainAxisAlignment: isMine
                      ? MainAxisAlignment.end
                      : MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (!isMine)
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: const Color(0xFF8B5CF6),
                        child: Text(
                          message['sender'][0],
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    if (!isMine) const SizedBox(width: 8),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: isMine
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        children: [
                          if (!isMine)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                message['sender'],
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF6B7280),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isMine
                                  ? const Color(0xFF6366F1)
                                  : Colors.white,
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(isMine ? 16 : 4),
                                topRight: Radius.circular(isMine ? 4 : 16),
                                bottomLeft: const Radius.circular(16),
                                bottomRight: const Radius.circular(16),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withValues(alpha: 0.04),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (message['type'] == 'image')
                                  Container(
                                    width: 200,
                                    height: 150,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(8),
                                      image: const DecorationImage(
                                        image: NetworkImage(
                                          'https://via.placeholder.com/200x150/6366F1/FFFFFF?text=Image',
                                        ),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                if (message['type'] == 'text' ||
                                    message['type'] == 'file')
                                  Text(
                                    message['content'],
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isMine
                                          ? Colors.white
                                          : const Color(0xFF1F2937),
                                      height: 1.4,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              _formatTime(time),
                              style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFF9CA3AF),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isMine) const SizedBox(width: 8),
                    if (isMine)
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: const Color(0xFF6366F1),
                        child: const Text(
                          'A',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),

        // Input message
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              // N?t ??nh k?m
              IconButton(
                onPressed: _showAttachmentOptions,
                icon: const Icon(
                  Icons.attach_file_rounded,
                  color: Color(0xFF6B7280),
                  size: 26,
                ),
              ),
              // Input
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Nhập tin nhắn...',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF1F2937),
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
              ),
              // N?t g?i
              Container(
                margin: const EdgeInsets.only(left: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: IconButton(
                  onPressed: _isLoading ? null : _sendMessage,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
