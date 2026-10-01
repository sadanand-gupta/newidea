import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:kryptox/app.dart';
import 'package:kryptox/core/theme/app_theme.dart';
import 'package:kryptox/shared/shared.dart';

/// Branded ~1.8s intro: a hexagon mark with a sweeping neon ring and a
/// self-drawing "X", a letter-by-letter wordmark and a progress line.
/// Tapping anywhere skips it; with "reduce motion" on it is much shorter.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 1800);
  static const _reducedDuration = Duration(milliseconds: 500);

  late final AnimationController _intro = AnimationController(vsync: this, duration: _duration);
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  bool _started = false;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _intro.addStatusListener((status) {
      if (status == AnimationStatus.completed) _goHome();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // MediaQuery isn't readable in initState; start the intro on first build.
    if (_started) return;
    _started = true;
    if (MediaQuery.of(context).disableAnimations) {
      _intro.duration = _reducedDuration;
    } else {
      _pulse.repeat(reverse: true);
    }
    _intro.forward();
  }

  @override
  void dispose() {
    _intro.dispose();
    _pulse.dispose();
    super.dispose();
  }

  void _goHome() {
    if (_navigated || !mounted) return;
    _navigated = true;
    Navigator.of(context).pushReplacementNamed(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.viewPaddingOf(context).bottom;
    return KxBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Semantics(
          label: 'KryptoX is loading. Double tap to skip.',
          button: true,
          onTap: _goHome,
          excludeSemantics: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _goHome,
            child: Stack(
              children: [
                Positioned.fill(
                  child: SafeArea(
                    // Leave room for the progress line so the two never overlap.
                    minimum: const EdgeInsets.fromLTRB(24, 24, 24, 110),
                    child: Center(
                      // Scales the whole lockup down on short (landscape) or
                      // narrow screens and at large text sizes instead of overflowing.
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            RepaintBoundary(
                              child: AnimatedBuilder(
                                animation: Listenable.merge([_intro, _pulse]),
                                builder: (context, _) => CustomPaint(
                                  size: const Size.square(148),
                                  painter: _LogoPainter(t: _intro.value, pulse: _pulse.value),
                                ),
                              ),
                            ),
                            const SizedBox(height: 28),
                            const _Wordmark(),
                            const SizedBox(height: 12),
                            Text(
                                  'CRYPTO MARKET INTELLIGENCE',
                                  textAlign: TextAlign.center,
                                  style: KxText.label(11, color: KxColors.textDim).copyWith(letterSpacing: 3.2),
                                )
                                .animate(delay: 1050.ms)
                                .fadeIn(duration: 500.ms)
                                .slideY(begin: 0.4, end: 0, duration: 500.ms, curve: Curves.easeOutCubic),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 56 + bottomPad,
                  child: AnimatedBuilder(
                    animation: _intro,
                    builder: (context, _) => _SyncProgress(value: Curves.easeInOutCubic.transform(_intro.value)),
                  ).animate().fadeIn(delay: 250.ms, duration: 400.ms),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Krypto" letters rise in one by one, then the gradient "X" pops.
class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    const word = 'Krypto';
    final style = KxText.display(42, weight: FontWeight.w700).copyWith(letterSpacing: -1);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (var i = 0; i < word.length; i++)
          Text(word[i], style: style)
              .animate(delay: (620 + i * 50).ms)
              .fadeIn(duration: 380.ms)
              .slideY(begin: 0.55, end: 0, duration: 420.ms, curve: Curves.easeOutCubic)
              .blurXY(begin: 6, end: 0, duration: 380.ms),
        GradientText('X', style: style)
            .animate(delay: 960.ms)
            .fadeIn(duration: 300.ms)
            .scaleXY(begin: 1.8, end: 1, duration: 520.ms, curve: Curves.easeOutBack),
      ],
    ).animate(delay: 1350.ms).shimmer(duration: 900.ms, color: KxColors.cyan.withValues(alpha: 0.55));
  }
}

class _SyncProgress extends StatelessWidget {
  const _SyncProgress({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 168,
          height: 2,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(2),
          ),
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: value.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                gradient: KxColors.brandGradient,
                borderRadius: BorderRadius.circular(2),
                boxShadow: [BoxShadow(color: KxColors.cyan.withValues(alpha: 0.6), blurRadius: 8)],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('LOADING MARKETS', style: KxText.label(10, color: KxColors.textMuted)),
            const SizedBox(width: 10),
            SizedBox(
              width: 36,
              child: Text(
                '${(value * 100).round()}%',
                textAlign: TextAlign.right,
                style: KxText.mono(10, color: KxColors.cyan),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Logo mark: faint track ring, gradient sweep with a glowing head, a rounded
/// hexagon that scales/rotates in, and an "X" that draws itself.
class _LogoPainter extends CustomPainter {
  _LogoPainter({required this.t, required this.pulse});

  /// Intro progress 0..1.
  final double t;

  /// Breathing glow 0..1 (repeats).
  final double pulse;

  static double _interval(double t, double begin, double end, [Curve curve = Curves.linear]) {
    final v = ((t - begin) / (end - begin)).clamp(0.0, 1.0);
    return curve.transform(v);
  }

  Path _roundedHexagon(Offset c, double radius, double rotation, double cornerRadius) {
    final vertices = [
      for (var i = 0; i < 6; i++) c + Offset.fromDirection(-math.pi / 2 + i * math.pi / 3 + rotation, radius),
    ];
    Offset toward(Offset from, Offset to) {
      final d = to - from;
      return from + d / d.distance * cornerRadius;
    }

    final path = Path();
    for (var i = 0; i <= 6; i++) {
      final v = vertices[i % 6];
      final prev = vertices[(i + 5) % 6];
      final next = vertices[(i + 1) % 6];
      final pIn = toward(v, prev);
      final pOut = toward(v, next);
      if (i == 0) {
        path.moveTo(pOut.dx, pOut.dy);
      } else {
        path.lineTo(pIn.dx, pIn.dy);
        path.quadraticBezierTo(v.dx, v.dy, pOut.dx, pOut.dy);
      }
    }
    return path..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;

    // --- Ring -----------------------------------------------------------
    final ringRect = Rect.fromCircle(center: c, radius: r - 4);
    final ringIn = _interval(t, 0, 0.12);
    canvas.drawCircle(
      c,
      r - 4,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: 0.08 * ringIn),
    );

    final sweep = 2 * math.pi * _interval(t, 0.02, 0.72, Curves.easeInOutCubic);
    final start = -math.pi / 2 + t * math.pi * 0.9;
    if (sweep > 0.001) {
      final ringPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          colors: const [KxColors.cyan, KxColors.violet, KxColors.magenta, KxColors.cyan],
          transform: GradientRotation(start),
        ).createShader(ringRect);
      canvas.drawArc(ringRect, start, sweep, false, ringPaint);

      // Glowing head of the sweep.
      final head = c + Offset.fromDirection(start + sweep, r - 4);
      canvas.drawCircle(
        head,
        6,
        Paint()
          ..color = KxColors.cyan.withValues(alpha: 0.7)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      canvas.drawCircle(head, 2.2, Paint()..color = Colors.white);
    }

    // --- Hexagon ----------------------------------------------------------
    final hexT = _interval(t, 0.08, 0.5);
    if (hexT <= 0) return;
    final hexScale = Curves.easeOutBack.transform(hexT);
    final hexOpacity = _interval(t, 0.08, 0.28);
    final hexR = r * 0.6 * hexScale;
    final rotation = (1 - Curves.easeOutCubic.transform(hexT)) * (-math.pi / 3);
    final hex = _roundedHexagon(c, hexR, rotation, hexR * 0.18);
    final hexBounds = Rect.fromCircle(center: c, radius: hexR);

    // Breathing outer glow (stronger once the intro has settled).
    final glowStrength = (0.25 + 0.25 * pulse) * hexOpacity;
    canvas.drawPath(
      hex,
      Paint()
        ..color = KxColors.cyan.withValues(alpha: glowStrength)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22),
    );

    // Dark glass fill with a soft brand tint.
    canvas.drawPath(
      hex,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(KxColors.bgElevated, KxColors.cyan, 0.16)!.withValues(alpha: hexOpacity),
            Color.lerp(KxColors.bgElevated, KxColors.violet, 0.22)!.withValues(alpha: hexOpacity),
          ],
        ).createShader(hexBounds),
    );

    // Gradient outline.
    canvas.drawPath(
      hex,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeJoin = StrokeJoin.round
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            KxColors.cyan.withValues(alpha: hexOpacity),
            KxColors.violet.withValues(alpha: hexOpacity),
          ],
        ).createShader(hexBounds),
    );

    // --- "X" --------------------------------------------------------------
    final a = hexR * 0.36;
    final strokes = [
      (c + Offset(-a, -a), c + Offset(a, a), _interval(t, 0.34, 0.6, Curves.easeOutCubic)),
      (c + Offset(a, -a), c + Offset(-a, a), _interval(t, 0.44, 0.7, Curves.easeOutCubic)),
    ];
    final xShader = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [KxColors.cyan, Colors.white, KxColors.violet],
    ).createShader(hexBounds);
    final width = hexR * 0.17;
    for (final (from, to, progress) in strokes) {
      if (progress <= 0) continue;
      final end = Offset.lerp(from, to, progress)!;
      canvas.drawLine(
        from,
        end,
        Paint()
          ..strokeWidth = width * 1.6
          ..strokeCap = StrokeCap.round
          ..color = KxColors.cyan.withValues(alpha: 0.35 + 0.15 * pulse)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      canvas.drawLine(
        from,
        end,
        Paint()
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round
          ..shader = xShader,
      );
    }
  }

  @override
  bool shouldRepaint(_LogoPainter old) => old.t != t || old.pulse != pulse;
}
