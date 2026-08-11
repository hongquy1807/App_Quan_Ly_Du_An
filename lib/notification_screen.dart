import 'package:flutter/material.dart';

import 'app_theme_controller.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final NotificationService _notificationService = NotificationService();
  final List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _notificationService.getNotifications(limit: 50);
      final data = response['data'];
      final notifications = data is Map ? data['notifications'] : null;
      final items = notifications is List
          ? notifications
              .whereType<Map>()
              .map((item) => _mapNotification(Map<String, dynamic>.from(item)))
              .toList()
          : <Map<String, dynamic>>[];

      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(items);
        _isLoading = false;
      });
    } on ApiException catch (err) {
      if (!mounted) return;
      setState(() {
        _errorMessage = err.message;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Không thể tải thông báo.';
        _isLoading = false;
      });
    }
  }

  Map<String, dynamic> _mapNotification(Map<String, dynamic> notification) {
    return {
      ...notification,
      'type': _typeFromApi(notification['type']?.toString()),
      'title': notification['title']?.toString() ?? 'Thông báo',
      'message': notification['message']?.toString() ??
          notification['content']?.toString() ??
          '',
      'project': notification['project']?.toString() ?? '',
      'time': notification['time']?.toString() ?? '',
      'isUnread': notification['isUnread'] == true ||
          notification['read'] == false ||
          notification['read']?.toString() == '0',
    };
  }

  _NotificationType _typeFromApi(String? type) {
    switch (type) {
      case 'deadline':
        return _NotificationType.deadline;
      case 'task':
        return _NotificationType.task;
      case 'project_invitation':
      case 'project':
        return _NotificationType.project;
      case 'project_message':
      case 'message':
        return _NotificationType.message;
      default:
        return _NotificationType.general;
    }
  }

  Future<void> _markRead(Map<String, dynamic> item) async {
    final id = int.tryParse(item['id']?.toString() ?? '');
    if (id == null || item['isUnread'] != true) return;

    setState(() {
      item['isUnread'] = false;
      item['read'] = true;
    });

    try {
      await _notificationService.markRead(id, true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        item['isUnread'] = true;
        item['read'] = false;
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
            _buildHeader(context),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: appThemeController.primaryColor),
      );
    }

    if (_errorMessage != null) {
      return _NotificationState(
        icon: Icons.wifi_off_rounded,
        title: _errorMessage!,
        actionLabel: 'Thử lại',
        onAction: _loadNotifications,
      );
    }

    if (_items.isEmpty) {
      return const _NotificationState(
        icon: Icons.notifications_none_rounded,
        title: 'Chưa có thông báo nào',
      );
    }

    return RefreshIndicator(
      color: appThemeController.primaryColor,
      onRefresh: _loadNotifications,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
        itemCount: _items.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          return _NotificationCard(
            item: _items[index],
            onTap: () => _markRead(_items[index]),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
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
              'Thông báo',
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
}

enum _NotificationType { deadline, task, project, message, general }

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.item,
    required this.onTap,
  });

  final Map<String, dynamic> item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = appThemeController;
    final type = item['type'] as _NotificationType;
    final color = _colorFor(type);
    final icon = _iconFor(type);
    final project = item['project']?.toString() ?? '';

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: item['isUnread'] == true
                ? color.withValues(alpha: 0.28)
                : theme.mutedTextColor.withValues(alpha: 0.12),
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
                          item['title']?.toString() ?? 'Thông báo',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: theme.textColor,
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
                    item['message']?.toString() ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.mutedTextColor,
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
                          project.isEmpty ? 'Dự án' : project,
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
                      Icon(
                        Icons.access_time_rounded,
                        size: 14,
                        color: theme.mutedTextColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        item['time']?.toString() ?? '',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.mutedTextColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
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
      case _NotificationType.general:
        return const Color(0xFFF59E0B);
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
      case _NotificationType.general:
        return Icons.notifications_rounded;
    }
  }
}

class _NotificationState extends StatelessWidget {
  const _NotificationState({
    required this.icon,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = appThemeController;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 64,
              color: theme.mutedTextColor.withValues(alpha: 0.55),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
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
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
