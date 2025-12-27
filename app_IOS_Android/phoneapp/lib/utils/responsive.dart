import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Profesjonalny system responsywności dla różnych rozmiarów ekranów
/// Obsługuje ekrany od 5.7" do tabletów
class Responsive {
  static late MediaQueryData _mediaQueryData;
  static late double screenWidth;
  static late double screenHeight;
  static late double safeWidth;
  static late double safeHeight;
  static late double blockSizeHorizontal;
  static late double blockSizeVertical;
  static late double safeBlockHorizontal;
  static late double safeBlockVertical;
  static late double textScaleFactor;
  static late ScreenSize screenSize;
  static late EdgeInsets safePadding;
  
  /// Bazowy rozmiar ekranu do obliczeń (iPhone 14 Pro - 393 x 852)
  static const double _baseWidth = 393.0;
  static const double _baseHeight = 852.0;

  static void init(BuildContext context) {
    _mediaQueryData = MediaQuery.of(context);
    screenWidth = _mediaQueryData.size.width;
    screenHeight = _mediaQueryData.size.height;
    safePadding = _mediaQueryData.padding;
    
    safeWidth = screenWidth - safePadding.left - safePadding.right;
    safeHeight = screenHeight - safePadding.top - safePadding.bottom;
    
    blockSizeHorizontal = screenWidth / 100;
    blockSizeVertical = screenHeight / 100;
    
    safeBlockHorizontal = safeWidth / 100;
    safeBlockVertical = safeHeight / 100;
    
    // Określ kategorię rozmiaru ekranu
    screenSize = _getScreenSize();
    
    // Współczynnik skalowania tekstu (z ograniczeniem dla czytelności)
    textScaleFactor = _mediaQueryData.textScaler.scale(1.0).clamp(0.8, 1.3);
  }
  
  static ScreenSize _getScreenSize() {
    if (screenWidth < 360) {
      return ScreenSize.extraSmall; // Bardzo małe ekrany < 5.5"
    } else if (screenWidth < 400) {
      return ScreenSize.small;      // Małe ekrany 5.5" - 6"
    } else if (screenWidth < 450) {
      return ScreenSize.medium;     // Średnie ekrany 6" - 6.5"
    } else if (screenWidth < 600) {
      return ScreenSize.large;      // Duże ekrany 6.5"+
    } else {
      return ScreenSize.tablet;     // Tablety
    }
  }
  
  /// Skaluje wartość proporcjonalnie do szerokości ekranu
  static double w(double size) {
    return size * (screenWidth / _baseWidth);
  }
  
  /// Skaluje wartość proporcjonalnie do wysokości ekranu
  static double h(double size) {
    return size * (screenHeight / _baseHeight);
  }
  
  /// Skaluje wartość używając mniejszego współczynnika (bezpieczniejsze)
  static double sp(double size) {
    final widthRatio = screenWidth / _baseWidth;
    final heightRatio = screenHeight / _baseHeight;
    return size * math.min(widthRatio, heightRatio);
  }
  
  /// Rozmiar czcionki z uwzględnieniem preferencji użytkownika
  static double fontSize(double size) {
    final scaledSize = sp(size);
    // Ograniczenie dla małych ekranów
    if (screenSize == ScreenSize.extraSmall) {
      return (scaledSize * 0.9).clamp(10.0, size * 1.2);
    }
    return scaledSize.clamp(size * 0.75, size * 1.25);
  }
  
  /// Rozmiar ikon responsywny
  static double iconSize(double size) {
    switch (screenSize) {
      case ScreenSize.extraSmall:
        return size * 0.8;
      case ScreenSize.small:
        return size * 0.9;
      case ScreenSize.medium:
        return size;
      case ScreenSize.large:
        return size * 1.05;
      case ScreenSize.tablet:
        return size * 1.15;
    }
  }
  
  /// Padding responsywny
  static double padding(double size) {
    switch (screenSize) {
      case ScreenSize.extraSmall:
        return size * 0.7;
      case ScreenSize.small:
        return size * 0.85;
      case ScreenSize.medium:
        return size;
      case ScreenSize.large:
        return size * 1.1;
      case ScreenSize.tablet:
        return size * 1.3;
    }
  }
  
  /// Margin responsywny
  static double margin(double size) => padding(size);
  
  /// Radius responsywny
  static double radius(double size) {
    switch (screenSize) {
      case ScreenSize.extraSmall:
        return size * 0.8;
      case ScreenSize.small:
        return size * 0.9;
      case ScreenSize.medium:
        return size;
      case ScreenSize.large:
        return size * 1.05;
      case ScreenSize.tablet:
        return size * 1.15;
    }
  }
  
