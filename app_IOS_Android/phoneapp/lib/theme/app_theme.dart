import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phoneapp/utils/responsive.dart';

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
  
  /// Tworzy responsywny TextTheme bazując na rozmiarze ekranu
  static TextTheme responsiveTextTheme(BuildContext context) {
    Responsive.init(context);
    
    final baseTheme = GoogleFonts.montserratTextTheme();
    
    return TextTheme(
      displayLarge: baseTheme.displayLarge?.copyWith(
        fontSize: Responsive.fontSize(57),
        color: AppColors.textPrimary,
      ),
      displayMedium: baseTheme.displayMedium?.copyWith(
        fontSize: Responsive.fontSize(45),
        color: AppColors.textPrimary,
      ),
      displaySmall: baseTheme.displaySmall?.copyWith(
        fontSize: Responsive.fontSize(36),
        color: AppColors.textPrimary,
      ),
      headlineLarge: baseTheme.headlineLarge?.copyWith(
        fontSize: Responsive.fontSize(32),
        color: AppColors.textPrimary,
      ),
      headlineMedium: baseTheme.headlineMedium?.copyWith(
        fontSize: Responsive.fontSize(28),
        color: AppColors.textPrimary,
      ),
      headlineSmall: baseTheme.headlineSmall?.copyWith(
        fontSize: Responsive.fontSize(24),
        color: AppColors.textPrimary,
      ),
      titleLarge: baseTheme.titleLarge?.copyWith(
        fontSize: Responsive.fontSize(22),
        color: AppColors.textPrimary,
      ),
      titleMedium: baseTheme.titleMedium?.copyWith(
        fontSize: Responsive.fontSize(16),
        color: AppColors.textPrimary,
      ),
      titleSmall: baseTheme.titleSmall?.copyWith(
        fontSize: Responsive.fontSize(14),
        color: AppColors.textPrimary,
      ),
      bodyLarge: baseTheme.bodyLarge?.copyWith(
        fontSize: Responsive.fontSize(16),
        color: AppColors.textPrimary,
      ),
      bodyMedium: baseTheme.bodyMedium?.copyWith(
        fontSize: Responsive.fontSize(14),
        color: AppColors.textPrimary,
      ),
      bodySmall: baseTheme.bodySmall?.copyWith(
        fontSize: Responsive.fontSize(12),
        color: AppColors.textPrimary,
      ),
      labelLarge: baseTheme.labelLarge?.copyWith(
        fontSize: Responsive.fontSize(14),
        color: AppColors.textPrimary,
      ),
      labelMedium: baseTheme.labelMedium?.copyWith(
        fontSize: Responsive.fontSize(12),
        color: AppColors.textPrimary,
      ),
      labelSmall: baseTheme.labelSmall?.copyWith(
        fontSize: Responsive.fontSize(11),
        color: AppColors.textPrimary,
      ),
    );
  }
}

/// Pomocnicze rozszerzenie do responsywnych rozmiarów
extension ResponsiveSizes on BuildContext {
  /// Inicjalizuje Responsive i zwraca rozmiar ekranu
  ScreenSize get screenSize {
    Responsive.init(this);
    return Responsive.screenSize;
  }
  
  /// Czy to małe urządzenie?
  bool get isSmallDevice {
    Responsive.init(this);
    return Responsive.isSmallDevice;
  }
  
  /// Czy to tablet?
  bool get isTablet {
    Responsive.init(this);
    return Responsive.isTablet;
  }
  
  /// Responsywny padding
  double rp(double value) {
    Responsive.init(this);
    return Responsive.padding(value);
  }
  
  /// Responsywny rozmiar czcionki
  double rf(double value) {
    Responsive.init(this);
    return Responsive.fontSize(value);
  }
  
  /// Responsywny rozmiar ikony
  double ri(double value) {
    Responsive.init(this);
    return Responsive.iconSize(value);
  }
  
  /// Responsywny radius
  double rr(double value) {
    Responsive.init(this);
    return Responsive.radius(value);
  }
  
  /// Responsywna wysokość
  double rh(double value) {
    Responsive.init(this);
    return Responsive.height(value);
  }
  
  /// Responsywna wartość sp
  double r(double value) {
    Responsive.init(this);
    return Responsive.sp(value);
  }
}
