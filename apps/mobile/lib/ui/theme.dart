import 'package:flutter/material.dart';

/// OffMesh Romantic & Stealth Theme System
/// Engineered for intimate couple messaging, privacy, and stealth disguise.
class OffMeshTheme {
  // --- Romantic Velvet & Rose Theme Tokens (Primary Couple Mode) ---
  static const Color romanticBackground = Color(0xFF0B0B10);
  static const Color romanticSurface = Color(0xFF151520);
  static const Color romanticSurfaceSubtle = Color(0xFF1E1E2D);
  static const Color romanticSurfaceRaised = Color(0xFF27273A);

  static const Color passionRose = Color(0xFFE11D48); // Deep vibrant rose
  static const Color passionRoseLight = Color(0xFFFB7185);
  static const Color passionRosePressed = Color(0xFFBE123C);
  static const Color blush = Color(0xFFFDA4AF);
  static const Color champagneGold = Color(0xFFF59E0B);

  static const Color textWhite = Color(0xFFF8FAFC);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color textDarker = Color(0xFF64748B);

  static const Color borderRomantic = Color(0xFF2A2A3E);
  static const Color borderSubtle = Color(0xFF1E1E2F);

  // Status indicators
  static const Color statusOnline = Color(0xFF10B981);
  static const Color statusPending = Color(0xFFF59E0B);
  static const Color statusError = Color(0xFFEF4444);

  // Chat Bubble Surfaces (Couples)
  static const Color bubbleOutgoing = Color(0xFFE11D48);
  static const Color bubbleOutgoingEnd = Color(0xFFC0153D);
  static const Color bubbleIncoming = Color(0xFF1E1E2C);
  static const Color bubbleIncomingText = Color(0xFFF8FAFC);
  static const Color bubbleOutgoingText = Color(0xFFFFFFFF);

  // --- Classic Minimal Light / Stealth Tokens ---
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

  static const Color focus = Color(0xFFE11D48);

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
  static const double radiusCard = 20.0;
  static const double radiusButton = 14.0;
  static const double radiusInput = 14.0;
  static const double radiusBubble = 20.0;

  /// Romantic Velvet Dark Theme (Default for Lovers & Couple Sanctuary)
  static ThemeData get romanticTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: romanticBackground,
      colorScheme: const ColorScheme.dark(
        primary: passionRose,
        onPrimary: Colors.white,
        secondary: blush,
        surface: romanticSurface,
        onSurface: textWhite,
        error: statusError,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: romanticBackground,
        foregroundColor: textWhite,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textWhite,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
      ),
      cardTheme: CardThemeData(
        color: romanticSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          side: const BorderSide(color: borderRomantic, width: 1),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: romanticSurface,
        selectedItemColor: passionRose,
        unselectedItemColor: textDarker,
        selectedLabelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: romanticSurfaceSubtle,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: const BorderSide(color: borderRomantic),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: const BorderSide(color: borderRomantic),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: const BorderSide(color: passionRose, width: 1.5),
        ),
        hintStyle: const TextStyle(color: textDarker, fontSize: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: passionRose,
          foregroundColor: Colors.white,
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
          foregroundColor: passionRose,
          side: const BorderSide(color: passionRose, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusButton),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
    );
  }

  /// Stealth Minimal Light Theme (For Decoy / Camouflage Mode)
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
