import 'package:flutter/material.dart';

class AppTheme {
  // Deep Professional Dark Blue Palette
  static const Color primaryDark = Color(0xFF0A192F);       // Deep Midnight Navy
  static const Color primaryCard = Color(0xFF172A45);       // Rich Navy Card
  static const Color primarySurface = Color(0xFF0E1E38);    // Surface Container
  static const Color accentBlue = Color(0xFF2563EB);        // Vivid Cobalt Blue
  static const Color accentCyan = Color(0xFF38BDF8);        // Electric Cyan Highlight
  static const Color accentGlow = Color(0xFF1D4ED8);        // Border Glow

  // Status Colors
  static const Color statusSafe = Color(0xFF10B981);         // Emerald Green
  static const Color statusWarning = Color(0xFFF59E0B);      // Amber Alert
  static const Color statusDanger = Color(0xFFEF4444);       // Crimson Emergency
  static const Color statusMuted = Color(0xFF64748B);        // Slate Gray

  // Text Colors
  static const Color textLight = Color(0xFFF8FAFC);         // Crisp White
  static const Color textMuted = Color(0xFF94A3B8);         // Soft Silver
  static const Color textDim = Color(0xFF64748B);           // Dimmed Label

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: primaryDark,
      primaryColor: accentBlue,
      colorScheme: const ColorScheme.dark(
        primary: accentBlue,
        secondary: accentCyan,
        surface: primaryCard,
        error: statusDanger,
        onPrimary: Colors.white,
        onSurface: textLight,
      ),
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryDark,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textLight,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(color: textLight),
      ),
      cardTheme: CardThemeData(
        color: primaryCard,
        elevation: 4,
        shadowColor: Colors.black45,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: accentGlow.withOpacity(0.3), width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentBlue,
          foregroundColor: Colors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accentCyan,
          side: const BorderSide(color: accentBlue, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: primarySurface,
        hintStyle: const TextStyle(color: textDim, fontSize: 14),
        labelStyle: const TextStyle(color: textMuted, fontSize: 14),
        prefixIconColor: textMuted,
        suffixIconColor: textMuted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accentCyan, width: 1.8),
        ),
      ),
    );
  }
}
