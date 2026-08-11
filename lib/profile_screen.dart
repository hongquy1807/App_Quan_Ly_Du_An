import 'package:flutter/material.dart';

import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme_controller.dart';
import 'completed_projects_screen.dart';
import 'feedback_screen.dart';
import 'friends_screen.dart';
import 'services/auth_service.dart';
import 'services/profile_service.dart';
import 'settings_screen.dart';
import 'widgets/app_bottom_navigation.dart';

enum ProfileLanguage { vietnamese, english, chinese }

String _profileText(ProfileLanguage language, String vi, String en, String zh) {
  switch (language) {
    case ProfileLanguage.vietnamese:
      return vi;
    case ProfileLanguage.english:
      return en;
    case ProfileLanguage.chinese:
      return zh;
  }
}

Future<ProfileLanguage> _loadProfileLanguage() async {
  final prefs = await SharedPreferences.getInstance();
  final rawValue = prefs.getString('app_language');
  return ProfileLanguage.values.firstWhere(
    (language) => language.name == rawValue,
    orElse: () => ProfileLanguage.vietnamese,
  );
}

class ProfileScreen extends StatefulWidget {
  final bool showBottomNavigation;

  const ProfileScreen({super.key, this.showBottomNavigation = true});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ProfileService _profileService = ProfileService();
  ProfileLanguage _language = ProfileLanguage.vietnamese;
  Map<String, dynamic> _userInfo = {
    'fullName': 'Nguyễn Văn A',
    'email': 'nguyenvana@email.com',
    'avatar': null,
    'phone': '0987 654 321',
    'birthday': '',
    'gender': 'Nam',
    'address': '',
    'joinDate': '01/01/2020',
    'skills': ['Flutter', 'React Native', 'Node.js', 'MongoDB'],
    'projects': 12,
    'tasksCompleted': 156,
  };
  bool _isLoadingProfile = false;

  @override
  void initState() {
    super.initState();
    _loadLanguage();
    _loadProfile();
  }

  String _t(String vi, String en, String zh) {
    return _profileText(_language, vi, en, zh);
  }

