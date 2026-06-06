import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const Color kBackgroundColor = Color(0xFFFFFFFF);
const Color kSurfaceColor = Color(0xFFF5F7FA);
const Color kBorderColor = Color(0xFFE0E0E0);
const Color kPrimaryColor = Color(0xFF1565C0);
const Color kPrimaryLightColor = Color(0xFFE8F0FE);
const Color kOnPrimaryColor = Color(0xFFFFFFFF);
const Color kTextPrimaryColor = Color(0xFF0D0D0D);
const Color kTextSecondaryColor = Color(0xFF616161);
const Color kTextDisabledColor = Color(0xFFBDBDBD);
const Color kErrorColor = Color(0xFFD32F2F);
const Color kSuccessColor = Color(0xFF2E7D32);
const Color kDividerColor = Color(0xFFEEEEEE);

ThemeData _baseTheme() {
  const colorScheme = ColorScheme.light(
    primary: kPrimaryColor,
    onPrimary: kOnPrimaryColor,
    surface: kBackgroundColor,
    onSurface: kTextPrimaryColor,
    background: kBackgroundColor,
    error: kErrorColor,
    onError: kOnPrimaryColor,
    secondary: kPrimaryColor,
    onSecondary: kOnPrimaryColor,
  );

  final textTheme = GoogleFonts.interTextTheme();

  return ThemeData(
    colorScheme: colorScheme,
    brightness: Brightness.light,
    useMaterial3: true,
    textTheme: textTheme,
    scaffoldBackgroundColor: kBackgroundColor,
    appBarTheme: AppBarTheme(
      backgroundColor: kBackgroundColor,
      foregroundColor: kTextPrimaryColor,
      elevation: 0,
      centerTitle: false,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
        fontSize: 22,
        color: kTextPrimaryColor,
      ),
      iconTheme: const IconThemeData(color: kPrimaryColor),
      actionsIconTheme: const IconThemeData(color: kPrimaryColor),
      shape: const Border(
        bottom: BorderSide(color: kDividerColor, width: 1),
      ),
    ),
    cardTheme: CardThemeData(
      color: kBackgroundColor,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: kBorderColor, width: 1),
      ),
      shadowColor: Colors.black.withValues(alpha: 0.06),
      margin: const EdgeInsets.all(8),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: kPrimaryColor,
        foregroundColor: kOnPrimaryColor,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 0,
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: kTextSecondaryColor,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: const BorderSide(color: kBorderColor),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: kTextSecondaryColor,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kSurfaceColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: kBorderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: kPrimaryColor, width: 1.5),
      ),
      enabledBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
        borderSide: BorderSide(color: kBorderColor),
      ),
      labelStyle: const TextStyle(color: kTextSecondaryColor),
      hintStyle: const TextStyle(color: kTextDisabledColor),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: kBackgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titleTextStyle: const TextStyle(
        color: kTextPrimaryColor,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
      contentTextStyle: const TextStyle(
        color: kTextSecondaryColor,
        fontSize: 14,
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: kBorderColor,
      thickness: 1,
      space: 1,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return kPrimaryColor;
        return kTextDisabledColor;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return kPrimaryLightColor;
        return kBorderColor;
      }),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: kPrimaryColor,
      foregroundColor: kOnPrimaryColor,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: kPrimaryColor,
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: kPrimaryColor,
      textColor: kTextPrimaryColor,
    ),
  );
}

ThemeData buildLightTheme() => _baseTheme();

ThemeData buildDarkTheme() => _baseTheme();
