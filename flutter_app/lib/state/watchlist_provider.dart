import 'package:flutter/foundation.dart';

import '../services/api_service.dart';

/// Watchlist ids, persisted on the backend. Toggles are optimistic and
/// rolled back if the server call fails.
class WatchlistProvider extends ChangeNotifier {
  WatchlistProvider(this._api);

  final ApiService _api;
  Set<String> _ids = {};
  String? error;

  Set<String> get ids => Set.unmodifiable(_ids);

  bool contains(String id) => _ids.contains(id);

  Future<void> load() async {
    try {
      _ids = (await _api.getWatchlistIds()).toSet();
      error = null;
    } catch (e) {
      error = e.toString();
    }
    notifyListeners();
  }

  /// Returns an error message on failure, or null on success.
  Future<String?> toggle(String id) async {
    final adding = !_ids.contains(id);
    adding ? _ids.add(id) : _ids.remove(id);
    notifyListeners();
    try {
      final ids = adding ? await _api.addToWatchlist(id) : await _api.removeFromWatchlist(id);
      _ids = ids.toSet();
      notifyListeners();
      return null;
    } catch (e) {
      adding ? _ids.remove(id) : _ids.add(id);
      notifyListeners();
      return 'Could not update watchlist: $e';
    }
  }
}
