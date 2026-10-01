import 'dart:math' as math;

import 'package:flutter/material.dart';

/// One-shot entrance animation: fade in while rising (or sliding) into place,
/// staggered by [index].
///
/// * Plays once, when the State is created. Rebuilds (data refreshes) never
///   replay or cut it short, and toggling [play] later has no effect.
/// * The widget tree is identical whether or not it plays, so the child's
///   state (e.g. an `AnimatedPrice` mid-flash) is never torn down.
/// * Skipped entirely when the OS asks to reduce motion.
///
/// To animate list rows only the first time an id is seen (not when they are
/// scrolled back into view), key the Entrance by id and pass
/// `play: seenIds.add(id)`.
class Entrance extends StatefulWidget {
  const Entrance({
    super.key,
    required this.child,
    this.index = 0,
    this.play = true,
    this.delay = Duration.zero,
    this.stagger = const Duration(milliseconds: 60),
    this.maxStaggered = 10,
    this.duration = const Duration(milliseconds: 420),
    this.offset = const Offset(0, 0.06),
  });

  final Widget child;

  /// Position among siblings; delays the start by `index * stagger`.
  final int index;

  /// False shows the child in place immediately. Read once, at creation.
  final bool play;

  /// Extra delay before the staggered start.
  final Duration delay;
  final Duration stagger;

  /// Indices beyond this share the last slot, so long lists don't make
  /// far-down rows wait seconds to appear.
  final int maxStaggered;
  final Duration duration;

  /// Starting offset as a fraction of the child's size (default: a slight
  /// rise from 6% below). Use e.g. `Offset(0.08, 0)` to slide in from the right.
  final Offset offset;

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    final lead = widget.delay + widget.stagger * math.min(widget.index, widget.maxStaggered);
    final total = lead + widget.duration;
    _controller = AnimationController(vsync: this, duration: total);
    final start = total == Duration.zero ? 0.0 : lead.inMicroseconds / total.inMicroseconds;
    _fade = CurvedAnimation(
      parent: _controller,
      curve: Interval(start, 1, curve: Curves.easeOutCubic),
    );
    _slide = Tween<Offset>(begin: widget.offset, end: Offset.zero).animate(_fade);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (widget.play && !MediaQuery.disableAnimationsOf(context)) {
      _controller.forward();
    } else {
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}
