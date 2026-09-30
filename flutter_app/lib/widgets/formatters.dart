import 'dart:math' as math;

String _groupThousands(String s) {
  final negative = s.startsWith('-');
  if (negative) s = s.substring(1);
  final parts = s.split('.');
  final whole = parts[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  return '${negative ? '-' : ''}$whole${parts.length > 1 ? '.${parts[1]}' : ''}';
}

int priceDecimals(double v) {
  final abs = v.abs();
  if (abs == 0 || !abs.isFinite || abs >= 1) return 2;
  if (abs >= 0.01) return 4;
  if (abs >= 0.0001) return 6;
  // Micro-cap prices: keep 4 significant digits instead of rounding to $0.00000000.
  return math.min(-(math.log(abs) / math.ln10).floor() + 3, 14);
}

/// $64,250.12 · $0.5850 · $0.00001780 — more decimals for smaller prices.
String formatPrice(num? value, {int? decimals}) {
  if (value == null) return '—';
  final v = value.toDouble();
  return '\$${_groupThousands(v.toStringAsFixed(decimals ?? priceDecimals(v)))}';
}

/// $1.27T · $845.20M · 19.74M (without currency).
String formatCompact(num? value, {bool currency = true}) {
  if (value == null) return '—';
  final v = value.toDouble();
  final abs = v.abs();
  final (divisor, suffix) = abs >= 1e12
      ? (1e12, 'T')
      : abs >= 1e9
          ? (1e9, 'B')
          : abs >= 1e6
              ? (1e6, 'M')
              : abs >= 1e3
                  ? (1e3, 'K')
                  : (1.0, '');
  return '${currency ? '\$' : ''}${(v / divisor).toStringAsFixed(2)}$suffix';
}

/// Whole number with thousands separators: 19,740,000.
String formatNumber(num? value) =>
    value == null ? '—' : _groupThousands(value.toDouble().toStringAsFixed(0));

String formatPercent(num? value) {
  if (value == null) return '—';
  return '${value >= 0 ? '+' : ''}${value.toStringAsFixed(2)}%';
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String _two(int n) => n.toString().padLeft(2, '0');

String formatTime(DateTime t) => '${_two(t.hour)}:${_two(t.minute)}';

String formatDate(DateTime? t) => t == null ? '—' : '${t.day} ${_months[t.month - 1]} ${t.year}';

String formatDateShort(DateTime t) => '${t.day} ${_months[t.month - 1]}';

String formatMonthYear(DateTime t) => "${_months[t.month - 1]} '${_two(t.year % 100)}";

String formatDateTime(DateTime t) => '${formatDateShort(t)} ${t.year}, ${formatTime(t)}';

String timeAgo(DateTime t) {
  final s = DateTime.now().difference(t).inSeconds;
  if (s < 10) return 'just now';
  if (s < 60) return '${s}s ago';
  if (s < 3600) return '${s ~/ 60}m ago';
  return formatTime(t);
}
