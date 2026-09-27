import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class SkeletonLoader extends StatefulWidget {
  const SkeletonLoader({super.key});

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
      itemCount: 10,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) => _SkeletonTile(animation: _controller),
    );
  }
}

class _SkeletonTile extends StatelessWidget {
  const _SkeletonTile({required this.animation});

  final AnimationController animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final shimmerValue = animation.value;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: KxColors.surface,
          ),
          child: Row(
            children: [
              // Rank
              _ShimmerBox(
                width: 22,
                height: 16,
                shimmerValue: shimmerValue,
              ),
              const SizedBox(width: 8),
              // Avatar
              _ShimmerBox(
                width: 32,
                height: 32,
                borderRadius: 8,
                shimmerValue: shimmerValue,
              ),
              const SizedBox(width: 12),
              // Name and symbol
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ShimmerBox(
                      width: double.infinity,
                      height: 14,
                      shimmerValue: shimmerValue,
                    ),
                    const SizedBox(height: 6),
                    _ShimmerBox(
                      width: 80,
                      height: 12,
                      shimmerValue: shimmerValue,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Change 7d
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _ShimmerBox(
                      width: 50,
                      height: 12,
                      shimmerValue: shimmerValue,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Price and 24h change
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _ShimmerBox(
                      width: 70,
                      height: 14,
                      shimmerValue: shimmerValue,
                    ),
                    const SizedBox(height: 6),
                    _ShimmerBox(
                      width: 50,
                      height: 12,
                      shimmerValue: shimmerValue,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 40),
            ],
          ),
        );
      },
    );
  }
}

class _ShimmerBox extends StatelessWidget {
  const _ShimmerBox({
    required this.width,
    required this.height,
    required this.shimmerValue,
    this.borderRadius = 4,
  });

  final double width;
  final double height;
  final double shimmerValue;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    // Shimmer effect: moves from left to right
    final shimmerPosition = (shimmerValue * 2) - 1; // -1 to 1

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: LinearGradient(
          begin: Alignment(-1 - shimmerPosition, 0),
          end: Alignment(1 - shimmerPosition, 0),
          colors: [
            KxColors.surface,
            KxColors.bgElevated.withValues(alpha: 0.8),
            KxColors.surface,
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
    );
  }
}
