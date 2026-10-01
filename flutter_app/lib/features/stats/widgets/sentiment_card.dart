import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:kryptox/core/theme/app_theme.dart';
import 'package:kryptox/core/utils/formatters.dart';
import 'package:kryptox/data/models/coin.dart';
import 'package:kryptox/features/stats/sentiment.dart';
import 'package:kryptox/shared/shared.dart';

/// Red → amber → green colour for a sentiment score (0-100).
Color _sentimentColor(double score) {
  final t = (score / 100).clamp(0.0, 1.0);
  return t < 0.5
      ? Color.lerp(KxColors.down, KxColors.warn, t * 2)!
      : Color.lerp(KxColors.warn, KxColors.up, (t - 0.5) * 2)!;
}

/// Estimated market sentiment: an animated semicircle gauge, the inputs
/// behind it as chips, and a note on how it is computed. See [Sentiment].
class SentimentCard extends StatelessWidget {
  const SentimentCard({super.key, required this.stats});

  final GlobalStats stats;

  static const _gaugeHeight = 150.0;

  @override
  Widget build(BuildContext context) {
    final sentiment = Sentiment.estimate(stats);
    final score = sentiment.score;
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: _gaugeHeight,
            child: score == null
                ? Center(
                    child: Text(
                      'Not enough market data to estimate sentiment right now.',
                      textAlign: TextAlign.center,
                      style: KxText.body(13, color: KxColors.textDim),
                    ),
                  )
                : _SentimentGauge(score: score),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _MetricChip(label: 'M.cap 24h', value: sentiment.marketCapChange),
              _MetricChip(label: 'Gainers avg', value: sentiment.gainersAvg),
              _MetricChip(label: 'Losers avg', value: sentiment.losersAvg),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            Sentiment.methodNote,
            textAlign: TextAlign.center,
            style: KxText.body(11, color: KxColors.textDim),
          ),
        ],
      ),
    );
  }
}

/// Compact "ESTIMATE ⓘ" tag for the sentiment section header; tap or hover
/// shows [Sentiment.methodNote].
class SentimentEstimateTag extends StatelessWidget {
  const SentimentEstimateTag({super.key});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: Sentiment.methodNote,
      triggerMode: TooltipTriggerMode.tap,
      showDuration: const Duration(seconds: 6),
      // Informational only (the full method note is also printed in the card),
      // kept compact so section headers stay aligned in the two-column layout.
      child: Semantics(
        label: 'In-app estimate',
        excludeSemantics: true,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: KxColors.borderStrong),
            color: KxColors.surface,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('ESTIMATE', style: KxText.label(9, color: KxColors.textDim)),
              const SizedBox(width: 4),
              const Icon(Icons.info_outline_rounded, size: 12, color: KxColors.textDim),
            ],
          ),
        ),
      ),
    );
  }
}

/// Gauge that sweeps up to [score] with the number and label underneath.
class _SentimentGauge extends StatelessWidget {
  const _SentimentGauge({required this.score});

  final double score;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          'Estimated sentiment ${score.round()} out of 100, ${Sentiment.labelFor(score)}. '
          'In-app estimate, not an official index.',
      excludeSemantics: true,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: score / 100),
        duration: const Duration(milliseconds: 1400),
        curve: Curves.easeOutCubic,
        builder: (context, t, _) {
          final current = t * 100;
          return Stack(
            children: [
              Positioned.fill(child: CustomPaint(painter: _GaugePainter(t))),
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  // Scale down rather than overflow the gauge at large text sizes.
                  child: SizedBox(
                    height: 72,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.bottomCenter,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${current.round()}', style: KxText.mono(34, weight: FontWeight.w700)),
                          Text(
                            Sentiment.labelFor(current),
                            style: KxText.display(14, weight: FontWeight.w600, color: _sentimentColor(current)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Small "label +1.23%" chip showing one input of the estimate.
class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final double? value;

  @override
  Widget build(BuildContext context) {
    final percent = formatPercent(value);
    return Semantics(
      label: '$label $percent',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: KxColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: KxText.body(11, color: KxColors.textDim),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              percent,
              style: KxText.mono(11, weight: FontWeight.w600, color: KxColors.change(value)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Semicircle gauge: red → amber → green track, glowing progress arc up to
/// [progress] (0-1), ticks at every quarter and a knob at the tip.
class _GaugePainter extends CustomPainter {
  const _GaugePainter(this.progress);

  final double progress;

  static const _stroke = 12.0;

  static SweepGradient _gradient(double alpha) => SweepGradient(
    startAngle: math.pi,
    endAngle: 2 * math.pi,
    colors: [
      KxColors.down.withValues(alpha: alpha),
      KxColors.warn.withValues(alpha: alpha),
      KxColors.up.withValues(alpha: alpha),
    ],
  );

  static Paint _arcPaint(Rect rect, {required double alpha, double width = _stroke}) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..shader = _gradient(alpha).createShader(rect);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height - 12);
    final radius = math.min(size.width / 2 - 14, size.height - 26);
    if (radius <= 0) return;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Track.
    canvas.drawArc(rect, math.pi, math.pi, false, _arcPaint(rect, alpha: 0.16));

    // Ticks at 0 / 25 / 50 / 75 / 100.
    final tick = Paint()
      ..color = KxColors.textMuted
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    for (var k = 0; k <= 4; k++) {
      final a = math.pi + math.pi * k / 4;
      final dir = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(center + dir * (radius - _stroke - 4), center + dir * (radius - _stroke - 10), tick);
    }

    if (progress <= 0.001) return;
    final sweep = math.pi * progress.clamp(0.0, 1.0);

    // Progress arc over a blurred glow.
    canvas.drawArc(
      rect,
      math.pi,
      sweep,
      false,
      _arcPaint(rect, alpha: 0.45, width: _stroke + 6)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawArc(rect, math.pi, sweep, false, _arcPaint(rect, alpha: 1));

    // Knob.
    final a = math.pi + sweep;
    final knob = center + Offset(math.cos(a), math.sin(a)) * radius;
    final color = _sentimentColor(progress * 100);
    canvas.drawCircle(
      knob,
      11,
      Paint()
        ..color = color.withValues(alpha: 0.6)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawCircle(knob, 9, Paint()..color = color);
    canvas.drawCircle(knob, 4, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_GaugePainter old) => old.progress != progress;
}
