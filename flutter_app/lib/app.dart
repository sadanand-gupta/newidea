import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:kryptox/core/theme/app_theme.dart';
import 'package:kryptox/features/shell/home_shell.dart';
import 'package:kryptox/features/splash/splash_screen.dart';

/// Light status/navigation bar icons over the dark, edge-to-edge canvas.
const kxOverlayStyle = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.light,
  statusBarBrightness: Brightness.dark, // iOS: dark background -> light content
  systemNavigationBarColor: Colors.transparent,
  systemNavigationBarDividerColor: Colors.transparent,
  systemNavigationBarIconBrightness: Brightness.light,
  systemNavigationBarContrastEnforced: false,
);

/// Named routes of the app.
abstract final class AppRoutes {
  static const splash = '/';
  static const home = '/home';
}

class KryptoXApp extends StatelessWidget {
  const KryptoXApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KryptoX',
      theme: buildKxTheme(),
      debugShowCheckedModeBanner: false,
      builder: (context, child) =>
          AnnotatedRegion<SystemUiOverlayStyle>(value: kxOverlayStyle, child: child ?? const SizedBox.shrink()),
      initialRoute: AppRoutes.splash,
      routes: {AppRoutes.splash: (_) => const SplashScreen(), AppRoutes.home: (_) => const HomeShell()},
    );
  }
}
