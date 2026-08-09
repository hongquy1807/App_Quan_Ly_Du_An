import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeMode { light, dark, pink }

class AppThemeController extends ChangeNotifier {
  static const _storageKey = 'app_theme_mode';

  AppThemeMode _mode = AppThemeMode.light;

  AppThemeMode get mode => _mode;

  bool get isDark => _mode == AppThemeMode.dark;

  Color get primaryColor {
    switch (_mode) {
      case AppThemeMode.light:
        return const Color(0xFF6366F1);
      case AppThemeMode.dark:
        return const Color(0xFF8B5CF6);
      case AppThemeMode.pink:
        return const Color(0xFFEC4899);
    }
  }

  Color get backgroundColor {
    switch (_mode) {
      case AppThemeMode.light:
        return const Color(0xFFF8FAFC);
      case AppThemeMode.dark:
        return const Color(0xFF111827);
      case AppThemeMode.pink:
        return const Color(0xFFFFF1F7);
    }
  }

  Color get surfaceColor {
    switch (_mode) {
      case AppThemeMode.light:
        return Colors.white;
      case AppThemeMode.dark:
        return const Color(0xFF1F2937);
      case AppThemeMode.pink:
        return Colors.white;
    }
  }

  Color get textColor {
    switch (_mode) {
      case AppThemeMode.light:
      case AppThemeMode.pink:
        return const Color(0xFF1F2937);
      case AppThemeMode.dark:
        return const Color(0xFFF9FAFB);
    }
  }

  Color get mutedTextColor {
    switch (_mode) {
      case AppThemeMode.light:
      case AppThemeMode.pink:
        return const Color(0xFF6B7280);
      case AppThemeMode.dark:
        return const Color(0xFFD1D5DB);
    }
  }

  ThemeData get themeData {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: isDark ? Brightness.dark : Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Roboto',
      colorScheme: colorScheme,
      scaffoldBackgroundColor: backgroundColor,
      primaryColor: primaryColor,
      appBarTheme: AppBarTheme(
        backgroundColor: surfaceColor,
        foregroundColor: textColor,
        elevation: 0,
        centerTitle: true,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primaryColor;
          return null;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primaryColor.withValues(alpha: 0.35);
          }
          return null;
        }),
      ),
    );
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final rawValue = prefs.getString(_storageKey);
    _mode = AppThemeMode.values.firstWhere(
      (mode) => mode.name == rawValue,
      orElse: () => AppThemeMode.light,
    );
    notifyListeners();
  }

  Future<void> setMode(AppThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, mode.name);
  }
}

final appThemeController = AppThemeController();
