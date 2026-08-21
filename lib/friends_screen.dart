import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme_controller.dart';
import 'services/auth_service.dart';
import 'services/friend_service.dart';

enum FriendsLanguage { vietnamese, english, chinese }

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final FriendService _friendService = FriendService();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  FriendsLanguage _language = FriendsLanguage.vietnamese;
  bool _isAscending = true;
  bool _isLoading = true;
  bool _isLoadingRequests = false;
  bool _isSending = false;
  bool _isRespondingRequest = false;
  bool _showAddFriend = false;
  bool _showRequests = false;
  String _query = '';
  String? _error;
  String? _requestError;
  List<Map<String, dynamic>> _friends = [];
  List<Map<String, dynamic>> _requests = [];

  @override
  void initState() {
    super.initState();
    _loadLanguage();
    _loadFriends();
    _loadIncomingRequests();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _emailController.dispose();
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

  Future<void> _loadFriends() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await _friendService.getFriends(
        search: _query,
        ascending: _isAscending,
      );
      final friends = data['friends'];
      if (!mounted) return;
      setState(() {
        _friends = friends is List
            ? friends
                .whereType<Map>()
                .map((friend) => Map<String, dynamic>.from(friend))
                .toList()
            : [];
        _isLoading = false;
      });
    } on ApiException catch (err) {
      if (!mounted) return;
      setState(() {
        _friends = [];
        _error = err.message;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadIncomingRequests() async {
    setState(() {
      _isLoadingRequests = true;
      _requestError = null;
    });

    try {
      final data = await _friendService.getIncomingRequests();
      final requests = data['requests'];
      if (!mounted) return;
      setState(() {
        _requests = requests is List
            ? requests
                .whereType<Map>()
                .map((request) => Map<String, dynamic>.from(request))
                .toList()
            : [];
        _isLoadingRequests = false;
      });
    } on ApiException catch (err) {
      if (!mounted) return;
      setState(() {
        _requests = [];
        _requestError = err.message;
        _isLoadingRequests = false;
      });
    }
  }

  Future<void> _refreshAll() async {
    await Future.wait([
      _loadFriends(),
      _loadIncomingRequests(),
    ]);
  }

  Future<void> _sendFriendRequest() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || _isSending) return;

    setState(() {
      _isSending = true;
    });

    try {
      final message = await _friendService.sendFriendRequest(email);
      if (!mounted) return;
      _emailController.clear();
      setState(() {
        _showAddFriend = false;
        _isSending = false;
      });
      _showSnack(message);
    } on ApiException catch (err) {
      if (!mounted) return;
      setState(() {
        _isSending = false;
      });
      _showSnack(err.message);
    }
  }

  void _toggleSort() {
    setState(() {
      _isAscending = !_isAscending;
    });
    _loadFriends();
  }

  void _toggleAddFriend() {
    setState(() {
      _showAddFriend = !_showAddFriend;
      if (_showAddFriend) _showRequests = false;
      if (!_showAddFriend) _emailController.clear();
    });
  }

  void _toggleRequests() {
    setState(() {
      _showRequests = !_showRequests;
      if (_showRequests) _showAddFriend = false;
    });
    if (_showRequests) _loadIncomingRequests();
  }

  Future<void> _respondFriendRequest(
    Map<String, dynamic> request, {
    required bool accept,
  }) async {
    if (_isRespondingRequest) return;
    final id = request['id'];
    if (id == null) return;

    setState(() {
      _isRespondingRequest = true;
    });

    try {
      final message = accept
          ? await _friendService.acceptFriendRequest(id)
          : await _friendService.rejectFriendRequest(id);
      if (!mounted) return;
      setState(() {
        _isRespondingRequest = false;
      });
      _showSnack(message);
      await _refreshAll();
    } on ApiException catch (err) {
      if (!mounted) return;
      setState(() {
        _isRespondingRequest = false;
      });
      _showSnack(err.message);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = appThemeController;

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(theme),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshAll,
                color: theme.primaryColor,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
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
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildStatCard(
                            icon: Icons.person_add_alt_1_rounded,
                            value: '',
                            label: _t('Thêm bạn', 'Add friend', '添加好友'),
                            onTap: _toggleAddFriend,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildStatCard(
                            icon: Icons.mark_email_unread_rounded,
                            value: _requests.isEmpty
                                ? ''
                                : _requests.length.toString(),
                            label: _t('Lời mời', 'Requests', '邀请'),
                            onTap: _toggleRequests,
                          ),
                        ),
                        const SizedBox(width: 10),
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
                    if (_showAddFriend) ...[
                      const SizedBox(height: 14),
                      _buildAddFriendBox(theme),
                    ],
                    if (_showRequests) ...[
                      const SizedBox(height: 14),
                      _buildRequestsBox(theme),
                    ],
                    const SizedBox(height: 16),
                    _buildSearchBox(theme),
                    const SizedBox(height: 18),
                    if (_isLoading)
                      _buildLoading(theme)
                    else if (_error != null)
                      _buildErrorState(theme)
                    else if (_friends.isEmpty)
                      _buildEmptyState(theme)
                    else
                      ..._friends.map(_buildFriendCard),
                  ],
                ),
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
        padding: const EdgeInsets.all(10),
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
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddFriendBox(AppThemeController theme) {
    return Container(
      padding: const EdgeInsets.all(12),
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
          Expanded(
            child: TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              style: TextStyle(
                color: theme.textColor,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: _t('Nhập email bạn bè', 'Friend email', '好友邮箱'),
                hintStyle: TextStyle(color: theme.mutedTextColor),
                prefixIcon: Icon(
                  Icons.alternate_email_rounded,
                  color: theme.primaryColor,
                ),
                border: InputBorder.none,
              ),
              onSubmitted: (_) => _sendFriendRequest(),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: theme.primaryColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: IconButton(
              onPressed: _isSending ? null : _sendFriendRequest,
              icon: _isSending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestsBox(AppThemeController theme) {
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.mark_email_unread_rounded, color: theme.primaryColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _t('Lời mời kết bạn', 'Friend requests', '好友邀请'),
                  style: TextStyle(
                    color: theme.textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                onPressed: _isLoadingRequests ? null : _loadIncomingRequests,
                icon: Icon(Icons.refresh_rounded, color: theme.primaryColor),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_isLoadingRequests)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: CircularProgressIndicator(color: theme.primaryColor),
              ),
            )
          else if (_requestError != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                _requestError!,
                style: TextStyle(
                  color: const Color(0xFFEF4444),
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else if (_requests.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Center(
                child: Text(
                  _t(
                    'Chưa có lời mời kết bạn',
                    'No friend requests',
                    '暂无好友邀请',
                  ),
                  style: TextStyle(
                    color: theme.mutedTextColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
          else
            ..._requests.map((request) => _buildRequestCard(request)),
        ],
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    final theme = appThemeController;
    final name = request['name']?.toString() ?? '';
    final email = request['email']?.toString() ?? '';
    final initial = name.trim().isNotEmpty
        ? name.trim()[0].toUpperCase()
        : email.trim().isNotEmpty
            ? email.trim()[0].toUpperCase()
            : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.backgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.mutedTextColor.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: theme.primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                initial,
                style: TextStyle(
                  color: theme.primaryColor,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? _t('Người dùng', 'User', '用户') : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.textColor,
                    fontSize: 15,
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
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _buildRequestActionButton(
            icon: Icons.close_rounded,
            color: const Color(0xFFEF4444),
            onTap: () => _respondFriendRequest(request, accept: false),
          ),
          const SizedBox(width: 8),
          _buildRequestActionButton(
            icon: Icons.check_rounded,
            color: const Color(0xFF22C55E),
            onTap: () => _respondFriendRequest(request, accept: true),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: _isRespondingRequest ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 22),
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
          _loadFriends();
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
                    _loadFriends();
                  },
                  icon: Icon(Icons.close_rounded, color: theme.mutedTextColor),
                ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
        ),
      ),
    );
  }

  Widget _buildFriendCard(Map<String, dynamic> friend) {
    final theme = appThemeController;
    final name = friend['name']?.toString() ?? '';
    final email = friend['email']?.toString() ?? '';
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

  Widget _buildLoading(AppThemeController theme) {
    return Padding(
      padding: const EdgeInsets.only(top: 100),
      child: Center(
        child: CircularProgressIndicator(color: theme.primaryColor),
      ),
    );
  }

  Widget _buildErrorState(AppThemeController theme) {
    return Padding(
      padding: const EdgeInsets.only(top: 100),
      child: Column(
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 68,
            color: theme.mutedTextColor.withValues(alpha: 0.55),
          ),
          const SizedBox(height: 14),
          Text(
            _error ?? _t('Không thể tải bạn bè', 'Cannot load friends', '无法加载好友'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.textColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: _loadFriends,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(_t('Thử lại', 'Retry', '重试')),
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
