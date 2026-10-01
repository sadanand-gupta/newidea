import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:kryptox/app.dart';
import 'package:kryptox/data/api_service.dart';
import 'package:kryptox/state/watchlist_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(kxOverlayStyle);

  final api = ApiService();

  runApp(
    MultiProvider(
      providers: [
        Provider<ApiService>.value(value: api),
        ChangeNotifierProvider(create: (_) => WatchlistProvider(api)..load()),
      ],
      child: const KryptoXApp(),
    ),
  );
}
