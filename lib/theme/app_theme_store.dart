import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppThemeController extends ValueNotifier<ThemeMode> {
  AppThemeController._(super.value);

  static final AppThemeController instance =
      AppThemeController._(ThemeMode.system);

  static Future<void> initialize() async {
    instance.value =
        await AppThemeStore.loadSavedThemeMode() ?? ThemeMode.system;
  }

  Future<void> updateThemeMode(ThemeMode mode) async {
    if (value == mode) {
      return;
    }

    await AppThemeStore.saveThemeMode(mode);
    value = mode;
  }
}

class AppThemeStore {
  static const _themeModeKey = 'app.theme_mode';

  static Future<ThemeMode?> loadSavedThemeMode() async {
    final preferences = await SharedPreferences.getInstance();
    final value = preferences.getString(_themeModeKey);

    return switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      _ => null,
    };
  }

  static Future<void> saveThemeMode(ThemeMode mode) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
        _themeModeKey,
        switch (mode) {
          ThemeMode.light => 'light',
          ThemeMode.dark => 'dark',
          ThemeMode.system => 'system',
        });
  }
}
