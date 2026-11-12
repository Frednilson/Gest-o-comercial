import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// Tema Material 3 (claro e escuro).
class AppTheme {
  AppTheme._();

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;

    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: brightness,
    ).copyWith(
      primary: dark ? const Color(0xFF60A5FA) : AppColors.primary,
      onPrimary: dark ? AppColors.darkBackground : Colors.white,
      primaryContainer: dark ? const Color(0xFF1E3A8A) : AppColors.primaryLight,
      onPrimaryContainer: dark ? const Color(0xFFDBEAFE) : const Color(0xFF1D4ED8),
      secondaryContainer: dark ? const Color(0xFF1E3A8A) : AppColors.primaryLight,
      onSecondaryContainer: dark ? const Color(0xFFDBEAFE) : const Color(0xFF1D4ED8),
      surface: dark ? AppColors.darkSurface : AppColors.background,
      onSurface: dark ? const Color(0xFFF1F5F9) : AppColors.textPrimary,
      onSurfaceVariant: dark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
      outline: dark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
      outlineVariant: dark ? AppColors.darkBorder : AppColors.lightBorder,
      error: AppColors.error,
    );

    final scaffold = dark ? AppColors.darkBackground : AppColors.backgroundAlt;
    final radius = BorderRadius.circular(12);

    OutlineInputBorder border(Color color, [double width = 1]) => OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: color, width: width),
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffold,
      appBarTheme: AppBarTheme(
        backgroundColor: scaffold,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? AppColors.darkSurface : Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: border(scheme.outlineVariant),
        enabledBorder: border(scheme.outlineVariant),
        focusedBorder: border(scheme.primary, 1.6),
        errorBorder: border(AppColors.error),
        focusedErrorBorder: border(AppColors.error, 1.6),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 50),
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(64, 50),
          shape: RoundedRectangleBorder(borderRadius: radius),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 50),
          shape: RoundedRectangleBorder(borderRadius: radius),
          side: BorderSide(color: scheme.outline),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: radius),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primaryContainer,
        elevation: 0,
        height: 68,
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilderFallback(),
      }),
    );
  }
}

/// Transição suave e discreta entre ecrãs (compatível com todas as versões do Flutter).
class FadeForwardsPageTransitionsBuilderFallback extends PageTransitionsBuilder {
  const FadeForwardsPageTransitionsBuilderFallback();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0.04, 0), end: Offset.zero).animate(curved),
        child: child,
      ),
    );
  }
}
