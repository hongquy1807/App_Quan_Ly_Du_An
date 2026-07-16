import 'package:flutter/material.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  static final List<Map<String, dynamic>> _items = [
    {
      'type': _NotificationType.deadline,
      'title': 'Task sắp đến hạn',
      'message': 'Thiết kế UI cho màn hình chính còn 1 ngày đến hạn.',
      'project': 'App di động',
      'time': 'Hôm nay',
      'isUnread': true,
    },
    {
      'type': _NotificationType.deadline,
      'title': 'Nhắc hạn nhiệm vụ',
      'message': 'Xây dựng API đăng nhập còn 2 ngày đến hạn.',
      'project': 'App di động',
      'time': '1 giờ trước',
      'isUnread': true,
    },
    {
      'type': _NotificationType.deadline,
      'title': 'Task sắp đến hạn',
      'message': 'Kiểm thử chức năng chat còn 3 ngày đến hạn.',
      'project': 'Hệ thống CRM',
      'time': '2 giờ trước',
      'isUnread': false,
    },
    {
      'type': _NotificationType.task,
      'title': 'Bạn có nhiệm vụ mới',
      'message': 'Bạn vừa được giao task: Tối ưu hiệu suất ứng dụng.',
      'project': 'App IoT',
      'time': '3 giờ trước',
      'isUnread': true,
    },
    {
      'type': _NotificationType.project,
      'title': 'Bạn được thêm vào dự án',
      'message': 'Nguyễn Văn A đã thêm bạn vào dự án Website bán hàng.',
      'project': 'Website bán hàng',
      'time': 'Hôm qua',
      'isUnread': false,
    },
    {
      'type': _NotificationType.message,
      'title': 'Tin nhắn mới',
      'message': 'Bạn có 5 tin nhắn mới ở dự án Dự án AI.',
      'project': 'Dự án AI',
      'time': 'Hôm qua',
      'isUnread': false,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: ListView.separated(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                itemCount: _items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  return _NotificationCard(item: _items[index]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
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
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            color: const Color(0xFF1F2937),
          ),
          const Expanded(
            child: Text(
              'Thông báo',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

enum _NotificationType { deadline, task, project, message }

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.item});

  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final type = item['type'] as _NotificationType;
    final color = _colorFor(type);
    final icon = _iconFor(type);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: item['isUnread'] == true
              ? color.withValues(alpha: 0.28)
              : const Color(0xFFF1F5F9),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        item['title'],
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                    ),
                    if (item['isUnread'] == true)
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(top: 6),
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  item['message'],
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF4B5563),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.folder_rounded, size: 15, color: color),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        item['project'],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.access_time_rounded,
                      size: 14,
                      color: Color(0xFF9CA3AF),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      item['time'],
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _colorFor(_NotificationType type) {
    switch (type) {
      case _NotificationType.deadline:
        return const Color(0xFFEF4444);
      case _NotificationType.task:
        return const Color(0xFF6366F1);
      case _NotificationType.project:
        return const Color(0xFF10B981);
      case _NotificationType.message:
        return const Color(0xFF3B82F6);
    }
  }

  IconData _iconFor(_NotificationType type) {
    switch (type) {
      case _NotificationType.deadline:
        return Icons.event_busy_rounded;
      case _NotificationType.task:
        return Icons.assignment_turned_in_rounded;
      case _NotificationType.project:
        return Icons.group_add_rounded;
      case _NotificationType.message:
        return Icons.chat_bubble_rounded;
    }
  }
}
