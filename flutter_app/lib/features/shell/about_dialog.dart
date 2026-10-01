import 'package:flutter/material.dart';

import 'package:kryptox/core/config.dart';
import 'package:kryptox/core/theme/app_theme.dart';
import 'package:kryptox/shared/shared.dart';

/// Branded About dialog: app name, version, data attribution and licenses.
Future<void> showKxAboutDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    builder: (context) => const _AboutDialog(),
  );
}

class _AboutDialog extends StatelessWidget {
  const _AboutDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: DecoratedBox(
          decoration: BoxDecoration(color: KxColors.bgElevated, borderRadius: BorderRadius.circular(24)),
          child: GlassCard(
            radius: 24,
            glow: KxColors.cyan,
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 14),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const KxLogoMark(size: 48),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Semantics(
                              header: true,
                              child: GradientText('KryptoX', style: KxText.display(24, weight: FontWeight.w700)),
                            ),
                            Text('Version ${AppConfig.version}', style: KxText.mono(12, color: KxColors.textDim)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Crypto market research: live prices, market-wide statistics, '
                    'interactive charts and a personal watchlist.',
                    style: KxText.body(14, color: KxColors.textDim).copyWith(height: 1.45),
                  ),
                  const SizedBox(height: 16),
                  const _AboutRow(icon: Icons.cloud_outlined, title: 'Market data', value: 'Provided by CoinGecko'),
                  const SizedBox(height: 10),
                  const _AboutRow(
                    icon: Icons.schedule_rounded,
                    title: 'Refresh',
                    value: 'Prices update automatically while you browse',
                  ),
                  const SizedBox(height: 10),
                  const _AboutRow(
                    icon: Icons.shield_outlined,
                    title: 'Disclaimer',
                    value: 'For information only. Not financial advice.',
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 4,
                    children: [
                      TextButton(
                        style: TextButton.styleFrom(minimumSize: const Size(64, 44)),
                        onPressed: () => showLicensePage(
                          context: context,
                          applicationName: 'KryptoX',
                          applicationVersion: AppConfig.version,
                        ),
                        child: Text(
                          'Licenses',
                          style: KxText.body(14, weight: FontWeight.w600, color: KxColors.textDim),
                        ),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(minimumSize: const Size(64, 44)),
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          'Close',
                          style: KxText.body(14, weight: FontWeight.w700, color: KxColors.cyan),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AboutRow extends StatelessWidget {
  const _AboutRow({required this.icon, required this.title, required this.value});

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: KxColors.cyan.withValues(alpha: 0.1),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 16, color: KxColors.cyan),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title.toUpperCase(), style: KxText.label(10, color: KxColors.textMuted)),
                const SizedBox(height: 2),
                Text(value, style: KxText.body(13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
