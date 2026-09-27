import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/splash_screen.dart';
import 'services/api_service.dart';
import 'state/auth_provider.dart';
import 'state/watchlist_provider.dart';
import 'theme/app_theme.dart';

/// Light status/navigation bar icons over our dark, edge-to-edge canvas.
const kxOverlayStyle = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.light,
  statusBarBrightness: Brightness.dark, // iOS: dark background -> light content
  systemNavigationBarColor: Colors.transparent,
  systemNavigationBarDividerColor: Colors.transparent,
  systemNavigationBarIconBrightness: Brightness.light,
  systemNavigationBarContrastEnforced: false,
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(kxOverlayStyle);

  final api = ApiService();
  final auth = AuthProvider(api);
  await auth.initialize();

  runApp(
    MultiProvider(
      providers: [
        Provider<ApiService>.value(value: api),
        ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ChangeNotifierProvider(create: (_) => WatchlistProvider(api)..load()),
      ],
      child: const KryptoXApp(),
    ),
  );
}

class KryptoXApp extends StatelessWidget {
  const KryptoXApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KryptoX',
      theme: buildKxTheme(),
      debugShowCheckedModeBanner: false,
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: kxOverlayStyle,
        child: child ?? const SizedBox.shrink(),
      ),
      routes: {
        '/login': (_) => const LoginScreen(),
        '/home': (_) => const HomeShell(),
        '/profile': (_) => const ProfileScreen(),
        '/': (_) => const SplashScreen(),
      },
      initialRoute: '/',
    );
  }
}
