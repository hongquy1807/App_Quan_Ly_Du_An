import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme_controller.dart';

enum FriendsLanguage { vietnamese, english, chinese }

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final TextEditingController _searchController = TextEditingController();
  FriendsLanguage _language = FriendsLanguage.vietnamese;
  bool _isAscending = true;
  String _query = '';

  final List<Map<String, String>> _friends = [
    {
      'name': 'Nguyễn Văn A',
      'email': 'nguyenvana@email.com',
    },
    {
      'name': 'Trần Thị B',
      'email': 'tranthib@email.com',
    },
    {
      'name': 'Lê Văn C',
      'email': 'levanc@email.com',
    },
    {
      'name': 'Phạm Thị D',
      'email': 'phamthid@email.com',
    },
    {
      'name': 'Phạm Hồng Quý',
      'email': 'hongquy@gmail.com',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadLanguage();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _t(String vi, String en, String zh) {
    switch (_language) {
      case FriendsLanguage.vietnamese:
        return vi;
      case FriendsLanguage.english:
        return en;
      case FriendsLanguage.chinese:
        return zh;
    }
  }

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final rawValue = prefs.getString('app_language');
    if (!mounted) return;
    setState(() {
      _language = FriendsLanguage.values.firstWhere(
        (language) => language.name == rawValue,
        orElse: () => FriendsLanguage.vietnamese,
      );
    });
  }

  List<Map<String, String>> get _visibleFriends {
    final keyword = _query.trim().toLowerCase();
    final filtered = _friends.where((friend) {
      final name = friend['name']!.toLowerCase();
      final email = friend['email']!.toLowerCase();
      return keyword.isEmpty ||
          name.contains(keyword) ||
          email.contains(keyword);
    }).toList();

    filtered.sort((a, b) {
      final compare = a['name']!.compareTo(b['name']!);
      return _isAscending ? compare : -compare;
    });

    return filtered;
  }

  void _toggleSort() {
    setState(() {
      _isAscending = !_isAscending;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = appThemeController;
    final visibleFriends = _visibleFriends;

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(theme),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          icon: Icons.people_alt_rounded,
                          value: _friends.length.toString(),
                          label: _t('Tổng bạn bè', 'Total friends', '好友总数'),
                          onTap: null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          icon: _isAscending
                              ? Icons.arrow_upward_rounded
                              : Icons.arrow_downward_rounded,
                          value: '',
                          label: _t('Sắp xếp', 'Sort', '排序'),
                          onTap: _toggleSort,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSearchBox(theme),
                  const SizedBox(height: 18),
                  if (visibleFriends.isEmpty)
                    _buildEmptyState(theme)
                  else
                    ...visibleFriends.map(_buildFriendCard),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(AppThemeController theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
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
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.backgroundColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 20,
                color: theme.textColor,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              _t('Bạn bè', 'Friends', '朋友'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: theme.textColor,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required VoidCallback? onTap,
  }) {
    final theme = appThemeController;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 92,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.surfaceColor,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            value.isEmpty
                ? Icon(icon, color: theme.primaryColor, size: 30)
                : Text(
                    value,
                    style: TextStyle(
                      color: theme.primaryColor,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: theme.mutedTextColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBox(AppThemeController theme) {
    return Container(
      height: 58,
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _query = value;
          });
        },
        style: TextStyle(color: theme.textColor, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: _t('Tìm kiếm bạn bè', 'Search friends', '搜索好友'),
          hintStyle: TextStyle(color: theme.mutedTextColor),
          prefixIcon: Icon(Icons.search_rounded, color: theme.mutedTextColor),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _query = '';
                    });
                  },
                  icon: Icon(Icons.close_rounded, color: theme.mutedTextColor),
                ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
        ),
      ),
    );
  }

  Widget _buildFriendCard(Map<String, String> friend) {
    final theme = appThemeController;
    final name = friend['name'] ?? '';
    final email = friend['email'] ?? '';
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
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
              color: theme.primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                initial,
                style: TextStyle(
                  color: theme.primaryColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
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
                    color: theme.textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.mutedTextColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(AppThemeController theme) {
    return Padding(
      padding: const EdgeInsets.only(top: 110),
      child: Column(
        children: [
          Icon(
            Icons.people_outline_rounded,
            size: 72,
            color: theme.mutedTextColor.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            _t('Không tìm thấy bạn bè', 'No friends found', '未找到好友'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.textColor,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