  /// Wysokość elementu UI responsywna
  static double height(double size) {
    switch (screenSize) {
      case ScreenSize.extraSmall:
        return size * 0.75;
      case ScreenSize.small:
        return size * 0.85;
      case ScreenSize.medium:
        return size;
      case ScreenSize.large:
        return size * 1.1;
      case ScreenSize.tablet:
        return size * 1.25;
    }
  }
  
  /// Wartość zależna od rozmiaru ekranu
  static T value<T>({
    required T extraSmall,
    T? small,
    T? medium,
    T? large,
    T? tablet,
  }) {
    switch (screenSize) {
      case ScreenSize.extraSmall:
        return extraSmall;
      case ScreenSize.small:
        return small ?? extraSmall;
      case ScreenSize.medium:
        return medium ?? small ?? extraSmall;
      case ScreenSize.large:
        return large ?? medium ?? small ?? extraSmall;
      case ScreenSize.tablet:
        return tablet ?? large ?? medium ?? small ?? extraSmall;
    }
  }
  
  /// Padding EdgeInsets responsywny
  static EdgeInsets paddingAll(double value) {
    return EdgeInsets.all(padding(value));
  }
  
  static EdgeInsets paddingSymmetric({
    double horizontal = 0,
    double vertical = 0,
  }) {
    return EdgeInsets.symmetric(
      horizontal: padding(horizontal),
      vertical: padding(vertical),
    );
  }
  
  static EdgeInsets paddingOnly({
    double left = 0,
    double top = 0,
    double right = 0,
    double bottom = 0,
  }) {
    return EdgeInsets.only(
      left: padding(left),
      top: padding(top),
      right: padding(right),
      bottom: padding(bottom),
    );
  }
  
  /// Czy to małe urządzenie?
  static bool get isSmallDevice => 
      screenSize == ScreenSize.extraSmall || screenSize == ScreenSize.small;
  
  /// Czy to tablet?
  static bool get isTablet => screenSize == ScreenSize.tablet;
  
  /// Czy to średnie/duże urządzenie?
  static bool get isLargeDevice => 
      screenSize == ScreenSize.large || screenSize == ScreenSize.tablet;
  
  /// Wysokość bottom navigation bar responsywna
  static double get navBarHeight {
    switch (screenSize) {
      case ScreenSize.extraSmall:
        return 60;
      case ScreenSize.small:
        return 65;
      case ScreenSize.medium:
        return 70;
      case ScreenSize.large:
        return 75;
      case ScreenSize.tablet:
        return 80;
    }
  }
  
  /// Maksymalna szerokość kontentu (dla dużych ekranów)
  static double get maxContentWidth {
    if (screenSize == ScreenSize.tablet) {
      return 600;
    }
    return screenWidth;
  }
}

enum ScreenSize {
  extraSmall, // < 360px width (~5.5" lub mniej)
  small,      // 360-400px (~5.5" - 6")
  medium,     // 400-450px (~6" - 6.5")
  large,      // 450-600px (~6.5"+)
  tablet,     // > 600px
}

/// Widget wrapper do inicjalizacji responsywności
class ResponsiveBuilder extends StatelessWidget {
  const ResponsiveBuilder({
    super.key,
    required this.builder,
  });
  
  final Widget Function(BuildContext context, ScreenSize screenSize) builder;
  
  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    return builder(context, Responsive.screenSize);
  }
}

/// Mixin do dodania responsywności do widgetów
mixin ResponsiveMixin {
  double r(double size) => Responsive.sp(size);
  double rw(double size) => Responsive.w(size);
  double rh(double size) => Responsive.h(size);
  double rf(double size) => Responsive.fontSize(size);
  double ri(double size) => Responsive.iconSize(size);
  double rp(double size) => Responsive.padding(size);
  double rr(double size) => Responsive.radius(size);
}

/// Rozszerzenie dla wygodniejszego użycia w widgetach
extension ResponsiveExtension on num {
  double get w => Responsive.w(toDouble());
  double get h => Responsive.h(toDouble());
  double get sp => Responsive.sp(toDouble());
  double get fontSize => Responsive.fontSize(toDouble());
  double get iconSize => Responsive.iconSize(toDouble());
  double get r => Responsive.padding(toDouble());
  double get radius => Responsive.radius(toDouble());
}
