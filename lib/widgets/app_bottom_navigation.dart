import 'package:flutter/material.dart';

import '../app_language_controller.dart';
import '../app_theme_controller.dart';

enum AppBottomNavItem { home, timeline, projects, messages, me }

class AppBottomNavigation extends StatelessWidget {
  final AppBottomNavItem currentItem;
  final bool rounded;
  final ValueChanged<AppBottomNavItem>? onItemSelected;

  const AppBottomNavigation({
    super.key,
    required this.currentItem,
    this.rounded = true,
    this.onItemSelected,
  });

  int get _currentIndex => currentItem.index;

  String _t(String vi, String en, String zh) {
    return appLanguageController.text(vi, en, zh);
  }

  void _onTap(BuildContext context, int index) {
    if (index == _currentIndex) return;
    final item = AppBottomNavItem.values[index];

    if (onItemSelected != null) {
      onItemSelected!(item);
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
    final nav = AnimatedBuilder(
      animation: appLanguageController,
      builder: (context, _) {
        return BottomNavigationBar(
          backgroundColor: theme.surfaceColor,
          currentIndex: _currentIndex,
          onTap: (index) => _onTap(context, index),
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
              label: _t('Trang ch\u1ee7', 'Home', '\u9996\u9875'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.calendar_month_rounded),
              activeIcon: const Icon(Icons.calendar_month_rounded),
              label: _t('L\u1ecbch', 'Timeline', '\u65e5\u7a0b'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.folder_rounded),
              activeIcon: const Icon(Icons.folder_rounded),
              label: _t('D\u1ef1 \u00e1n', 'Projects', '\u9879\u76ee'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.chat_rounded),
              activeIcon: const Icon(Icons.chat_rounded),
              label: _t('Tin nh\u1eafn', 'Messages', '\u6d88\u606f'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.person_rounded),
              activeIcon: const Icon(Icons.person_rounded),
              label: _t('T\u00f4i', 'Me', '\u6211\u7684'),
            ),
          ],
        );
      },
    );

    if (!rounded) return nav;

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
