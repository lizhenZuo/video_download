import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_localizations.dart';

class AppLocaleController extends ValueNotifier<Locale?> {
  AppLocaleController._(super.value);

  static final AppLocaleController instance = AppLocaleController._(null);

  static Future<void> initialize() async {
    instance.value = await AppLocaleStore.loadSavedLocale();
  }

  Future<void> updateLocale(Locale locale) async {
    final normalized = AppLocalizations.resolve(locale);
    if (_sameLocale(value, normalized)) {
      return;
    }

    await AppLocaleStore.saveLocale(normalized);
    value = normalized;
  }

  static bool _sameLocale(Locale? left, Locale? right) {
    if (left == null || right == null) {
      return left == right;
    }

    return left.languageCode == right.languageCode &&
        left.scriptCode == right.scriptCode;
  }
}

class AppLocaleStore {
  static const _localeKey = 'app.locale';

  static Future<Locale?> loadSavedLocale() async {
    final preferences = await SharedPreferences.getInstance();
    final value = preferences.getString(_localeKey);
    return AppLocalizations.localeFromStorageKey(value);
  }

  static Future<void> saveLocale(Locale locale) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _localeKey,
      AppLocalizations.localeStorageKey(locale),
    );
  }
}