  Future<void> _loadLanguage() async {
    final language = await _loadProfileLanguage();
    if (!mounted) return;
    setState(() {
      _language = language;
    });
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoadingProfile = true;
    });

    try {
      final profile = await _profileService.getProfile();
      if (!mounted) return;
      setState(() {
        _userInfo = {
          ..._userInfo,
          'id': profile['id'],
          'fullName': profile['name']?.toString() ?? '',
          'email': profile['email']?.toString() ?? '',
          'avatar': profile['avatar']?.toString(),
          'birthday': profile['birthday']?.toString() ?? '',
          'address': profile['address']?.toString() ?? '',
        };
      });
    } on ApiException catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err.message)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingProfile = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appThemeController.backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              _buildProfileCard(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    _buildMenuItem(
                      icon: Icons.workspace_premium_rounded,
                      title: _t(
                        'Dự án đã hoàn thành',
                        'Completed projects',
                        '已完成项目',
                      ),
                      subtitle: _t(
                        'Xem lại các dự án bạn từng tham gia',
                        'Review projects you have participated in',
                        '查看你曾参与的项目',
                      ),
                      color: const Color(0xFF6366F1),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const CompletedProjectsScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    _buildMenuItem(
                      icon: Icons.people_alt_rounded,
                      title: _t('Bạn bè', 'Friends', '朋友'),
                      subtitle: _t(
                        'Quản lý bạn bè và người quen',
                        'Manage friends and contacts',
                        '管理朋友和联系人',
                      ),
                      color: const Color(0xFF3B82F6),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const FriendsScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    _buildMenuItem(
                      icon: Icons.description_rounded,
                      title: _t('CV điện tử', 'Digital CV', '电子简历'),
                      subtitle: _t(
                        'Tạo và quản lý CV của bạn',
                        'Create and manage your CV',
                        '创建和管理你的简历',
                      ),
                      color: const Color(0xFFEC4899),
                      isLocked: true,
                      onTap: () {
                        _showLockedFeatureDialog(
                          _t('CV điện tử', 'Digital CV', '电子简历'),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    _buildMenuItem(
                      icon: Icons.feedback_rounded,
                      title: _t('Hòm thư góp ý', 'Feedback inbox', '反馈信箱'),
                      subtitle: _t(
                        'Gửi ý kiến đóng góp cho chúng tôi',
                        'Send us your feedback',
                        '向我们发送反馈',
                      ),
                      color: const Color(0xFFF59E0B),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const FeedbackScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    _buildMenuItem(
                      icon: Icons.settings_rounded,
                      title: _t('Cài đặt ứng dụng', 'App settings', '应用设置'),
                      subtitle: _t(
                        'Tùy chỉnh giao diện và thông báo',
                        'Customize appearance and notifications',
                        '自定义外观和通知',
                      ),
                      color: const Color(0xFF10B981),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SettingsScreen(),
                          ),
                        );
                        if (mounted) _loadLanguage();
                      },
                    ),
                    const SizedBox(height: 8),
                    _buildMenuItem(
                      icon: Icons.group_add_rounded,
                      title: _t('Giới thiệu bạn bè', 'Invite friends', '邀请朋友'),
                      subtitle: _t(
                        'Mời bạn bè, người quen sử dụng ứng dụng',
                        'Invite friends and contacts to use the app',
                        '邀请朋友和熟人使用应用',
                      ),
                      color: const Color(0xFF3B82F6),
                      onTap: _showInviteFriendsDialog,
                    ),
                    const SizedBox(height: 8),
                    _buildMenuItem(
                      icon: Icons.logout_rounded,
                      title: _t('Đăng xuất', 'Log out', '退出登录'),
                      subtitle: _t(
                        'Đăng xuất khỏi tài khoản',
                        'Sign out of your account',
                        '退出当前账户',
                      ),
                      color: const Color(0xFFEF4444),
                      isLogout: true,
                      onTap: _showLogoutDialog,
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar:
          widget.showBottomNavigation ? _buildBottomNavigationBar() : null,
    );
  }

  Widget _buildProfileCard() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: GestureDetector(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProfileDetailScreen(userInfo: _userInfo),
            ),
          );
          if (mounted) _loadProfile();
        },
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: _buildProfileAvatarContent(size: 56, fontSize: 24),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _userInfo['fullName']?.toString() ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _userInfo['email']?.toString() ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: _isLoadingProfile
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileAvatarContent({
    required double size,
    required double fontSize,
  }) {
    final avatarUrl = _profileService.buildAvatarUrl(
      _userInfo['avatar']?.toString(),
    );
    if (avatarUrl != null) {
      return ClipOval(
        child: Image.network(
          avatarUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildAvatarLetter(fontSize);
          },
        ),
      );
    }

    return _buildAvatarLetter(fontSize);
  }

  Widget _buildAvatarLetter(double fontSize) {
    final name = _userInfo['fullName']?.toString().trim() ?? '';
    final letter = name.isNotEmpty ? name[0].toUpperCase() : 'U';
    return Center(
      child: Text(
        letter,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF6366F1),
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    bool isLocked = false,
    bool isLogout = false,
  }) {
    final theme = appThemeController;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.surfaceColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isLogout
                                ? const Color(0xFFEF4444)
                                : theme.textColor,
                          ),
                        ),
                      ),
                      if (isLocked) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _t('Sắp ra mắt', 'Soon', '即将推出'),
                            style: const TextStyle(
                              fontSize: 9,
                              color: Color(0xFF6B7280),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: isLogout
                          ? const Color(0xFFEF4444).withValues(alpha: 0.7)
                          : theme.mutedTextColor,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isLogout
                  ? Icons.arrow_forward_ios_rounded
                  : Icons.chevron_right_rounded,
              color: isLogout
                  ? const Color(0xFFEF4444).withValues(alpha: 0.5)
                  : theme.mutedTextColor,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return const AppBottomNavigation(
      currentItem: AppBottomNavItem.me,
    );
  }

  void _showLogoutDialog() {
    final theme = appThemeController;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          _t('Đăng xuất', 'Log out', '退出登录'),
          style: TextStyle(color: theme.textColor),
        ),
        content: Text(
          _t(
            'Bạn có chắc chắn muốn đăng xuất khỏi tài khoản?',
            'Are you sure you want to sign out?',
            '你确定要退出登录吗？',
          ),
          style: TextStyle(color: theme.mutedTextColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_t('Hủy', 'Cancel', '取消')),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/login',
                (route) => false,
              );
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    _t(
                      'Đã đăng xuất thành công',
                      'Signed out successfully',
                      '已成功退出登录',
                    ),
                  ),
                  backgroundColor: theme.primaryColor,
                ),
              );
            },
            child: Text(
              _t('Đăng xuất', 'Log out', '退出登录'),
              style: const TextStyle(
                color: Color(0xFFEF4444),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showLockedFeatureDialog(String featureName) {
    final theme = appThemeController;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(featureName, style: TextStyle(color: theme.textColor)),
        content: Text(
          _t(
            'Tính năng này đang được phát triển!',
            'This feature is still in development.',
            '此功能正在开发中。',
          ),
          style: TextStyle(color: theme.mutedTextColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_t('Đã hiểu', 'Got it', '知道了')),
          ),
        ],
      ),
    );
  }

  void _showInviteFriendsDialog() {
    final theme = appThemeController;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          _t('Giới thiệu bạn bè', 'Invite friends', '邀请朋友'),
          style: TextStyle(color: theme.textColor),
        ),
        content: Text(
          _t(
            'Hãy giới thiệu ứng dụng quản lý dự án này cho bạn bè, đồng nghiệp hoặc người quen cùng sử dụng.',
            'Share this project management app with friends, colleagues, or people you know.',
            '把这个项目管理应用分享给朋友、同事或熟人一起使用。',
          ),
          style: TextStyle(color: theme.mutedTextColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_t('Đóng', 'Close', '关闭')),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    _t(
                      'Đã sẵn sàng chia sẻ lời mời',
                      'Invitation is ready to share',
                      '邀请已准备好分享',
                    ),
                  ),
                  backgroundColor: theme.primaryColor,
                ),
              );
            },
            child: Text(
              _t('Chia sẻ', 'Share', '分享'),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class ProfileDetailScreen extends StatefulWidget {
  final Map<String, dynamic> userInfo;

  const ProfileDetailScreen({super.key, required this.userInfo});

  @override
  State<ProfileDetailScreen> createState() => _ProfileDetailScreenState();
}

class _ProfileDetailScreenState extends State<ProfileDetailScreen> {
  late Map<String, dynamic> _userInfo;
  final ProfileService _profileService = ProfileService();
  final ImagePicker _imagePicker = ImagePicker();
  ProfileLanguage _language = ProfileLanguage.vietnamese;

  @override
  void initState() {
    super.initState();
    _userInfo = Map<String, dynamic>.from(widget.userInfo);
    _loadLanguage();
  }

  String _t(String vi, String en, String zh) {
    return _profileText(_language, vi, en, zh);
  }

  Future<void> _loadLanguage() async {
    final language = await _loadProfileLanguage();
    if (!mounted) return;
    setState(() {
      _language = language;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appThemeController.backgroundColor,
      appBar: AppBar(
        title: Text(_t('Thông tin cá nhân', 'Personal information', '个人信息')),
        backgroundColor: appThemeController.surfaceColor,
        foregroundColor: appThemeController.textColor,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _showEditProfileSheet,
            icon: const Icon(Icons.edit_rounded),
            tooltip: _t('Cập nhật thông tin', 'Update information', '更新信息'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: _buildDetailAvatar(radius: 44, fontSize: 34),
          ),
          const SizedBox(height: 20),
          _ProfileInfoTile(
            icon: Icons.person_rounded,
            label: _t('Họ tên', 'Full name', '姓名'),
            value: _userInfo['fullName']?.toString() ?? '',
          ),
          _ProfileInfoTile(
            icon: Icons.email_rounded,
            label: 'Email',
            value: _userInfo['email']?.toString() ?? '',
          ),
          _ProfileInfoTile(
            icon: Icons.phone_rounded,
            label: _t('Số điện thoại', 'Phone number', '电话号码'),
            value: _userInfo['phone']?.toString() ?? '',
          ),
          _ProfileInfoTile(
            icon: Icons.cake_rounded,
            label: _t('Ngày sinh', 'Birthday', '生日'),
            value: _userInfo['birthday']?.toString() ?? '',
          ),
          _ProfileInfoTile(
            icon: Icons.location_on_rounded,
            label: _t('Địa chỉ', 'Address', '地址'),
            value: _userInfo['address']?.toString() ?? '',
          ),
        ],
      ),
    );
  }

  String get _avatarLetter {
    final name = _userInfo['fullName']?.toString().trim() ?? '';
    return name.isNotEmpty ? name[0].toUpperCase() : 'U';
  }

  Widget _buildDetailAvatar({
    required double radius,
    required double fontSize,
  }) {
    final avatarUrl = _profileService.buildAvatarUrl(
      _userInfo['avatar']?.toString(),
    );

    if (avatarUrl != null) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: const Color(0xFF6366F1),
        child: ClipOval(
          child: Image.network(
            avatarUrl,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return _buildDetailAvatarLetter(fontSize);
            },
          ),
        ),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFF6366F1),
      child: _buildDetailAvatarLetter(fontSize),
    );
  }

  Widget _buildDetailAvatarLetter(double fontSize) {
    return Text(
      _avatarLetter,
      style: TextStyle(
        color: Colors.white,
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  void _showEditProfileSheet() {
    final theme = appThemeController;
    final fullNameController = TextEditingController(
      text: _userInfo['fullName']?.toString() ?? '',
    );
    final emailController = TextEditingController(
      text: _userInfo['email']?.toString() ?? '',
    );
    final phoneController = TextEditingController(
      text: _userInfo['phone']?.toString() ?? '',
    );
    final birthdayController = TextEditingController(
      text: _userInfo['birthday']?.toString() ?? '',
    );
    final addressController = TextEditingController(
      text: _userInfo['address']?.toString() ?? '',
    );
    String? selectedAvatarPath = _userInfo['avatarPath']?.toString();
    var isSheetActive = true;

    showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.surfaceColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _t('Cập nhật thông tin', 'Update information', '更新信息'),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: theme.textColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  StatefulBuilder(
                    builder: (context, setSheetState) {
                      return Column(
                        children: [
                          Center(
                            child: GestureDetector(
                              onTap: () async {
                                final pickedImage =
                                    await _imagePicker.pickImage(
                                  source: ImageSource.gallery,
                                  imageQuality: 85,
                                );
                                if (pickedImage == null || !isSheetActive) {
                                  return;
                                }
                                setSheetState(() {
                                  selectedAvatarPath = pickedImage.path;
                                });
                              },
                              child: Stack(
                                children: [
                                  CircleAvatar(
                                    radius: 38,
                                    backgroundColor: const Color(0xFF6366F1),
                                    child: Text(
                                      fullNameController.text.trim().isNotEmpty
                                          ? fullNameController.text
                                              .trim()[0]
                                              .toUpperCase()
                                          : 'U',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: theme.backgroundColor,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.camera_alt_rounded,
                                        size: 18,
                                        color: theme.primaryColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            selectedAvatarPath == null
                                ? _t(
                                    'Nhấn vào ảnh đại diện để chọn ảnh',
                                    'Tap the avatar to choose an image',
                                    '点击头像选择图片',
                                  )
                                : _t(
                                    'Đã chọn ảnh đại diện',
                                    'Avatar image selected',
                                    '已选择头像图片',
                                  ),
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.mutedTextColor,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  _EditProfileField(
                    controller: fullNameController,
                    label: _t('Họ tên', 'Full name', '姓名'),
                  ),
                  _EditProfileField(controller: emailController, label: 'Email'),
                  _EditProfileField(
                    controller: phoneController,
                    label: _t('Số điện thoại', 'Phone number', '电话号码'),
                  ),
                  _EditProfileField(
                    controller: birthdayController,
                    label: _t('Ngày sinh', 'Birthday', '生日'),
                  ),
                  _EditProfileField(
                    controller: addressController,
                    label: _t('Địa chỉ', 'Address', '地址'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context, {
                          ..._userInfo,
                          'fullName': fullNameController.text.trim(),
                          'email': emailController.text.trim(),
                          'phone': phoneController.text.trim(),
                          'birthday': birthdayController.text.trim(),
                          'address': addressController.text.trim(),
                          'avatarPath': selectedAvatarPath,
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        _t('Lưu thay đổi', 'Save changes', '保存更改'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ).then((updatedInfo) {
      isSheetActive = false;
      if (!mounted || updatedInfo == null) return;
      setState(() {
        _userInfo = updatedInfo;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              'Đã cập nhật thông tin',
              'Information updated',
              '信息已更新',
            ),
          ),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    });
  }
}

class _EditProfileField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final int maxLines;

  const _EditProfileField({
    required this.controller,
    required this.label,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final theme = appThemeController;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: TextStyle(color: theme.textColor),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: theme.mutedTextColor),
          filled: true,
          fillColor: theme.backgroundColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: theme.mutedTextColor.withValues(alpha: 0.18),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: theme.mutedTextColor.withValues(alpha: 0.18),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: theme.primaryColor, width: 1.5),
          ),
        ),
      ),
    );
  }
}
class _ProfileInfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ProfileInfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = appThemeController;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: theme.primaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.mutedTextColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: theme.textColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
