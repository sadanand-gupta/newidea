import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Polls a screen's data every [pollInterval], but only while the screen is
/// actually on screen, and catches up as soon as it comes back.
///
/// "Visible" means the widget's TickerMode is enabled (false for hidden
/// IndexedStack tabs, which the shell mutes, and for pages covered by a pushed
/// route) and the app is in the foreground. While the app is paused / hidden
/// the timer is stopped entirely; `inactive` (a system dialog, a desktop
/// window losing focus) keeps polling.
///
/// When the screen becomes visible again (tab shown, route popped, app
/// resumed) [onVisible] runs, which by default calls [onPoll] if [isStale].
/// It runs after the current frame, because TickerMode flips during build.
///
/// Ticks are skipped while the previous [onPoll] future is still pending.
/// The mixin does not perform the initial load: call it from `initState`.
///
/// ```dart
/// class _MyState extends State<My> with VisiblePolling<My> {
///   @override
///   Duration get pollInterval => const Duration(seconds: 30);
///   @override
///   bool get isStale => isOlderThanPollInterval(_data.updatedAt);
///   @override
///   Future<void> onPoll() => _reload();
/// }
/// ```
mixin VisiblePolling<T extends StatefulWidget> on State<T> {
  Timer? _pollTimer;
  AppLifecycleListener? _lifecycle;
  ValueListenable<TickerModeData>? _tickerMode;
  bool _polling = false;

  /// Time between polls while visible.
  Duration get pollInterval;

  /// Refreshes the data. Called on every tick while visible, and by the
  /// default [onVisible] when the data went stale while hidden.
  Future<void> onPoll();

  /// Whether the data is old enough to refresh the moment the screen
  /// becomes visible again. See [isOlderThanPollInterval].
  bool get isStale;

  /// Called (after the frame) when the screen becomes visible: its tab is
  /// shown, a covering route is popped, or the app is resumed. Override for
  /// per-resource logic; the default refreshes when [isStale].
  void onVisible() {
    if (isStale) _runPoll();
  }

  /// True while on screen and the app is not paused / hidden.
  bool get isVisible {
    if (!mounted) return false;
    final tickerEnabled = _tickerMode?.value.enabled ?? TickerMode.getValuesNotifier(context).value.enabled;
    return tickerEnabled && _isForeground(WidgetsBinding.instance.lifecycleState);
  }

  /// True when [lastUpdate] is null or at least [pollInterval] ago.
  bool isOlderThanPollInterval(DateTime? lastUpdate) =>
      lastUpdate == null || DateTime.now().difference(lastUpdate) >= pollInterval;

  static bool _isForeground(AppLifecycleState? state) =>
      state == null || state == AppLifecycleState.resumed || state == AppLifecycleState.inactive;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onStateChange: _onLifecycleChanged);
    _startPolling();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final notifier = TickerMode.getValuesNotifier(context);
    if (!identical(notifier, _tickerMode)) {
      _tickerMode?.removeListener(_onTickerModeChanged);
      _tickerMode = notifier..addListener(_onTickerModeChanged);
    }
  }

  @override
  void dispose() {
    _stopPolling();
    _lifecycle?.dispose();
    _tickerMode?.removeListener(_onTickerModeChanged);
    super.dispose();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(pollInterval, (_) {
      if (isVisible) _runPoll();
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _runPoll() async {
    if (_polling || !mounted) return;
    _polling = true;
    try {
      await onPoll();
    } finally {
      _polling = false;
    }
  }

  void _onLifecycleChanged(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_pollTimer == null) {
        _startPolling();
        _scheduleOnVisible();
      }
    } else if (!_isForeground(state)) {
      // paused / hidden / detached: no point polling in the background.
      _stopPolling();
    }
  }

  void _onTickerModeChanged() {
    if (_tickerMode?.value.enabled ?? false) _scheduleOnVisible();
  }

  void _scheduleOnVisible() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (isVisible) onVisible();
    });
    // Make sure a frame is coming (e.g. right after an app resume).
    WidgetsBinding.instance.ensureVisualUpdate();
  }
}
