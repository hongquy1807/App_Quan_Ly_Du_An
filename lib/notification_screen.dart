import 'package:flutter/material.dart';

import 'app_language_controller.dart';
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
  final List<Map<String, dynamic>> _notifications = [];

  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _error;

  String _t(String vi, String en, String zh) {
    return appLanguageController.text(vi, en, zh);
  }

  @override
  void initState() {
    super.initState();
    appThemeController.addListener(_onSettingsChanged);
    appLanguageController.addListener(_onSettingsChanged);
    _loadNotifications();
  }

  @override
  void dispose() {
    appThemeController.removeListener(_onSettingsChanged);
    appLanguageController.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadNotifications({bool refresh = false}) async {
    if (!mounted) return;
    setState(() {
      _error = null;
      if (refresh) {
        _isRefreshing = true;
      } else {
        _isLoading = true;
      }
    });

    try {
      final response = await _notificationService.getNotifications(limit: 50);
      final data = response['data'];
      final rawNotifications = data is Map ? data['notifications'] : response['notifications'];
      final notifications = rawNotifications is List
          ? rawNotifications
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
          : <Map<String, dynamic>>[];

      if (!mounted) return;
      setState(() {
        _notifications
          ..clear()
          ..addAll(notifications);
      });
    } on ApiException catch (err) {
      if (!mounted) return;
      setState(() {
        _error = err.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = _t(
          'Không thể tải thông báo.',
          'Cannot load notifications.',
          '无法加载通知。',
        );
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isRefreshing = false;
      });
    }
  }

  Future<void> _markAllRead() async {
    try {
      await _notificationService.markAllRead();
      await _loadNotifications(refresh: true);
    } on ApiException catch (err) {
      _showMessage(err.message);
    }
  }

  Future<void> _toggleRead(Map<String, dynamic> notification) async {
    final id = int.tryParse(notification['id']?.toString() ?? '');
    if (id == null) return;

    final wasUnread = _isUnread(notification);
    setState(() {
      notification['isUnread'] = false;
      notification['read'] = true;
    });

    try {
      await _notificationService.markRead(id, true);
    } on ApiException catch (err) {
      if (!mounted) return;
      setState(() {
        notification['isUnread'] = wasUnread;
        notification['read'] = !wasUnread;
      });
      _showMessage(err.message);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  bool _isUnread(Map<String, dynamic> notification) {
    if (notification['isUnread'] is bool) return notification['isUnread'] as bool;
    if (notification['read'] is bool) return !(notification['read'] as bool);
    return notification['read']?.toString() != '1';
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'deadline':
        return Icons.event_busy_rounded;
      case 'task':
        return Icons.assignment_turned_in_rounded;
      case 'project_invitation':
        return Icons.group_add_rounded;
      case 'project_message':
        return Icons.forum_rounded;
      case 'project':
        return Icons.folder_rounded;
      default:
        return Icons.notifications_none_rounded;
    }
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'deadline':
        return const Color(0xFFE11D48);
      case 'task':
        return appThemeController.primaryColor;
      case 'project_invitation':
        return const Color(0xFF10B981);
      case 'project_message':
        return const Color(0xFFF59E0B);
      case 'project':
        return const Color(0xFF3B82F6);
      default:
        return appThemeController.primaryColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = appThemeController;
    final isDark = theme.isDark;

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
              decoration: BoxDecoration(
                color: theme.surfaceColor,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.06),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.maybePop(context),
                    icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.textColor),
                  ),
                  Expanded(
                    child: Text(
                      _t('Thông báo', 'Notifications', '通知'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: theme.textColor,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _notifications.any(_isUnread) ? _markAllRead : null,
                    icon: Icon(
                      Icons.done_all_rounded,
                      color: _notifications.any(_isUnread)
                          ? theme.primaryColor
                          : theme.mutedTextColor.withValues(alpha: 0.45),
                    ),
                    tooltip: _t('Đánh dấu đã đọc', 'Mark all as read', '全部标为已读'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => _loadNotifications(refresh: true),
                color: theme.primaryColor,
                child: _buildBody(theme),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(AppThemeController theme) {
    if (_isLoading && !_isRefreshing) {
      return Center(
        child: CircularProgressIndicator(color: theme.primaryColor),
      );
    }

    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(28),
        children: [
          const SizedBox(height: 160),
          Icon(Icons.error_outline_rounded, size: 74, color: const Color(0xFFEF4444).withValues(alpha: 0.85)),
          const SizedBox(height: 18),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.textColor, fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 20),
          Center(
            child: ElevatedButton.icon(
              onPressed: () => _loadNotifications(),
              icon: const Icon(Icons.refresh_rounded),
              label: Text(_t('Thử lại', 'Retry', '重试')),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
            ),
          ),
        ],
      );
    }

    if (_notifications.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(28),
        children: [
          const SizedBox(height: 180),
          Icon(
            Icons.notifications_off_outlined,
            size: 78,
            color: theme.mutedTextColor.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 18),
          Text(
            _t('Chưa có thông báo', 'No notifications yet', '暂无通知'),
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.textColor, fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            _t(
              'Các nhắc hẹn và cập nhật dự án sẽ xuất hiện tại đây.',
              'Project reminders and updates will appear here.',
              '项目提醒和更新会显示在这里。',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.mutedTextColor, fontSize: 15),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 28),
      itemCount: _notifications.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        return _buildNotificationCard(theme, _notifications[index]);
      },
    );
  }

  Widget _buildNotificationCard(
    AppThemeController theme,
    Map<String, dynamic> notification,
  ) {
    final type = notification['type']?.toString() ?? 'general';
    final color = _colorForType(type);
    final isUnread = _isUnread(notification);
    final project = notification['project']?.toString() ?? '';
    final message = notification['message']?.toString().isNotEmpty == true
        ? notification['message'].toString()
        : notification['content']?.toString() ?? '';

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => _toggleRead(notification),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.surfaceColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isUnread ? color.withValues(alpha: 0.35) : Colors.transparent,
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: theme.isDark ? 0.18 : 0.06),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: theme.isDark ? 0.18 : 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(_iconForType(type), color: color, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          notification['title']?.toString() ?? _t('Thông báo', 'Notification', '通知'),
                          style: TextStyle(
                            color: theme.textColor,
                            fontSize: 17,
                            fontWeight: isUnread ? FontWeight.w800 : FontWeight.w700,
                          ),
                        ),
                      ),
                      if (isUnread)
                        Container(
                          width: 9,
                          height: 9,
                          margin: const EdgeInsets.only(top: 7, left: 8),
                          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                        ),
                    ],
                  ),
                  if (message.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: theme.mutedTextColor, fontSize: 14, height: 1.35),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (project.isNotEmpty) ...[
                        Icon(Icons.folder_rounded, size: 16, color: color),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            project,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Icon(Icons.access_time_rounded, size: 15, color: theme.mutedTextColor),
                      const SizedBox(width: 5),
                      Text(
                        notification['time']?.toString() ?? '',
                        style: TextStyle(color: theme.mutedTextColor, fontSize: 13),
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
}
