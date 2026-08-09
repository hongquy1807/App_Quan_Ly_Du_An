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

  late final List<Widget> _pages = const [
    HomeScreen(showBottomNavigation: false),
    TimelineScreen(showBottomNavigation: false),
    ProjectScreen(showBottomNavigation: false),
    ChatScreen(showBottomNavigation: false),
    ProfileScreen(showBottomNavigation: false),
  ];

  @override
  void initState() {
    super.initState();
    _currentItem = widget.initialItem;
  }

  void _selectItem(AppBottomNavItem item) {
    if (item == _currentItem) return;
    setState(() {
      _currentItem = item;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentItem.index,
        children: _pages,
      ),
      bottomNavigationBar: AppBottomNavigation(
        currentItem: _currentItem,
        onItemSelected: _selectItem,
      ),
    );
  }
}
