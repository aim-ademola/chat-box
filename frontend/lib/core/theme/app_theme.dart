import 'package:frontend/core/theme/app_theme_colors.dart';
import 'package:flutter/material.dart';

class AppTheme {
  static const _lightColors = AppThemeColors(
    headerBackground: Color(0xFF2D8C80),
    messageSheet: Colors.white,
    secondaryText: Color(0xFF7A8482),
    inactiveIcon: Color(0xFF98A09E),
    badge: Color(0xFFFF5A5F),
    online: Color(0xFF1EDB76),
    offline: Color(0xFFBEC4C3),
    handle: Color(0xFFD7DDDC),
    searchBorder: Color(0xFF57A59A),
    storyRingMuted: Color(0xFF8EC1BA),
  );

  static const _darkColors = AppThemeColors(
    headerBackground: Color(0xFF103A35),
    messageSheet: Color.fromARGB(255, 0, 0, 0),
    secondaryText: Color(0xFF8D9794),
    inactiveIcon: Color(0xFF66706D),
    badge: Color(0xFFFF5A5F),
    online: Color(0xFF1EDB76),
    offline: Color(0xFF87908E),
    handle: Color(0xFF303937),
    searchBorder: Color(0xFF365754),
    storyRingMuted: Color(0xFF5A7773),
  );

  ThemeData get light {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xFF2D8C80),
      onPrimary: Colors.white,
      secondary: Color(0xFF6BC4B5),
      onSecondary: Colors.white,
      error: Color(0xFFFF5A5F),
      onError: Colors.white,
      surface: Color(0xFFF7F8F8),
      onSurface: Color(0xFF0E1B18),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      fontFamily: 'caros',
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: _lightColors.messageSheet,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: _lightColors.inactiveIcon,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
        selectedLabelStyle: const TextStyle(
          fontFamily: 'circular',
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: 'circular',
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      extensions: const [_lightColors],
    );
  }

  ThemeData get dark {
    const colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFF6ED3C2),
      onPrimary: Color(0xFF081311),
      secondary: Color(0xFF2A6E65),
      onSecondary: Colors.white,
      error: Color(0xFFFF5A5F),
      onError: Colors.white,
      surface: Color(0xFF081311),
      onSurface: Color(0xFFF4F7F6),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      fontFamily: 'caros',
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: _darkColors.messageSheet,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: _darkColors.inactiveIcon,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
        selectedLabelStyle: const TextStyle(
          fontFamily: 'circular',
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: 'circular',
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      extensions: const [_darkColors],
    );
  }
}
