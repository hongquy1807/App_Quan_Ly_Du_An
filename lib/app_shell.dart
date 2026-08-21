import 'package:flutter/material.dart';

import 'chat_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'project_screen.dart';
import 'timeline_screen.dart';
import 'widgets/app_bottom_navigation.dart';

class AppShell extends StatefulWidget {
  final AppBottomNavItem initialItem;

  const AppShell({
    super.key,
    this.initialItem = AppBottomNavItem.home,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late AppBottomNavItem _currentItem;
  int _homeRefreshKey = 0;
  int _timelineRefreshKey = 0;
  int _projectRefreshKey = 0;
  int _chatRefreshKey = 0;
  int _profileRefreshKey = 0;

  @override
  void initState() {
    super.initState();
    _currentItem = widget.initialItem;
  }

  void _selectItem(AppBottomNavItem item) {
    if (item == _currentItem) return;
    setState(() {
      switch (item) {
        case AppBottomNavItem.home:
          _homeRefreshKey++;
          break;
        case AppBottomNavItem.timeline:
          _timelineRefreshKey++;
          break;
        case AppBottomNavItem.projects:
          _projectRefreshKey++;
          break;
        case AppBottomNavItem.messages:
          _chatRefreshKey++;
          break;
        case AppBottomNavItem.me:
          _profileRefreshKey++;
          break;
      }
      _currentItem = item;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentItem == AppBottomNavItem.home,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || _currentItem == AppBottomNavItem.home) return;
        setState(() {
          _homeRefreshKey++;
          _currentItem = AppBottomNavItem.home;
        });
      },
      child: Scaffold(
        body: IndexedStack(
          index: _currentItem.index,
          children: [
            HomeScreen(
              key: ValueKey('home-$_homeRefreshKey'),
              showBottomNavigation: false,
            ),
            TimelineScreen(
              key: ValueKey('timeline-$_timelineRefreshKey'),
              showBottomNavigation: false,
            ),
            ProjectScreen(
              key: ValueKey('projects-$_projectRefreshKey'),
              showBottomNavigation: false,
            ),
            ChatScreen(
              key: ValueKey('chat-$_chatRefreshKey'),
              showBottomNavigation: false,
            ),
            ProfileScreen(
              key: ValueKey('profile-$_profileRefreshKey'),
              showBottomNavigation: false,
            ),
          ],
        ),
        bottomNavigationBar: AppBottomNavigation(
          currentItem: _currentItem,
          onItemSelected: _selectItem,
        ),
      ),
    );
  }
}
