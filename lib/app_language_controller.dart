import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguageMode { vietnamese, english, chinese }

class AppLanguageController extends ChangeNotifier {
  static const storageKey = 'app_language';

  AppLanguageMode _mode = AppLanguageMode.vietnamese;

  AppLanguageMode get mode => _mode;

  String text(String vi, String en, String zh) {
    switch (_mode) {
      case AppLanguageMode.english:
        return en;
      case AppLanguageMode.chinese:
        return zh;
      case AppLanguageMode.vietnamese:
        return vi;
    }
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final rawValue = prefs.getString(storageKey);
    _mode = AppLanguageMode.values.firstWhere(
      (language) => language.name == rawValue,
      orElse: () => AppLanguageMode.vietnamese,
    );
    notifyListeners();
  }

  Future<void> setMode(AppLanguageMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, mode.name);
  }
}

final appLanguageController = AppLanguageController();
