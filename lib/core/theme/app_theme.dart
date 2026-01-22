import 'package:flutter/material.dart';

class AppTheme {
  // NEST Color Palette (from Android)
  static const Color creamBackground = Color(0xFFFDF8F3);
  static const Color white = Color(0xFFFFFFFF);
  static const Color darkText = Color(0xFF2D2D2D);
  static const Color secondaryText = Color(0xFF757575);
  static const Color grayText = Color(0xFF9E9E9E);
  static const Color sageGreen = Color(0xFF7CAE7A);
  static const Color terracotta = Color(0xFFD4A574);
  static const Color coral = Color(0xFFFF6B6B);
  static const Color divider = Color(0xFFE0E0E0);
  
  static ThemeData get lightTheme {
    return ThemeData(
      primaryColor: sageGreen,
      scaffoldBackgroundColor: creamBackground,
      fontFamily: 'Charlevoix',
      
      appBarTheme: const AppBarTheme(
        backgroundColor: creamBackground,
        foregroundColor: darkText,
        elevation: 0,
        centerTitle: true,
      ),
      
      cardTheme: CardThemeData(
        color: white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: sageGreen,
          foregroundColor: white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: darkText,
        ),
        headlineMedium: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: darkText,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          color: darkText,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: secondaryText,
        ),
        bodySmall: TextStyle(
          fontSize: 13,
          color: secondaryText,
        ),
      ),
      
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: white,
        selectedItemColor: coral,
        unselectedItemColor: grayText,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
    );
  }
}
