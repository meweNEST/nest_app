import 'package:flutter/material.dart';

class AppTheme {
  // Brand Colors
  static const Color creamBackground = Color(0xFFF8F4E3);
  static const Color sageGreen = Color(0xFF87A981);
  static const Color terracotta = Color(0xFFE9937D);
  static const Color darkText = Color(0xFF333333);
  static const Color secondaryText = Color(0xFF666666);
  static const Color white = Colors.white;

  // Booking-specific colors (MUST exist or app crashes)
  static const Color bookingButtonColor = Color.fromRGBO(248, 124, 200, 1);
  static const Color bookingButtonHoverColor = Color.fromRGBO(178, 229, 209, 1);
  static const Color bookingButtonTextColor = Colors.white;

  // Global theme
  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: sageGreen,
    scaffoldBackgroundColor: white,

    colorScheme: const ColorScheme.light(
      primary: sageGreen,
      secondary: terracotta,
      background: creamBackground,
      surface: white,
      onPrimary: white,
      onSecondary: white,
      onBackground: darkText,
      onSurface: darkText,
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: white,
      foregroundColor: darkText,
      elevation: 0,
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        foregroundColor: white,
        backgroundColor: sageGreen,
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),

    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: white,
      selectedItemColor: sageGreen,
      unselectedItemColor: secondaryText,
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
    ),

    textTheme: const TextTheme(
      displayLarge: TextStyle(fontSize: 57, fontWeight: FontWeight.bold, color: darkText),
      displayMedium: TextStyle(fontSize: 45, fontWeight: FontWeight.bold, color: darkText),
      displaySmall: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: darkText),
      headlineLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: darkText),
      headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: darkText),
      headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: darkText),
      titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: darkText),
      titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: darkText),
      titleSmall: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: darkText),
      bodyLarge: TextStyle(fontSize: 16, color: darkText),
      bodyMedium: TextStyle(fontSize: 14, color: darkText),
      bodySmall: TextStyle(fontSize: 12, color: secondaryText),
      labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: white),
      labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: secondaryText),
      labelSmall: TextStyle(fontSize: 11, color: secondaryText),
    ),
  );
}
