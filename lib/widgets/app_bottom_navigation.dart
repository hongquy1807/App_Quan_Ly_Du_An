import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_theme_controller.dart';

enum AppBottomNavItem { home, timeline, projects, messages, me }

class AppBottomNavigation extends StatefulWidget {
  final AppBottomNavItem currentItem;
  final bool rounded;
  final ValueChanged<AppBottomNavItem>? onItemSelected;

  const AppBottomNavigation({
    super.key,
    required this.currentItem,
    this.rounded = true,
    this.onItemSelected,
  });

  @override
  State<AppBottomNavigation> createState() => _AppBottomNavigationState();
}

class _AppBottomNavigationState extends State<AppBottomNavigation> {
  String _language = 'vietnamese';

  @override
  void initState() {
    super.initState();
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _language = prefs.getString('app_language') ?? 'vietnamese';
    });
  }

  String _t(String vi, String en, String zh) {
    switch (_language) {
      case 'english':
        return en;
      case 'chinese':
        return zh;
      default:
        return vi;
    }
  }

  int get _currentIndex => widget.currentItem.index;

  void _onTap(int index) {
    if (index == _currentIndex) return;
    final item = AppBottomNavItem.values[index];

    if (widget.onItemSelected != null) {
      widget.onItemSelected!(item);
      return;
    }

    final route = switch (item) {
      AppBottomNavItem.home => '/home',
      AppBottomNavItem.timeline => '/timeline',
      AppBottomNavItem.projects => '/projects',
      AppBottomNavItem.messages => '/chat',
      AppBottomNavItem.me => '/profile',
    };

    Navigator.pushReplacementNamed(context, route);
  }

  @override
  Widget build(BuildContext context) {
    final theme = appThemeController;
    final nav = BottomNavigationBar(
      backgroundColor: theme.surfaceColor,
      currentIndex: _currentIndex,
      onTap: _onTap,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: theme.primaryColor,
      unselectedItemColor: theme.mutedTextColor,
      selectedLabelStyle: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 11,
      ),
      unselectedLabelStyle: const TextStyle(fontSize: 11),
      items: [
        BottomNavigationBarItem(
          icon: const Icon(Icons.home_rounded),
          activeIcon: const Icon(Icons.home_rounded),
          label: _t('Trang chủ', 'Home', '首页'),
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.calendar_month_rounded),
          activeIcon: const Icon(Icons.calendar_month_rounded),
          label: _t('Lịch', 'Timeline', '日程'),
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.folder_rounded),
          activeIcon: const Icon(Icons.folder_rounded),
          label: _t('Dự án', 'Projects', '项目'),
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.chat_rounded),
          activeIcon: const Icon(Icons.chat_rounded),
          label: _t('Tin nhắn', 'Messages', '消息'),
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.person_rounded),
          activeIcon: const Icon(Icons.person_rounded),
          label: _t('Tôi', 'Me', '我的'),
        ),
      ],
    );

    if (!widget.rounded) {
      return nav;
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.surfaceColor,
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
      child: nav,
    );
  }
}
