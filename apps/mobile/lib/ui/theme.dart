import 'package:flutter/material.dart';

/// OffMesh Theme Specification - Monochrome Minimal
/// Strictly aligned with OFFMESH_THEME.md
class OffMeshTheme {
  // Color Tokens
  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceSubtle = Color(0xFFF7F7F8);
  static const Color surfaceRaised = Color(0xFFFFFFFF);

  static const Color textPrimary = Color(0xFF111111);
  static const Color textSecondary = Color(0xFF666666);
  static const Color textTertiary = Color(0xFF8A8A8A);

  static const Color border = Color(0xFFE5E5E5);
  static const Color borderStrong = Color(0xFFCFCFCF);

  static const Color actionPrimary = Color(0xFF111111);
  static const Color actionPrimaryPressed = Color(0xFF333333);
  static const Color actionOnPrimary = Color(0xFFFFFFFF);
  static const Color actionSecondary = Color(0xFFF2F2F2);
  static const Color actionSecondaryText = Color(0xFF111111);

  static const Color focus = Color(0xFF4B6FFF);

  // Semantic Status Colors
  static const Color statusPending = Color(0xFF8A6500);
  static const Color statusSuccess = Color(0xFF167A45);
  static const Color statusWarning = Color(0xFFA65300);
  static const Color statusError = Color(0xFFB42318);
  static const Color statusInfo = Color(0xFF2457A7);

  // Chat Bubble Surfaces
  static const Color bubbleIncoming = Color(0xFFF1F1F1);
  static const Color bubbleIncomingText = Color(0xFF111111);
  static const Color bubbleOutgoing = Color(0xFF111111);
  static const Color bubbleOutgoingText = Color(0xFFFFFFFF);

  // Spacing (4 dp base grid)
  static const double space1 = 4.0;
  static const double space2 = 8.0;
  static const double space3 = 12.0;
  static const double space4 = 16.0;
  static const double space5 = 20.0;
  static const double space6 = 24.0;
  static const double space8 = 32.0;
  static const double space10 = 40.0;
  static const double space12 = 48.0;

  // Radii
  static const double radiusCard = 16.0;
  static const double radiusButton = 12.0;
  static const double radiusInput = 12.0;
  static const double radiusBubble = 18.0;

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.light(
        primary: actionPrimary,
        onPrimary: actionOnPrimary,
        secondary: actionSecondary,
        surface: surface,
        onSurface: textPrimary,
        error: statusError,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          side: const BorderSide(color: border, width: 1),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: actionPrimary,
        unselectedItemColor: textTertiary,
        selectedLabelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceSubtle,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: const BorderSide(color: actionPrimary, width: 1.5),
        ),
        hintStyle: const TextStyle(color: textTertiary, fontSize: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: actionPrimary,
          foregroundColor: actionOnPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusButton),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: actionPrimary,
          side: const BorderSide(color: borderStrong),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusButton),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
    );
  }
}
