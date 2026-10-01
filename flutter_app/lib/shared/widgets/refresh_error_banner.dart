import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:kryptox/core/theme/app_theme.dart';
import 'package:kryptox/shared/widgets/glass_card.dart';

/// Thin floating error strip shown when a refresh fails but old data is on screen.
class RefreshErrorBanner extends StatelessWidget {
  const RefreshErrorBanner({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      blur: true,
      radius: 14,
      padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
      gradient: LinearGradient(colors: [KxColors.down.withValues(alpha: 0.22), KxColors.down.withValues(alpha: 0.1)]),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: KxColors.down, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Refresh failed: $message',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: KxText.body(12),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.5, curve: Curves.easeOutBack);
  }
}
