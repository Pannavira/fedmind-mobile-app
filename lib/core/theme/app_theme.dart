import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // --- Modern Clinical & Medical Counseling Palette ---
  // Deep medical teal: inspires psychological trust, tranquility, and clinical precision
  static const Color primaryTeal = Color(0xFF0F766E); // Teal 700
  static const Color primaryTealDark = Color(0xFF115E59); // Teal 800
  static const Color primaryTealLight = Color(0xFF14B8A6); // Teal 500
  static const Color softTealBg = Color(0xFFF0FDFA); // Teal 50

  // Slate & Navy structure
  static const Color primaryNavy = Color(0xFF0F172A); // Slate 900
  static const Color surfaceLight = Color(0xFFF8FAFC); // Slate 50
  static const Color cardLight = Colors.white;
  static const Color textDark = Color(0xFF0F172A); // Slate 900
  static const Color textSecondary = Color(0xFF334155); // Slate 700
  static const Color textMuted = Color(0xFF64748B); // Slate 500
  static const Color borderLight = Color(0xFFE2E8F0); // Slate 200
  static const Color borderSubtle = Color(0xFFF1F5F9); // Slate 100

  // Clinical Accents
  static const Color accentCyan = Color(0xFF0284C7); // Sky 600
  static const Color accentIndigo = Color(0xFF4F46E5); // Indigo 600

  // Backwards compatibility aliases
  static const Color primaryBlue = primaryTeal;
  static const Color secondaryBlue = accentCyan;

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: surfaceLight,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryTeal,
        primary: primaryTeal,
        onPrimary: Colors.white,
        secondary: accentCyan,
        onSecondary: Colors.white,
        surface: surfaceLight,
        onSurface: textDark,
        error: const Color(0xFFEF4444),
      ),
      fontFamily: GoogleFonts.inter().fontFamily,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: textDark,
        elevation: 0,
        scrolledUnderElevation: 1.5,
        shadowColor: const Color(0x1A0F172A),
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          color: textDark,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
        iconTheme: const IconThemeData(color: textDark, size: 22),
      ),
      cardTheme: CardThemeData(
        color: cardLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: borderLight, width: 1),
        ),
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryTeal,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            letterSpacing: 0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryTeal,
          side: const BorderSide(color: borderLight, width: 1.2),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryTeal,
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryTeal, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEF4444)),
        ),
        labelStyle: const TextStyle(color: textMuted, fontSize: 13),
        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        elevation: 2,
        shadowColor: const Color(0x140F172A),
        indicatorColor: primaryTeal.withValues(alpha: 0.12),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: primaryTeal,
            );
          }
          return GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: textMuted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: primaryTeal, size: 23);
          }
          return const IconThemeData(color: textMuted, size: 22);
        }),
      ),
      dividerTheme: const DividerThemeData(
        color: borderSubtle,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
