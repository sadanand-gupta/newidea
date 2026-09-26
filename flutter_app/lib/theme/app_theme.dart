import 'dart:ui' show FontFeature;

import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// KryptoX design tokens. The brand is dark-only: deep space background,
/// cyan → violet neon accents, frosted glass surfaces.
abstract final class KxColors {
  static const bg = Color(0xFF05060B);
  static const bgElevated = Color(0xFF0C0F18);
  static const surface = Color(0x14FFFFFF); // 8% white glass
  static const surfaceStrong = Color(0x1FFFFFFF);
  static const border = Color(0x1AFFFFFF);
  static const borderStrong = Color(0x33FFFFFF);

  static const cyan = Color(0xFF00E5FF);
  static const violet = Color(0xFF8B5CF6);
  static const magenta = Color(0xFFE040FB);

  static const up = Color(0xFF00F5A0);
  static const down = Color(0xFFFF4D6D);
  static const warn = Color(0xFFFFB547);

  static const text = Color(0xFFEAF0FF);
  static const textDim = Color(0xFF9AA3B8);
  static const textMuted = Color(0xFF5F6780);

  static const brandGradient = LinearGradient(
    colors: [cyan, violet],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static Color change(num? v) => v == null ? textMuted : (v >= 0 ? up : down);
}

abstract final class KxText {
  static TextStyle display(double size, {FontWeight weight = FontWeight.w700, Color color = KxColors.text}) =>
      GoogleFonts.spaceGrotesk(fontSize: size, fontWeight: weight, color: color, letterSpacing: -0.5);

  static TextStyle body(double size, {FontWeight weight = FontWeight.w400, Color color = KxColors.text}) =>
      GoogleFonts.inter(fontSize: size, fontWeight: weight, color: color);

  /// Tabular monospace for every number so digits don't jitter as they tick.
  static TextStyle mono(double size, {FontWeight weight = FontWeight.w500, Color color = KxColors.text}) =>
      GoogleFonts.jetBrainsMono(
        fontSize: size,
        fontWeight: weight,
        color: color,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static TextStyle label(double size, {Color color = KxColors.textDim}) =>
      GoogleFonts.inter(fontSize: size, fontWeight: FontWeight.w600, color: color, letterSpacing: 0.8);
}

ThemeData buildKxTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: KxColors.cyan,
      brightness: Brightness.dark,
      primary: KxColors.cyan,
      secondary: KxColors.violet,
      surface: KxColors.bgElevated,
      error: KxColors.down,
    ),
  );
  return base.copyWith(
    scaffoldBackgroundColor: KxColors.bg,
    textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor: KxColors.text,
      displayColor: KxColors.text,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      titleTextStyle: KxText.display(20),
      iconTheme: const IconThemeData(color: KxColors.text),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: KxColors.bgElevated,
      contentTextStyle: KxText.body(14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: KxColors.borderStrong),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: KxColors.bgElevated,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: KxColors.borderStrong,
    ),
    dividerTheme: const DividerThemeData(color: KxColors.border, thickness: 1, space: 1),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: KxColors.cyan),
    splashFactory: InkSparkle.splashFactory,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: SharedAxisPageTransitionsBuilder(
          transitionType: SharedAxisTransitionType.horizontal,
          fillColor: KxColors.bg,
        ),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: SharedAxisPageTransitionsBuilder(
          transitionType: SharedAxisTransitionType.horizontal,
          fillColor: KxColors.bg,
        ),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: SharedAxisPageTransitionsBuilder(
          transitionType: SharedAxisTransitionType.horizontal,
          fillColor: KxColors.bg,
        ),
      },
    ),
  );
}
