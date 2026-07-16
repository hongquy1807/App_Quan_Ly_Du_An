import 'package:flutter/material.dart';

import 'chat_screen.dart';
import 'create_task_screen.dart';
import 'forgot_password_screen.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'notification_screen.dart';
import 'profile_screen.dart';
import 'project_screen.dart';
import 'register_screen.dart';
import 'reset_password_screen.dart';
import 'timeline_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quản lý dự án',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/forgot-password': (context) => const ForgotPasswordScreen(),
        '/home': (context) => const HomeScreen(),
        '/timeline': (context) => const TimelineScreen(),
        '/projects': (context) => const ProjectScreen(),
        '/chat': (context) => const ChatScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/notifications': (context) => const NotificationScreen(),
        '/create-task': (context) => const CreateTaskScreen(),
      },
      onGenerateRoute: (settings) {
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
  }
}
