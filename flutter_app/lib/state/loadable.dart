import 'package:flutter/foundation.dart';

import 'package:kryptox/data/api_service.dart';

/// Holds the loading / error / data state of one API call.
///
/// Previous data is kept while reloading, so lists don't flash back to a
/// spinner on every search keystroke or pull-to-refresh.
class Loadable<T> extends ChangeNotifier {
  T? data;
  String? source;
  DateTime? updatedAt;
  Object? error;
  bool loading = false;

  int _requestId = 0;
  bool _disposed = false;

  bool get hasData => data != null;

  Future<void> load(Future<ApiResult<T>> Function() request) async {
    final id = ++_requestId;
    loading = true;
    error = null;
    _notify();
    try {
      final result = await request();
      if (id != _requestId) return; // a newer request superseded this one
      data = result.data;
      source = result.source;
      updatedAt = result.updatedAt;
    } catch (e) {
      if (id != _requestId) return;
      error = e;
    }
    loading = false;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
