import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Reactive controller for switching between modern Light and Dark themes.
/// Defaults to Light theme.
class AppThemeController extends ValueNotifier<ThemeMode> {
  AppThemeController._() : super(ThemeMode.light);

  static final AppThemeController instance = AppThemeController._();

  bool get isDark => value == ThemeMode.dark;

  void toggleTheme() {
    setThemeMode(isDark ? ThemeMode.light : ThemeMode.dark);
  }

  void setThemeMode(ThemeMode mode) {
    if (value == mode) return;
    value = mode;
    applySystemUiOverlay();
  }

  void applySystemUiOverlay() {
    final dark = isDark;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: AppColors.background,
        systemNavigationBarIconBrightness:
            dark ? Brightness.light : Brightness.dark,
      ),
    );
  }
}

/// Shared adaptive design tokens for Pusaka Seni Scoring IPSI.
/// Automatically adapts between soft modern Light theme and refined Dark theme.
class AppColors {
  AppColors._();

  static bool get _isDark => AppThemeController.instance.isDark;

  // Canvas & Surfaces
  static Color get background =>
      _isDark ? const Color(0xFF0F172A) : const Color(0xFFF4F7FB);
  static Color get backgroundTop =>
      _isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
  static Color get backgroundBottom =>
      _isDark ? const Color(0xFF162033) : const Color(0xFFEEF3FA);
  static Color get surface =>
      _isDark ? const Color(0xFF1E293B) : const Color(0xFFFFFFFF);
  static Color get surfaceMuted =>
      _isDark ? const Color(0xFF283548) : const Color(0xFFF1F5F9);
  static Color get surfaceSoft =>
      _isDark ? const Color(0xFF162135) : const Color(0xFFF8FAFC);
  static Color get border =>
      _isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
  static Color get borderStrong =>
      _isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1);

  // Typography Ink
  static Color get textPrimary =>
      _isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
  static Color get textSecondary =>
      _isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569);
  static Color get textMuted =>
      _isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

  // Brand & Semantic Accents
  static const Color primary = Color(0xFFDC2626);
  static const Color primaryDark = Color(0xFFB91C1C);
  static Color get primarySoft =>
      _isDark ? const Color(0xFF45161B) : const Color(0xFFFEF2F2);
  static Color get primaryBorder =>
      _isDark ? const Color(0xFF991B1B) : const Color(0xFFFECACA);
  static Color get primaryText =>
      _isDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B);

  static const Color emerald = Color(0xFF059669);
  static Color get emeraldSoft =>
      _isDark ? const Color(0xFF0D332B) : const Color(0xFFECFDF5);
  static Color get emeraldBorder =>
      _isDark ? const Color(0xFF047857) : const Color(0xFFA7F3D0);
  static Color get emeraldText =>
      _isDark ? const Color(0xFF6EE7B7) : const Color(0xFF065F46);

  static const Color amber = Color(0xFFD97706);
  static Color get amberSoft =>
      _isDark ? const Color(0xFF3A2811) : const Color(0xFFFFFBEB);
  static Color get amberBorder =>
      _isDark ? const Color(0xFFB45309) : const Color(0xFFFDE68A);
  static Color get amberText =>
      _isDark ? const Color(0xFFFCD34D) : const Color(0xFF92400E);

  static const Color sky = Color(0xFF0284C7);
  static Color get skySoft =>
      _isDark ? const Color(0xFF102C42) : const Color(0xFFF0F9FF);
  static Color get skyBorder =>
      _isDark ? const Color(0xFF0369A1) : const Color(0xFFBAE6FD);
  static Color get skyText =>
      _isDark ? const Color(0xFF7DD3FC) : const Color(0xFF075985);

  static const Color blue = Color(0xFF2563EB);
  static Color get blueSoft =>
      _isDark ? const Color(0xFF17284B) : const Color(0xFFEFF6FF);
  static Color get blueBorder =>
      _isDark ? const Color(0xFF1D4ED8) : const Color(0xFFBFDBFE);
  static Color get blueText =>
      _isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E40AF);

  static const Color teal = Color(0xFF0D9488);
  static Color get tealSoft =>
      _isDark ? const Color(0xFF103437) : const Color(0xFFF0FDFA);
  static Color get tealBorder =>
      _isDark ? const Color(0xFF0F766E) : const Color(0xFF99F6E4);
  static Color get tealText =>
      _isDark ? const Color(0xFF5EEAD4) : const Color(0xFF115E59);

  static const Color purple = Color(0xFF7C3AED);
  static Color get purpleSoft =>
      _isDark ? const Color(0xFF2B1C4B) : const Color(0xFFF5F3FF);
  static Color get purpleBorder =>
      _isDark ? const Color(0xFF6D28D9) : const Color(0xFFDDD6FE);
}

class AppDecorations {
  AppDecorations._();

  static BoxDecoration get pageBackground => BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.backgroundTop, AppColors.backgroundBottom],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      );

  static BoxDecoration card({
    double radius = 20,
    Color? color,
    Color? borderColor,
    double borderWidth = 1.0,
    bool elevated = true,
  }) {
    final isDark = AppThemeController.instance.isDark;
    return BoxDecoration(
      color: color ?? AppColors.surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: borderColor ?? AppColors.border,
        width: borderWidth,
      ),
      boxShadow: elevated
          ? (isDark
              ? const [
                  BoxShadow(
                    color: Color(0x40000000),
                    blurRadius: 16,
                    offset: Offset(0, 6),
                  ),
                ]
              : const [
                  BoxShadow(
                    color: Color(0x0F0F172A),
                    blurRadius: 16,
                    offset: Offset(0, 6),
                  ),
                  BoxShadow(
                    color: Color(0x060F172A),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ])
          : null,
    );
  }

  static BoxDecoration softTile({
    double radius = 14,
    Color? color,
    Color? borderColor,
    double borderWidth = 1.0,
  }) {
    return BoxDecoration(
      color: color ?? AppColors.surfaceSoft,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: borderColor ?? AppColors.border,
        width: borderWidth,
      ),
    );
  }
}

class AppTheme {
  AppTheme._();

  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF4F7FB),
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
        surface: const Color(0xFFFFFFFF),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFFFFFFFF),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFFFFFFFF),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE2E8F0),
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0F172A),
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.dark,
        surface: const Color(0xFF1E293B),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1E293B),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF334155)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF1E293B),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF334155),
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

/// Compact icon button to toggle between Light and Dark theme from any screen.
class ThemeToggleButton extends StatelessWidget {
  final double iconSize;
  final double buttonSize;
  final double borderRadius;

  const ThemeToggleButton({
    super.key,
    this.iconSize = 16,
    this.buttonSize = 30,
    this.borderRadius = 9,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppThemeController.instance,
      builder: (context, mode, _) {
        final isDark = mode == ThemeMode.dark;
        return IconButton(
          onPressed: AppThemeController.instance.toggleTheme,
          tooltip: isDark ? 'Ubah ke Tema Terang' : 'Ubah ke Tema Gelap',
          icon: Icon(
            isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            size: iconSize,
            color: isDark ? const Color(0xFFFBBF24) : AppColors.textSecondary,
          ),
          constraints: BoxConstraints(
            minWidth: buttonSize,
            minHeight: buttonSize,
          ),
          padding: EdgeInsets.zero,
          style: IconButton.styleFrom(
            backgroundColor: AppColors.surfaceMuted,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
            side: BorderSide(color: AppColors.border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(borderRadius),
            ),
          ),
        );
      },
    );
  }
}
