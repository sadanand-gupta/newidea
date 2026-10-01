import 'package:flutter/foundation.dart';

import 'package:kryptox/data/api_service.dart';
import 'package:kryptox/data/models/coin.dart';
import 'package:kryptox/state/loadable.dart';

/// Time windows the detail chart can show.
enum ChartRange {
  day(1, '24H', 'Past 24 hours'),
  week(7, '7D', 'Past 7 days'),
  month(30, '30D', 'Past 30 days'),
  quarter(90, '90D', 'Past 90 days'),
  year(365, '1Y', 'Past year');

  const ChartRange(this.days, this.label, this.longLabel);

  /// Value of the API's `days` parameter.
  final int days;

  /// Compact label for the range selector ("7D").
  final String label;

  /// Caption under the price ("Past 7 days").
  final String longLabel;
}

/// Chart points tagged with the range they were fetched for, so the header
/// never mixes a stale range's change with the newly selected range label.
class ChartSeries {
  const ChartSeries(this.range, this.points);

  final ChartRange range;
  final List<PricePoint> points;

  /// Percent change from the first to the last point, if computable.
  double? get change => points.length < 2 ? null : changeTo(points.last);

  /// Percent change from the first point to [point] (e.g. a scrubbed one).
  double? changeTo(PricePoint point) {
    if (points.isEmpty || points.first.price == 0) return null;
    return (point.price / points.first.price - 1) * 100;
  }
}

/// Price-history state of the detail page: the selected [range], its loading
/// state, a per-range cache and the point under the finger while scrubbing.
///
/// Notifies when the range changes or the chart request progresses. Scrubbing
/// is published separately on [scrub] so it doesn't rebuild the chart itself.
class ChartRangeController extends ChangeNotifier {
  ChartRangeController({required this.fetch, ChartRange initialRange = ChartRange.week}) : _range = initialRange {
    _chart.addListener(notifyListeners);
  }

  /// Loads the series for a number of days.
  final Future<ApiResult<List<PricePoint>>> Function(int days) fetch;

  final _chart = Loadable<ChartSeries>();

  /// Last good series per range, so flipping back to a range is instant and
  /// a failed refresh never blanks a chart the user already saw.
  final _cache = <ChartRange, ChartSeries>{};

  /// Point under the finger while the chart is being scrubbed.
  final scrub = ValueNotifier<PricePoint?>(null);

  ChartRange _range;
  bool _disposed = false;

  ChartRange get range => _range;
  bool get loading => _chart.loading;
  Object? get error => _chart.error;

  /// Series to draw for the selected range: fresh data, else the cached copy
  /// for this range, else (while loading) the previous range's series.
  ChartSeries? get visible {
    final live = _chart.data;
    if (live != null && live.range == _range) return live;
    return _cache[_range] ?? live;
  }

  /// [visible] only if it belongs to the selected range.
  ChartSeries? get current {
    final series = visible;
    return series?.range == _range ? series : null;
  }

  /// Fetches the selected range (again).
  Future<void> load() {
    final range = _range;
    return _chart.load(() async {
      final result = await fetch(range.days);
      final series = ChartSeries(range, result.data);
      _cache[range] = series;
      return ApiResult(series, result.source, result.updatedAt);
    });
  }

  void select(ChartRange range) {
    if (_disposed || range == _range) return;
    _range = range;
    notifyListeners();
    scrub.value = null;
    load();
  }

  void onScrub(PricePoint? point) {
    if (_disposed) return;
    if (scrub.value != point) scrub.value = point;
  }

  @override
  void dispose() {
    _disposed = true;
    _chart.dispose();
    scrub.dispose();
    super.dispose();
  }
}
