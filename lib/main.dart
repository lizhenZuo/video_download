import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'home_page.dart';
import 'l10n/app_locale_store.dart';
import 'l10n/app_localizations.dart';
import 'theme/app_theme_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppLocaleController.initialize();
  await AppThemeController.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF0B3B66);

    return ValueListenableBuilder<Locale?>(
      valueListenable: AppLocaleController.instance,
      builder: (context, locale, child) {
        return ValueListenableBuilder<ThemeMode>(
          valueListenable: AppThemeController.instance,
          builder: (context, themeMode, child) {
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              title: AppLocalizations.current.appName,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: AppLocalizations.supportedLocales,
              locale: locale,
              localeListResolutionCallback: (locales, supportedLocales) {
                return AppLocalizations.resolveFromList(locales);
              },
              themeMode: themeMode,
              theme: _buildLightTheme(seed),
              darkTheme: _buildDarkTheme(seed),
              home: const HomePage(),
            );
          },
        );
      },
    );
  }
}

ThemeData _buildLightTheme(Color seed) {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
      surface: const Color(0xFFFFFCF5),
    ),
    scaffoldBackgroundColor: const Color(0xFFF7F2E8),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(18)),
        borderSide: BorderSide.none,
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 18),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
    ),
  );
}

ThemeData _buildDarkTheme(Color seed) {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
      surface: const Color(0xFF15212D),
      onSurface: const Color(0xFFF1F6FB),
    ),
    scaffoldBackgroundColor: const Color(0xFF0F1822),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      foregroundColor: Color(0xFFF1F6FB),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: Color(0xFF1A2633),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(18)),
        borderSide: BorderSide.none,
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 18),
    ),
    cardTheme: CardThemeData(
      color: const Color(0xFF15212D),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: const Color(0xFF15212D),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
    ),
    dividerColor: const Color(0xFF263647),
  );
}
