import 'package:flutter/material.dart';

class TossColors {
  const TossColors._();

  static const blue = Color(0xFF3182F6);
  static const blue50 = Color(0xFFEAF3FF);
  static const blue100 = Color(0xFFD9EAFE);
  static const gray50 = Color(0xFFF2F4F6);
  static const gray100 = Color(0xFFE5E8EB);
  static const gray200 = Color(0xFFD1D6DB);
  static const gray500 = Color(0xFF8B95A1);
  static const gray700 = Color(0xFF4E5968);
  static const gray900 = Color(0xFF191F28);
  static const green = Color(0xFF00A86B);
  static const green50 = Color(0xFFE8F8F0);
  static const orange = Color(0xFFFF8A00);
  static const orange50 = Color(0xFFFFF3E0);
  static const red = Color(0xFFF04452);
  static const red50 = Color(0xFFFFECEF);
  static const white = Color(0xFFFFFFFF);
}

class TossTheme {
  const TossTheme._();

  static ThemeData light() {
    const colorScheme = ColorScheme.light(
      primary: TossColors.blue,
      onPrimary: TossColors.white,
      secondary: TossColors.green,
      error: TossColors.red,
      surface: TossColors.white,
      onSurface: TossColors.gray900,
    );

    final base = ThemeData(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: TossColors.gray50,
      useMaterial3: true,
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: TossColors.white,
        foregroundColor: TossColors.gray900,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: TossColors.gray900,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      textTheme: base.textTheme.copyWith(
        displaySmall: const TextStyle(
          color: TossColors.gray900,
          fontSize: 32,
          fontWeight: FontWeight.w800,
          height: 1.2,
          letterSpacing: 0,
        ),
        headlineMedium: const TextStyle(
          color: TossColors.gray900,
          fontSize: 28,
          fontWeight: FontWeight.w800,
          height: 1.2,
          letterSpacing: 0,
        ),
        titleLarge: const TextStyle(
          color: TossColors.gray900,
          fontSize: 22,
          fontWeight: FontWeight.w800,
          height: 1.25,
          letterSpacing: 0,
        ),
        titleMedium: const TextStyle(
          color: TossColors.gray900,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          height: 1.35,
          letterSpacing: 0,
        ),
        bodyLarge: const TextStyle(
          color: TossColors.gray700,
          fontSize: 16,
          fontWeight: FontWeight.w500,
          height: 1.45,
          letterSpacing: 0,
        ),
        bodyMedium: const TextStyle(
          color: TossColors.gray700,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          height: 1.45,
          letterSpacing: 0,
        ),
        labelLarge: const TextStyle(
          color: TossColors.gray700,
          fontSize: 14,
          fontWeight: FontWeight.w700,
          height: 1.2,
          letterSpacing: 0,
        ),
      ),
      iconTheme: const IconThemeData(color: TossColors.gray700),
      dividerTheme: const DividerThemeData(
        color: TossColors.gray100,
        thickness: 1,
        space: 1,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: TossColors.blue,
          foregroundColor: TossColors.white,
          disabledBackgroundColor: TossColors.gray100,
          disabledForegroundColor: TossColors.gray500,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: TossColors.gray900,
          minimumSize: const Size.fromHeight(48),
          side: const BorderSide(color: TossColors.gray100),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: TossColors.blue,
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: TossColors.gray50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: TossColors.blue, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: TossColors.red, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        labelStyle: const TextStyle(
          color: TossColors.gray500,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
        prefixIconColor: TossColors.gray500,
      ),
    );
  }
}
