import 'package:flutter/material.dart';

/// Central palette for the whole app. Dark-first glassmorphism: a deep
/// navy/indigo base so frosted glass surfaces and gradient accents have
/// something rich to sit on top of.
class AppColors {
  AppColors._();

  static const Color backgroundBase = Color(0xFF0A0C18);
  static const Color backgroundIndigo = Color(0xFF13152B);
  static const Color backgroundViolet = Color(0xFF1B1338);

  static const Color accentViolet = Color(0xFF8B6CFF);
  static const Color accentBlue = Color(0xFF5B8DEF);
  static const Color accentCyan = Color(0xFF4FD8D0);
  static const Color accentPink = Color(0xFFEC6FA8);

  static const Color success = Color(0xFF3DDC84);
  static const Color warning = Color(0xFFF5B94E);
  static const Color danger = Color(0xFFEF5B6C);

  static const Color textPrimary = Color(0xFFF5F6FA);
  static const Color textSecondary = Color(0xB3F5F6FA); // ~70% white
  static const Color textMuted = Color(0x73F5F6FA); // ~45% white

  static const Color glassSurface = Color(0x14FFFFFF); // ~8% white
  static const Color glassSurfaceStrong = Color(0x1FFFFFFF); // ~12% white
  static const Color glassBorder = Color(0x26FFFFFF); // ~15% white

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accentViolet, accentBlue],
  );

  static const LinearGradient auroraGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accentViolet, accentPink, accentCyan],
  );
}

class AppRadius {
  AppRadius._();
  static const double sm = 12;
  static const double md = 18;
  static const double lg = 24;
  static const double pill = 999;
}

class AppSpacing {
  AppSpacing._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.backgroundBase,
    colorScheme: const ColorScheme.dark(
      surface: AppColors.backgroundIndigo,
      primary: AppColors.accentViolet,
      secondary: AppColors.accentCyan,
      error: AppColors.danger,
      onSurface: AppColors.textPrimary,
    ),
  );

  final textTheme = base.textTheme
      .apply(bodyColor: AppColors.textPrimary, displayColor: AppColors.textPrimary)
      .copyWith(
        headlineSmall: base.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        titleLarge: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        titleMedium: base.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary, height: 1.4),
        bodySmall: base.textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
        labelLarge: base.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.2),
      );

  return base.copyWith(
    textTheme: textTheme,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      foregroundColor: AppColors.textPrimary,
    ),
    dividerColor: AppColors.glassBorder,
    splashFactory: InkRipple.splashFactory,
    iconTheme: const IconThemeData(color: AppColors.textSecondary),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.backgroundIndigo,
      contentTextStyle: const TextStyle(color: AppColors.textPrimary),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      behavior: SnackBarBehavior.floating,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.glassSurface,
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.glassBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.glassBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.accentViolet, width: 1.5),
      ),
      hintStyle: const TextStyle(color: AppColors.textMuted),
    ),
  );
}
