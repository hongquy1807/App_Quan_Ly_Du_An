import 'package:flutter/material.dart';

import 'app_shell.dart';
import 'app_theme_controller.dart';
import 'create_project_screen.dart';
import 'create_task_screen.dart';
import 'forgot_password_screen.dart';
import 'login_screen.dart';
import 'notification_screen.dart';
import 'project_members_screen.dart';
import 'register_screen.dart';
import 'reset_password_screen.dart';
import 'services/auth_service.dart';
import 'widgets/app_bottom_navigation.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await appThemeController.load();
  final initialRoute = await AuthService.shouldAutoLogin() ? '/home' : '/login';
  runApp(MyApp(initialRoute: initialRoute));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.initialRoute = '/login'});

  final String initialRoute;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appThemeController,
      builder: (context, _) {
        return MaterialApp(
          title: 'Quản lý dự án',
          theme: appThemeController.themeData,
          initialRoute: initialRoute,
          routes: {
            '/login': (context) => const LoginScreen(),
            '/register': (context) => const RegisterScreen(),
            '/forgot-password': (context) => const ForgotPasswordScreen(),
            '/home': (context) =>
                const AppShell(initialItem: AppBottomNavItem.home),
            '/timeline': (context) =>
                const AppShell(initialItem: AppBottomNavItem.timeline),
            '/projects': (context) =>
                const AppShell(initialItem: AppBottomNavItem.projects),
            '/chat': (context) =>
                const AppShell(initialItem: AppBottomNavItem.messages),
            '/profile': (context) =>
                const AppShell(initialItem: AppBottomNavItem.me),
            '/notifications': (context) => const NotificationScreen(),
            '/create-project': (context) => const CreateProjectScreen(),
          },
          onGenerateRoute: (settings) {
            if (settings.name == '/project-members') {
              final args = settings.arguments as Map<String, dynamic>?;
              final rawMembers = args?['members'] as List<dynamic>?;
              return MaterialPageRoute(
                builder: (context) => ProjectMembersScreen(
                  project: args?['project'] as Map<String, dynamic>?,
                  members: rawMembers
                      ?.map(
                        (member) => Map<String, dynamic>.from(member as Map),
                      )
                      .toList(),
                ),
              );
            }

            if (settings.name == '/create-task') {
              final args = settings.arguments as Map<String, dynamic>?;
              final rawMembers = args?['members'] as List<dynamic>?;
              return MaterialPageRoute(
                builder: (context) => CreateTaskScreen(
                  project: args?['project'] as Map<String, dynamic>?,
                  members: rawMembers
                      ?.map(
                        (member) => Map<String, dynamic>.from(member as Map),
                      )
                      .toList(),
                ),
              );
            }

            if (settings.name == '/reset-password') {
              final args = settings.arguments as Map<String, dynamic>;
              return MaterialPageRoute(
                builder: (context) => ResetPasswordScreen(
                  email: args['email'] ?? '',
                  resetToken: args['reset_token'] ?? '',
                ),
              );
            }

            return null;
          },
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
