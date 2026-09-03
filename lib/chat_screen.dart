import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme_controller.dart';
import 'services/auth_service.dart';
import 'services/chatbot_service.dart';
import 'services/project_chat_service.dart';
import 'utils/color_utils.dart';
import 'widgets/app_bottom_navigation.dart';

enum ChatLanguage { vietnamese, english, chinese }

class ChatScreen extends StatefulWidget {
  final bool showBottomNavigation;

  const ChatScreen({super.key, this.showBottomNavigation = true});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ProjectChatService _chatService = ProjectChatService();
  final ChatbotService _chatbotService = ChatbotService();
  // Danh sách dự án
  final List<Map<String, dynamic>> _projects = [
    {
      'id': '1',
      'name': 'App di động',
      'color': '#6366F1',
      'icon': Icons.forum_rounded,
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
      'icon': Icons.forum_rounded,
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
      'icon': Icons.forum_rounded,
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
  final List<Map<String, dynamic>> _friends = [];
  Map<String, dynamic>? _selectedProject;
  ChatLanguage _language = ChatLanguage.vietnamese;
  bool _showChatbot = false;
  bool _showFriendChats = false;
  List<Map<String, dynamic>> _messages = [];
  final List<Map<String, dynamic>> _botMessages = [];
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _botMessageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ScrollController _botScrollController = ScrollController();
  bool _isLoading = false;
  bool _isBotLoading = false;
  bool _isLoadingProjects = false;
  bool _isLoadingFriends = false;
  bool _isLoadingMessages = false;
  String? _projectError;
  String? _friendError;
  String? _messageError;
  Timer? _projectPollTimer;
  Timer? _messagePollTimer;

  // Danh sách file đính kèm
  final List<Map<String, dynamic>> _attachments = [];

  @override
  void initState() {
    super.initState();
    _loadLanguage();
    _loadBotMessages();
    _loadProjects();
    _loadFriends();
    _projectPollTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) {
        if (!mounted || _showChatbot || _selectedProject != null) return;
        if (_showFriendChats) {
          _loadFriends(silent: true);
        } else {
          _loadProjects(silent: true);
        }
      },
    );
    _messagePollTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) {
        if (!mounted || _showChatbot || _selectedProject == null) return;
        _loadMessages(silent: true);
      },
    );
  }

  String _t(String vi, String en, String zh) {
    switch (_language) {
      case ChatLanguage.vietnamese:
        return vi;
      case ChatLanguage.english:
        return en;
      case ChatLanguage.chinese:
        return zh;
    }
  }

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final rawValue = prefs.getString('app_language');
    if (!mounted) return;
    setState(() {
      _language = ChatLanguage.values.firstWhere(
        (language) => language.name == rawValue,
        orElse: () => ChatLanguage.vietnamese,
      );
      _loadBotMessages();
      _loadMessages();
    });
  }

  void _loadBotMessages() {
    _botMessages
      ..clear()
      ..add({
        'content': _t(
          'Chào bạn, mình có thể hỗ trợ tóm tắt công việc, nhắc deadline, gợi ý chia nhiệm vụ hoặc trả lời các câu hỏi về quản lý dự án.',
          'Hi, I can help summarize work, remind you about deadlines, suggest task breakdowns, or answer project management questions.',
          '你好，我可以帮你总结工作、提醒截止日期、建议任务拆分，或回答项目管理相关问题。',
        ),
        'isMine': false,
        'time': null,
      });
  }

  @override
  void dispose() {
    _projectPollTimer?.cancel();
    _messagePollTimer?.cancel();
    _messageController.dispose();
    _botMessageController.dispose();
    _scrollController.dispose();
    _botScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadProjects({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoadingProjects = true;
        _projectError = null;
      });
    }

    try {
      final projects = await _chatService.getProjects();
      if (!mounted) return;
      setState(() {
        _projects
          ..clear()
          ..addAll(projects
              .where((project) =>
                  project['status']?.toString().toLowerCase() != 'completed')
              .map(_mapProject));
        if (!silent) _isLoadingProjects = false;
      });
    } on ApiException catch (err) {
      if (!mounted) return;
      if (silent) return;
      setState(() {
        _projects.clear();
        _projectError = err.message;
        _isLoadingProjects = false;
      });
    }
  }

  Future<void> _loadFriends({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoadingFriends = true;
        _friendError = null;
      });
    }

    try {
      final friends = await _chatService.getFriends();
      if (!mounted) return;
      setState(() {
        _friends
          ..clear()
          ..addAll(friends.map(_mapFriendChat));
        if (!silent) _isLoadingFriends = false;
      });
    } on ApiException catch (err) {
      if (!mounted) return;
      if (silent) return;
      setState(() {
        _friends.clear();
        _friendError = err.message;
        _isLoadingFriends = false;
      });
    }
  }

  Future<void> _loadMessages({bool silent = false}) async {
    final conversation = _selectedProject;
    if (conversation == null) return;
    final conversationId = int.tryParse(conversation['id']?.toString() ?? '');
    if (conversationId == null) return;
    final isDirect = conversation['chatType'] == 'direct';

    if (!silent) {
      setState(() {
        _isLoadingMessages = true;
        _messageError = null;
        _messages.clear();
      });
    }

    try {
      final data = isDirect
          ? await _chatService.getDirectMessages(conversationId)
          : await _chatService.getMessages(conversationId);
      final messages = data['messages'];
      if (!mounted) return;
      setState(() {
        _messages = messages is List
            ? messages
                .whereType<Map>()
                .map((message) => _mapMessage(Map<String, dynamic>.from(message)))
                .toList()
            : [];
        if (!silent) _isLoadingMessages = false;
      });
      if (!silent) _scrollToBottom();
    } on ApiException catch (err) {
      if (!mounted) return;
      if (silent) return;
      setState(() {
        _messageError = err.message;
        _isLoadingMessages = false;
      });
    }
  }

  Map<String, dynamic> _mapProject(Map<String, dynamic> project) {
    final lastMessage = project['last_message'];
    final lastMessageMap = lastMessage is Map
        ? Map<String, dynamic>.from(lastMessage)
        : <String, dynamic>{};
    final projectId = int.tryParse(project['id']?.toString() ?? '') ?? 0;
    const colors = [
      '#6366F1',
      '#EC4899',
      '#F59E0B',
      '#10B981',
      '#8B5CF6',
    ];

    return {
      ...project,
      'id': project['id']?.toString() ?? '',
      'name': project['name']?.toString() ?? _t('Dự án', 'Project', '项目'),
      'color': project['color']?.toString() ?? colors[projectId % colors.length],
      'icon': Icons.forum_rounded,
      'memberCount': int.tryParse(project['member_count']?.toString() ?? '') ?? 0,
      'lastMessage': lastMessageMap['content']?.toString() ??
          _t('Chưa có tin nhắn', 'No messages yet', '暂无消息'),
      'lastTime': _parseDate(lastMessageMap['created_at']) ??
          _parseDate(project['updated_at']) ??
          DateTime.now(),
      'unreadCount': int.tryParse(project['unread_count']?.toString() ?? '') ?? 0,
    };
  }

  Map<String, dynamic> _mapFriendChat(Map<String, dynamic> friend) {
    final lastMessage = friend['last_message'];
    final lastMessageMap = lastMessage is Map
        ? Map<String, dynamic>.from(lastMessage)
        : <String, dynamic>{};
    final friendId = int.tryParse(friend['id']?.toString() ?? '') ?? 0;
    const colors = [
      '#6366F1',
      '#EC4899',
      '#F59E0B',
      '#10B981',
      '#8B5CF6',
    ];

    return {
      ...friend,
      'id': friend['id']?.toString() ?? '',
      'chatType': 'direct',
      'name': friend['name']?.toString() ?? _t('Bạn bè', 'Friend', '好友'),
      'email': friend['email']?.toString() ?? '',
      'color': colors[friendId % colors.length],
      'icon': Icons.person_rounded,
      'memberCount': 2,
      'lastMessage': lastMessageMap['content']?.toString() ??
          _t('Chưa có tin nhắn', 'No messages yet', '暂无消息'),
      'lastTime': _parseDate(lastMessageMap['created_at']) ?? DateTime.now(),
      'unreadCount': int.tryParse(friend['unread_count']?.toString() ?? '') ?? 0,
    };
  }

  Map<String, dynamic> _mapMessage(Map<String, dynamic> message) {
    final type = message['message_type']?.toString() ?? 'text';
    final content = message['content']?.toString();
    final fileName = message['file_name']?.toString();
    final senderName = message['sender_name']?.toString() ??
        _t('Thành viên', 'Member', '成员');

    return {
      'id': message['id']?.toString() ?? '',
      'sender': senderName,
      'senderId': message['sender_id']?.toString() ?? '',
      'content': (content == null || content.isEmpty)
          ? (fileName ?? _t('Tệp đính kèm', 'Attachment', '附件'))
          : content,
      'time': _parseDate(message['created_at']) ?? DateTime.now(),
      'isMine': message['is_mine'] == true,
      'type': type,
    };
  }

  DateTime? _parseDate(dynamic value) {
    final rawValue = value?.toString();
    if (rawValue == null || rawValue.isEmpty) return null;
    return DateTime.tryParse(rawValue)?.toLocal();
  }

  String? _buildAvatarUrl(String? avatarPath) {
    if (avatarPath == null || avatarPath.trim().isEmpty) return null;
    final avatar = avatarPath.trim();
    if (avatar.startsWith('http://') || avatar.startsWith('https://')) {
      return avatar;
    }

    final apiUri = Uri.parse(AuthService.baseUrl);
    final origin = '${apiUri.scheme}://${apiUri.authority}';
    return '$origin$avatar';
  }

  void loadMockMessages() {
    // Giả lập dữ liệu tin nhắn
    _messages = [
      {
        'id': '1',
        'sender': 'Nguyễn Văn A',
        'senderId': '1',
        'content': _t(
          'Chào mọi người! Hôm nay chúng ta sẽ bàn về thiết kế UI nhé.',
          'Hi everyone! Today we will discuss the UI design.',
          '大家好，今天我们来讨论 UI 设计。',
        ),
        'time': DateTime.now().subtract(const Duration(hours: 3)),
        'isMine': true,
        'type': 'text',
      },
      {
        'id': '2',
        'sender': 'Trần Thị B',
        'senderId': '2',
        'content': _t(
          'Tôi đã có bản thiết kế sơ bộ, mọi người xem thử nhé.',
          'I have a draft design ready. Please take a look.',
          '我已经有初步设计稿了，大家看一下。',
        ),
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
        'content': _t(
          'Giao diện đẹp quá! Tôi thấy phần header hơi to, có thể chỉnh lại được không?',
          'The interface looks great! The header feels a bit large. Can we adjust it?',
          '界面很好看。我觉得顶部区域有点大，可以调整一下吗？',
        ),
        'time': DateTime.now().subtract(const Duration(hours: 2)),
        'isMine': false,
        'type': 'text',
      },
      {
        'id': '5',
        'sender': 'Nguyễn Văn A',
        'senderId': '1',
        'content': _t(
          'Đã nhận được file thiết kế, cảm ơn bạn!',
          'Design file received, thank you!',
          '已收到设计文件，谢谢。',
        ),
        'time': DateTime.now().subtract(const Duration(minutes: 5)),
        'isMine': true,
        'type': 'text',
      },
      {
        'id': '6',
        'sender': 'Phạm Thị D',
        'senderId': '4',
        'content': _t(
          'Tôi sẽ điều chỉnh lại phần header theo góp ý.',
          'I will adjust the header based on the feedback.',
          '我会根据反馈调整顶部区域。',
        ),
        'time': DateTime.now().subtract(const Duration(minutes: 2)),
        'isMine': false,
        'type': 'text',
      },
    ];
  }

  Future<void> _sendMessage({String? filePath, String? fileType}) async {
    final content = _messageController.text.trim();
    if (content.isEmpty && _attachments.isEmpty) return;

    final conversation = _selectedProject;
    if (conversation == null) return;
    final conversationId = int.tryParse(conversation['id']?.toString() ?? '');
    if (conversationId == null) return;
    final isDirect = conversation['chatType'] == 'direct';

    final fallbackContent = _t(
      'Đã gửi một file đính kèm',
      'Sent an attachment',
      '已发送一个附件',
    );

    setState(() {
      _isLoading = true;
    });

    try {
      final message = isDirect
          ? await _chatService.sendDirectMessage(
              friendId: conversationId,
              content: content.isNotEmpty ? content : fallbackContent,
              fileType: content.isNotEmpty ? null : 'file',
            )
          : await _chatService.sendMessage(
              projectId: conversationId,
              content: content.isNotEmpty ? content : fallbackContent,
              messageType: content.isNotEmpty ? 'text' : 'file',
            );
      if (!mounted) return;
      setState(() {
        _messages.add(_mapMessage(message));
        _messageController.clear();
        _attachments.clear();
        _isLoading = false;
      });
      _scrollToBottom();
      if (isDirect) {
        _loadFriends();
      } else {
        _loadProjects();
      }
    } on ApiException catch (err) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      _showSnackbar(err.message);
    }
  }

  void sendMockMessage({String? filePath, String? fileType}) {
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
        'content': content.isNotEmpty
            ? content
            : _t(
                'Đã gửi một file đính kèm',
                'Sent an attachment',
                '已发送一个附件',
              ),
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

  Future<void> _sendBotMessage() async {
    final content = _botMessageController.text.trim();
    if (content.isEmpty || _isBotLoading) return;

    setState(() {
      _botMessages.add({
        'content': content,
        'isMine': true,
        'time': DateTime.now(),
      });
      _botMessageController.clear();
      _isBotLoading = true;
    });
    _scrollBotToBottom();

    try {
      final data = await _chatbotService.ask(
        content,
        language: _language.name,
      );
      final answer = data['answer']?.toString().trim();
      if (!mounted) return;
      setState(() {
        _botMessages.add({
          'content': (answer == null || answer.isEmpty)
              ? _t(
                  'Mình chưa có câu trả lời phù hợp.',
                  'I do not have a suitable answer yet.',
                  '我还没有合适的回答。',
                )
              : answer,
          'isMine': false,
          'time': DateTime.now(),
        });
        _isBotLoading = false;
      });
      _scrollBotToBottom();
    } on ApiException catch (err) {
      if (!mounted) return;
      setState(() {
        _botMessages.add({
          'content': err.message,
          'isMine': false,
          'time': DateTime.now(),
        });
        _isBotLoading = false;
      });
      _scrollBotToBottom();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _botMessages.add({
          'content': _t(
            'Không thể kết nối chatbot. Kiểm tra backend và Gemini API key nhé.',
            'Cannot connect to chatbot. Please check the backend and Gemini API key.',
            '无法连接聊天机器人。请检查后端和 Gemini API key。',
          ),
          'isMine': false,
          'time': DateTime.now(),
        });
        _isBotLoading = false;
      });
      _scrollBotToBottom();
    }
  }

  void _scrollBotToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_botScrollController.hasClients) {
        _botScrollController.animateTo(
          _botScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showAttachmentOptions() {
    final theme = appThemeController;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: theme.surfaceColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _t('Đính kèm file', 'Attach file', '添加附件'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.textColor,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildAttachmentOption(
                  icon: Icons.image_rounded,
                  label: _t('Hình ảnh', 'Image', '图片'),
                  color: const Color(0xFF6366F1),
                  onTap: () {
                    Navigator.pop(context);
                    _showSnackbar(
                      _t(
                        'Chọn hình ảnh từ thư viện',
                        'Choose an image from gallery',
                        '从相册选择图片',
                      ),
                    );
                  },
                ),
                _buildAttachmentOption(
                  icon: Icons.video_camera_back_rounded,
                  label: 'Video',
                  color: const Color(0xFFEC4899),
                  onTap: () {
                    Navigator.pop(context);
                    _showSnackbar(
                      _t(
                        'Chọn video từ thư viện',
                        'Choose a video from gallery',
                        '从相册选择视频',
                      ),
                    );
                  },
                ),
                _buildAttachmentOption(
                  icon: Icons.insert_drive_file_rounded,
                  label: _t('Tài liệu', 'Document', '文档'),
                  color: const Color(0xFFF59E0B),
                  onTap: () {
                    Navigator.pop(context);
                    _showSnackbar(
                      _t(
                        'Chọn tài liệu từ thiết bị',
                        'Choose a document from device',
                        '从设备选择文档',
                      ),
                    );
                  },
                ),
                _buildAttachmentOption(
                  icon: Icons.mic_rounded,
                  label: _t('Ghi âm', 'Record', '录音'),
                  color: const Color(0xFF10B981),
                  onTap: () {
                    Navigator.pop(context);
                    _showSnackbar(
                      _t('Bắt đầu ghi âm', 'Start recording', '开始录音'),
                    );
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
            style: TextStyle(fontSize: 12, color: appThemeController.mutedTextColor),
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
      return _t('Vừa xong', 'Just now', '刚刚');
    } else if (diff.inHours < 1) {
      return _t(
        '${diff.inMinutes} phút',
        '${diff.inMinutes} min',
        '${diff.inMinutes} 分钟',
      );
    } else if (diff.inDays < 1) {
      return _t(
        '${diff.inHours} giờ',
        '${diff.inHours} h',
        '${diff.inHours} 小时',
      );
    } else {
      return _t(
        '${diff.inDays} ngày',
        '${diff.inDays} days',
        '${diff.inDays} 天',
      );
    }
  }

  String projectLastMessage(Map<String, dynamic> project) {
    switch (project['id']) {
      case '1':
        return _t(
          'Đã nhận được file thiết kế, cảm ơn bạn!',
          'Design file received, thank you!',
          '已收到设计文件，谢谢。',
        );
      case '2':
        return _t(
          'Khi nào deploy lên production?',
          'When will we deploy to production?',
          '什么时候部署到生产环境？',
        );
      case '3':
        return _t(
          'Model đã đạt accuracy 95%',
          'The model reached 95% accuracy',
          '模型准确率已达到 95%',
        );
      default:
        return project['lastMessage']?.toString() ?? '';
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
            // Header
            if (_selectedProject == null)
              Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                  const Icon(
                    Icons.chat_rounded,
                    color: Color(0xFF6366F1),
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _t('Tin nhắn', 'Messages', '消息'),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: theme.textColor,
                          ),
                        ),
                        Text(
                          _t(
                            'Nhắn tin theo dự án',
                            'Message by project',
                            '按项目聊天',
                          ),
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.mutedTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Nut tim kiem
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
            if (_selectedProject == null) ...[
              const SizedBox(height: 16),
              _buildMessageModeTabs(),
              if (!_showChatbot) ...[
                const SizedBox(height: 10),
                _buildChatSourceTabs(),
              ],
              const SizedBox(height: 16),
            ],

            // Noi dung chinh
            Expanded(
              child: _selectedProject == null
                  ? (_showChatbot
                      ? _buildChatbot()
                      : (_showFriendChats ? _buildFriendList() : _buildProjectList()))
                  : _buildChatDetail(),
            ),
          ],
        ),
      ),
      bottomNavigationBar: widget.showBottomNavigation && _selectedProject == null
          ? _buildBottomNavigationBar()
          : null,
    );
  }

  Widget _buildBottomNavigationBar() {
    return const AppBottomNavigation(
      currentItem: AppBottomNavItem.messages,
    );
  }

  Widget _buildMessageModeTabs() {
    final theme = appThemeController;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildModeTab(
            icon: Icons.chat_bubble_rounded,
            label: _t('Tin nhắn', 'Messages', '消息'),
            selected: !_showChatbot,
            onTap: () {
              setState(() {
                _showChatbot = false;
              });
            },
          ),
          _buildModeTab(
            icon: Icons.smart_toy_rounded,
            label: 'Chatbot',
            selected: _showChatbot,
            onTap: () {
              setState(() {
                _showChatbot = true;
                _selectedProject = null;
              });
              _scrollBotToBottom();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildModeTab({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final theme = appThemeController;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? theme.primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? Colors.white : theme.mutedTextColor,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : theme.textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatSourceTabs() {
    final theme = appThemeController;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _buildSourceTab(
            icon: Icons.folder_rounded,
            label: _t('Dự án', 'Projects', '项目'),
            selected: !_showFriendChats,
            onTap: () {
              setState(() {
                _showFriendChats = false;
              });
              _loadProjects();
            },
          ),
          _buildSourceTab(
            icon: Icons.people_alt_rounded,
            label: _t('Bạn bè', 'Friends', '好友'),
            selected: _showFriendChats,
            onTap: () {
              setState(() {
                _showFriendChats = true;
              });
              _loadFriends();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSourceTab({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final theme = appThemeController;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? theme.primaryColor.withValues(alpha: 0.12) : null,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 17,
                color: selected ? theme.primaryColor : theme.mutedTextColor,
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: selected ? theme.primaryColor : theme.mutedTextColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStateMessage({
    required IconData icon,
    required String title,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final theme = appThemeController;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 58, color: theme.mutedTextColor),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: theme.textColor,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(actionLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProjectList() {
    final theme = appThemeController;
    if (_isLoadingProjects) {
      return Center(
        child: CircularProgressIndicator(color: theme.primaryColor),
      );
    }

    if (_projectError != null) {
      return _buildStateMessage(
        icon: Icons.error_outline_rounded,
        title: _projectError!,
        actionLabel: _t('Thử lại', 'Retry', '重试'),
        onAction: _loadProjects,
      );
    }

    if (_projects.isEmpty) {
      return _buildStateMessage(
        icon: Icons.forum_outlined,
        title: _t(
          'Chưa có dự án để nhắn tin',
          'No projects to message',
          '暂无可聊天项目',
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _projects.length,
      itemBuilder: (context, index) {
        final project = _projects[index];
        final color = parseHexColor(project['color']);
        final memberCount = int.tryParse(
              project['memberCount']?.toString() ??
                  project['member_count']?.toString() ??
                  '',
            ) ??
            ((project['members'] is List) ? (project['members'] as List).length : 0);

        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedProject = project;
            });
            _loadMessages();
            _scrollToBottom();
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.surfaceColor,
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
                // Icon du an
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(project['icon'], color: color, size: 28),
                ),
                const SizedBox(width: 14),
                // Thong tin
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              project['name'],
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: theme.textColor,
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
                        project['lastMessage']?.toString() ??
                            _t('Chưa có tin nhắn', 'No messages yet', '暂无消息'),
                        style: TextStyle(
                          fontSize: 13,
                          color: project['unreadCount'] > 0
                              ? theme.textColor
                              : theme.mutedTextColor,
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
                            color: theme.mutedTextColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _t(
                              '$memberCount thành viên',
                              '$memberCount members',
                              '$memberCount 名成员',
                            ),
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.mutedTextColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _formatTime(project['lastTime']),
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.mutedTextColor,
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

  Widget _buildFriendList() {
    final theme = appThemeController;
    if (_isLoadingFriends) {
      return Center(
        child: CircularProgressIndicator(color: theme.primaryColor),
      );
    }

    if (_friendError != null) {
      return _buildStateMessage(
        icon: Icons.error_outline_rounded,
        title: _friendError!,
        actionLabel: _t('Thử lại', 'Retry', '重试'),
        onAction: () => _loadFriends(),
      );
    }

    if (_friends.isEmpty) {
      return _buildStateMessage(
        icon: Icons.people_outline_rounded,
        title: _t(
          'Chưa có bạn bè để nhắn tin',
          'No friends to message',
          '暂无可聊天的好友',
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _friends.length,
      itemBuilder: (context, index) {
        final friend = _friends[index];
        final color = parseHexColor(friend['color']);
        final name = friend['name']?.toString() ?? '';
        final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';
        final avatarUrl = _buildAvatarUrl(friend['avatar']?.toString());

        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedProject = friend;
            });
            _loadMessages();
            _scrollToBottom();
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.surfaceColor,
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
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: avatarUrl == null
                      ? Center(
                          child: Text(
                            initial,
                            style: TextStyle(
                              color: color,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        )
                      : Image.network(
                          avatarUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Center(
                            child: Text(
                              initial,
                              style: TextStyle(
                                color: color,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: theme.textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        friend['lastMessage']?.toString() ??
                            friend['email']?.toString() ??
                            '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.mutedTextColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        friend['email']?.toString() ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.mutedTextColor,
                        ),
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

  Widget _buildChatbot() {
    final theme = appThemeController;
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _botScrollController,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            itemCount: _botMessages.length + (_isBotLoading ? 1 : 0),
            itemBuilder: (context, index) {
              if (_isBotLoading && index == _botMessages.length) {
                return _buildBotTypingIndicator();
              }

              final message = _botMessages[index];
              final isMine = message['isMine'] == true;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  mainAxisAlignment: isMine
                      ? MainAxisAlignment.end
                      : MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (!isMine)
                      const CircleAvatar(
                        radius: 17,
                        backgroundColor: Color(0xFFEDE9FE),
                        child: Icon(
                          Icons.smart_toy_rounded,
                          color: Color(0xFF6366F1),
                          size: 18,
                        ),
                      ),
                    if (!isMine) const SizedBox(width: 8),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          color: isMine ? const Color(0xFF6366F1) : Colors.white,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(isMine ? 16 : 6),
                            topRight: Radius.circular(isMine ? 6 : 16),
                            bottomLeft: const Radius.circular(16),
                            bottomRight: const Radius.circular(16),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withValues(alpha: 0.06),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Text(
                          message['content'],
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.4,
                            color: isMine
                                ? Colors.white
                                : const Color(0xFF1F2937),
                          ),
                        ),
                      ),
                    ),
                    if (isMine) const SizedBox(width: 8),
                    if (isMine)
                      const CircleAvatar(
                        radius: 17,
                        backgroundColor: Color(0xFF6366F1),
                        child: Text(
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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: theme.surfaceColor,
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
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.backgroundColor,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: TextField(
                    controller: _botMessageController,
                    decoration: InputDecoration(
                      hintText: _t(
                        'Hỏi chatbot về công việc...',
                        'Ask the chatbot about work...',
                        '向聊天机器人询问工作...',
                      ),
                      hintStyle: TextStyle(color: theme.mutedTextColor),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    style: TextStyle(
                      fontSize: 15,
                      color: theme.textColor,
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendBotMessage(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: IconButton(
                  onPressed: _isBotLoading ? null : _sendBotMessage,
                  icon: _isBotLoading
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

  Widget _buildBotTypingIndicator() {
    final theme = appThemeController;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const CircleAvatar(
            radius: 17,
            backgroundColor: Color(0xFFEDE9FE),
            child: Icon(
              Icons.smart_toy_rounded,
              color: Color(0xFF6366F1),
              size: 18,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: theme.surfaceColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(6),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: theme.primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatDetail() {
    final theme = appThemeController;
    final project = _selectedProject!;
    final isDirect = project['chatType'] == 'direct';
    final color = parseHexColor(project['color']);
    final memberCount = int.tryParse(
          project['memberCount']?.toString() ??
              project['member_count']?.toString() ??
              '',
        ) ??
        ((project['members'] is List) ? (project['members'] as List).length : 0);

    return Column(
      children: [
        // Header chat
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: theme.surfaceColor,
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
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: theme.textColor,
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
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: theme.textColor,
                      ),
                    ),
                    Text(
                      isDirect
                          ? (project['email']?.toString() ??
                              _t('Bạn bè', 'Friend', '好友'))
                          : _t(
                              '$memberCount thành viên',
                              '$memberCount members',
                              '$memberCount 名成员',
                            ),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
              ),
              // Nut thong tin du an
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.backgroundColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.info_outline_rounded,
                  color: theme.mutedTextColor,
                  size: 22,
                ),
              ),
            ],
          ),
        ),

        // Danh sach tin nhan
        Expanded(
          child: _isLoadingMessages
              ? Center(
                  child: CircularProgressIndicator(color: theme.primaryColor),
                )
              : _messageError != null
                  ? _buildStateMessage(
                      icon: Icons.error_outline_rounded,
                      title: _messageError!,
                      actionLabel: _t('Thử lại', 'Retry', '重试'),
                      onAction: _loadMessages,
                    )
                  : _messages.isEmpty
                      ? _buildStateMessage(
                          icon: Icons.chat_bubble_outline_rounded,
                          title: _t(
                            'Chưa có tin nhắn',
                            'No messages yet',
                            '暂无消息',
                          ),
                        )
                      : ListView.builder(
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
                          (message['sender']?.toString().isNotEmpty ?? false)
                              ? message['sender'].toString()[0].toUpperCase()
                              : '?',
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
                                style: TextStyle(
                                  fontSize: 11,
                                  color: theme.mutedTextColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isMine
                                  ? const Color(0xFF6366F1)
                                  : theme.surfaceColor,
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
                                      color: theme.backgroundColor,
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
                                          : theme.textColor,
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
                              style: TextStyle(
                                fontSize: 10,
                                color: theme.mutedTextColor,
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
            color: theme.surfaceColor,
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
              // Nut dinh kem
              IconButton(
                onPressed: _showAttachmentOptions,
                icon: Icon(
                  Icons.attach_file_rounded,
                  color: theme.mutedTextColor,
                  size: 26,
                ),
              ),
              // Input
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.backgroundColor,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: _t(
                        'Nhập tin nhắn...',
                        'Type a message...',
                        '输入消息...',
                      ),
                      hintStyle: TextStyle(color: theme.mutedTextColor),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    style: TextStyle(
                      fontSize: 15,
                      color: theme.textColor,
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
              ),
              // Nut gui
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
