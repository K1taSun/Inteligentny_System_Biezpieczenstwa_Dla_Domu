import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const Color midnight = Color(0xFF050E1F);
  static const Color navy = Color(0xFF0F1F3D);
  static const Color indigo = Color(0xFF1C2F5D);
  static const Color card = Color(0xFF1C2F5D);
  static const Color accent = Color(0xFF4CE0B3);
  static const Color warning = Color(0xFFFFB74D);
  static const Color success = Color(0xFF7DD177);
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFF9EB5D9);
  static const Color subtle = Color(0xFF324264);
}

class AppTheme {
  static ThemeData get theme {
    final textTheme = GoogleFonts.montserratTextTheme().apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.midnight,
      colorScheme: ColorScheme.dark(
        primary: AppColors.accent,
        secondary: AppColors.warning,
        tertiary: AppColors.success,
        surface: AppColors.navy,
        error: Colors.redAccent,
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        margin: EdgeInsets.zero,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.midnight,
        elevation: 0,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        selectedItemColor: AppColors.accent,
        unselectedItemColor: AppColors.textSecondary,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: false,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.navy.withValues(alpha: 0.8),
        indicatorColor: AppColors.accent.withValues(alpha: 0.2),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppColors.accent
                : AppColors.textSecondary,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => textTheme.labelMedium?.copyWith(
            color: states.contains(WidgetState.selected)
                ? AppColors.accent
                : AppColors.textSecondary,
            fontWeight:
                states.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.navy,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: AppColors.textSecondary,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.subtle,
        selectedColor: AppColors.accent.withValues(alpha: 0.2),
        labelStyle: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
