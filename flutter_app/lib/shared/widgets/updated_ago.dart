import 'dart:async';

import 'package:flutter/material.dart';

import 'package:kryptox/core/theme/app_theme.dart';
import 'package:kryptox/core/utils/formatters.dart';

/// "Updated 12s ago" that keeps itself current.
///
/// Re-renders every second while the age is shown in seconds and every 15s
/// after that (the text then only changes per minute). Pauses while its
/// route/tab is hidden (TickerMode off). Shows [placeholder] while [time] is
/// null.
class UpdatedAgo extends StatefulWidget {
  const UpdatedAgo({super.key, required this.time, this.style, this.placeholder = 'Syncing…'});

  final DateTime? time;

  /// Defaults to 11px mono in [KxColors.textMuted].
  final TextStyle? style;
  final String placeholder;

  @override
  State<UpdatedAgo> createState() => _UpdatedAgoState();
}

class _UpdatedAgoState extends State<UpdatedAgo> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void didUpdateWidget(UpdatedAgo old) {
    super.didUpdateWidget(old);
    if (old.time != widget.time) _schedule();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _schedule() {
    _timer?.cancel();
    final t = widget.time;
    if (t == null) return;
    final fresh = DateTime.now().difference(t).inSeconds < 60;
    _timer = Timer(Duration(seconds: fresh ? 1 : 15), _tick);
  }

  void _tick() {
    if (!mounted) return;
    if (TickerMode.of(context)) setState(() {});
    _schedule();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.time;
    return Text(
      t == null ? widget.placeholder : 'Updated ${timeAgo(t)}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: widget.style ?? KxText.mono(11, color: KxColors.textMuted),
    );
  }
}
