import 'dart:math' as math;

import 'package:animations/animations.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// KryptoX design tokens. The brand is dark-only: deep space background,
/// cyan → violet neon accents, frosted glass surfaces.
abstract final class KxColors {
  static const bg = Color(0xFF05060B);
  static const bgElevated = Color(0xFF0C0F18);
  static const surface = Color(0x14FFFFFF); // 8% white glass
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
  static const textMuted = Color(0xFF7C8599); // >= 4.5:1 on bg for small text

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

  /// Widely tracked cyan kicker above page titles ("MARKETS", "OVERVIEW").
  static TextStyle eyebrow({double size = 11, Color color = KxColors.cyan}) =>
      label(size, color: color).copyWith(letterSpacing: 2.4);
}

/// Spacing, sizing and radius tokens shared by every screen.
abstract final class KxLayout {
  /// Widest a page's content column gets on tablets, desktop and web.
  /// Phones always use the full width.
  static const double maxContentWidth = 840;

  /// Horizontal page gutter.
  static const double gutter = 16;
  static const EdgeInsets pagePadding = EdgeInsets.symmetric(horizontal: gutter);

  /// Vertical gap between the sections of a page.
  static const double sectionGap = 18;

  /// Padding of a tab's page header (menu · title · actions).
  static const EdgeInsets headerPadding = EdgeInsets.fromLTRB(16, 14, 16, 10);

  /// Bottom space a tab keeps free so content clears the floating nav bar.
  static const double navBarClearance = 110;

  /// Bottom offset of a floating banner (e.g. "refresh failed") so it sits
  /// just above the nav bar, including a tall system gesture area.
  static double floatingBannerBottom(BuildContext context) => math.max(104, MediaQuery.paddingOf(context).bottom + 10);

  /// Bottom inset that optically centres full-page loading / error / empty
  /// states in the area above the nav bar.
  static const double stateViewBottomInset = 90;

  /// [navBarClearance], or more when the system gesture area is taller.
  static double bottomClearance(BuildContext context) =>
      math.max(navBarClearance, MediaQuery.paddingOf(context).bottom + 20);

  /// Minimum interactive size (Material / WCAG touch-target guidance).
  static const double minTapTarget = 44;

  /// Width above which pointer-friendly affordances (e.g. refresh buttons,
  /// since mice can't pull-to-refresh) are shown.
  static const double wideBreakpoint = 600;

  // Corner radii, from small controls up to hero cards.
  static const double radiusControl = 12; // chips, segmented controls
  static const double radiusButton = 14; // icon buttons, banners
  static const double radiusTile = 16; // stat tiles
  static const double radiusRow = 18; // list rows, compact cards
  static const double radiusCard = 20; // default glass card
  static const double radiusHero = 22; // dashboard hero cards
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
    textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(bodyColor: KxColors.text, displayColor: KxColors.text),
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
