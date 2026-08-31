import 'package:flutter/material.dart';

/// Uygulama paleti. [bind] ile aktif tema parlaklığına bağlanır;
/// böylece mevcut `AppColors.ink` çağrıları koyu/açık moda uyum sağlar.
abstract final class AppColors {
  static Brightness _brightness = Brightness.light;

  static void bind(Brightness brightness) {
    _brightness = brightness;
  }

  static bool get _dark => _brightness == Brightness.dark;

  static Color get ink =>
      _dark ? const Color(0xFFE8EEE9) : const Color(0xFF17221B);
  static Color get mutedInk =>
      _dark ? const Color(0xFF9AA89E) : const Color(0xFF6E7B72);
  static Color get canvas =>
      _dark ? const Color(0xFF0F1311) : const Color(0xFFF7F9F6);
  static Color get card =>
      _dark ? const Color(0xFF1E2621) : Colors.white;
  static Color get primary => const Color(0xFF49B86A);
  static Color get primaryDark =>
      _dark ? const Color(0xFF6BE08A) : const Color(0xFF247A40);
  static Color get softGreen =>
      _dark ? const Color(0xFF2A4634) : const Color(0xFFE5F5E8);
  static Color get orange => const Color(0xFFFFA14A);
  static Color get lavender =>
      _dark ? const Color(0xFF2A2840) : const Color(0xFFECEBFF);
  static Color get line =>
      _dark ? const Color(0xFF334038) : const Color(0xFFE7ECE8);

  /// Rota önizleme / harita kartı zemini
  static Color get mapCanvas =>
      _dark ? const Color(0xFF171E1A) : const Color(0xFFE8F0E6);
  static Color get mapPark =>
      _dark ? const Color(0xFF1F2C24) : const Color(0xFFD4E8D0);
  static Color get mapGrid =>
      _dark ? const Color(0xFF2A3530) : Colors.white;

  static bool get isDark => _dark;
}

abstract final class AppTheme {
  static ThemeData light() {
    const ink = Color(0xFF17221B);
    const muted = Color(0xFF6E7B72);
    const canvas = Color(0xFFF7F9F6);
    const card = Colors.white;
    const primary = Color(0xFF49B86A);
    const primaryDark = Color(0xFF247A40);
    const softGreen = Color(0xFFE5F5E8);
    const line = Color(0xFFE7ECE8);

    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: primaryDark,
      onPrimary: Colors.white,
      surface: canvas,
      onSurface: ink,
      onSurfaceVariant: muted,
      outline: line,
      surfaceContainerHighest: card,
      primaryContainer: softGreen,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: canvas,
      fontFamily: 'Arial',
      appBarTheme: const AppBarTheme(
        backgroundColor: canvas,
        foregroundColor: ink,
        elevation: 0,
        centerTitle: false,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: card,
        indicatorColor: softGreen,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected) ? primaryDark : muted,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: line),
        ),
      ),
      dividerColor: line,
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }

  static ThemeData dark() {
    const ink = Color(0xFFE8EEE9);
    const muted = Color(0xFF9AA89E);
    const canvas = Color(0xFF0F1311);
    const card = Color(0xFF1E2621);
    const primary = Color(0xFF49B86A);
    const primaryBright = Color(0xFF6BE08A);
    const softGreen = Color(0xFF2A4634);
    const line = Color(0xFF334038);

    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.dark,
    ).copyWith(
      primary: primaryBright,
      onPrimary: const Color(0xFF0C140F),
      surface: canvas,
      onSurface: ink,
      onSurfaceVariant: muted,
      outline: line,
      surfaceContainerHighest: card,
      primaryContainer: softGreen,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: canvas,
      fontFamily: 'Arial',
      appBarTheme: const AppBarTheme(
        backgroundColor: canvas,
        foregroundColor: ink,
        elevation: 0,
        centerTitle: false,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: card,
        indicatorColor: softGreen,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected) ? primaryBright : muted,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: line),
        ),
      ),
      dividerColor: line,
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }
}
