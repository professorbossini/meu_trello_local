import 'dart:math' as math;
import 'dart:typed_data';

/// Procedurally rendered application icon: a tile in the app's
/// blue-violet-rose accent gradient holding a short checklist, two tasks
/// ticked off and one still open.
///
/// Drawing it in code keeps a single source of truth for every size the
/// tray and the desktop entry need, with no binary assets to keep in sync.
/// This file is pure Dart on purpose so `tool/generate_icons.dart` can reuse
/// it outside Flutter.
abstract final class AppIcon {
  /// Diagonal gradient stops, matching `AppTheme.gradientColors`.
  static const _gradientStops = [
    (0x42, 0x85, 0xF4),
    (0x9B, 0x72, 0xCB),
    (0xD9, 0x65, 0x70),
  ];
  static const _white = (0xFF, 0xFF, 0xFF);

  /// Vertical centers of the checklist rows, in unit coordinates.
  static const _rows = [0.30, 0.50, 0.70];
  static const _checkboxX = 0.30;
  static const _checkboxRadius = 0.085;

  /// Samples per axis used for anti-aliasing.
  static const _supersampling = 4;

  /// Renders the icon as non-premultiplied RGBA, row by row.
  static Uint8List rgba(int size) {
    final pixels = Uint8List(size * size * 4);
    const n = _supersampling;
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        // Premultiplied accumulators.
        var r = 0.0, g = 0.0, b = 0.0, a = 0.0;
        for (var sy = 0; sy < n; sy++) {
          for (var sx = 0; sx < n; sx++) {
            final u = (x + (sx + 0.5) / n) / size;
            final v = (y + (sy + 0.5) / n) / size;
            final (sr, sg, sb, sa) = _sample(u, v);
            r += sr * sa;
            g += sg * sa;
            b += sb * sa;
            a += sa;
          }
        }
        if (a == 0) continue;
        final offset = (y * size + x) * 4;
        pixels[offset] = (r / a).round();
        pixels[offset + 1] = (g / a).round();
        pixels[offset + 2] = (b / a).round();
        pixels[offset + 3] = (255 * a / (n * n)).round();
      }
    }
    return pixels;
  }

  /// Renders the icon as ARGB32 in network byte order, the pixmap format of
  /// the StatusNotifierItem specification.
  static Uint8List argb(int size) {
    final rgba = AppIcon.rgba(size);
    final argb = Uint8List(rgba.length);
    for (var i = 0; i < rgba.length; i += 4) {
      argb[i] = rgba[i + 3];
      argb[i + 1] = rgba[i];
      argb[i + 2] = rgba[i + 1];
      argb[i + 3] = rgba[i + 2];
    }
    return argb;
  }

  /// Color of the point (u, v), painting the layers back to front.
  static (double, double, double, double) _sample(double u, double v) {
    if (!_inRoundedRect(u, v, 0, 0, 1, 1, 0.22)) return (0, 0, 0, 0);

    final tile = _gradient((u + v) / 2);
    var color = tile;
    void paint((int, int, int) paint, [double opacity = 1]) {
      color = (
        _mix(color.$1, paint.$1, opacity),
        _mix(color.$2, paint.$2, opacity),
        _mix(color.$3, paint.$3, opacity),
      );
    }

    for (final (index, cy) in _rows.indexed) {
      final done = index < _rows.length - 1;

      // Task line, dimmed while the task is still open.
      if (_inRoundedRect(u, v, 0.44, cy - 0.042, 0.78, cy + 0.042, 0.042)) {
        paint(_white, done ? 1 : 0.6);
      }

      final distance = _distance(u, v, _checkboxX, cy);
      if (done) {
        // Filled checkbox with the tile color showing through as a tick.
        if (distance <= _checkboxRadius) {
          paint(_white);
          final onTick =
              _nearSegment(u, v, 0.255, cy + 0.002, 0.288, cy + 0.035, 0.018) ||
              _nearSegment(u, v, 0.288, cy + 0.035, 0.345, cy - 0.030, 0.018);
          if (onTick) paint(tile);
        }
      } else if (distance <= _checkboxRadius && distance >= 0.058) {
        paint(_white, 0.85);
      }
    }

    return (color.$1.toDouble(), color.$2.toDouble(), color.$3.toDouble(), 1);
  }

  static (int, int, int) _gradient(double t) {
    final segments = _gradientStops.length - 1;
    final position = t.clamp(0.0, 1.0) * segments;
    final index = position.floor().clamp(0, segments - 1);
    final from = _gradientStops[index];
    final to = _gradientStops[index + 1];
    final local = position - index;
    return (
      _mix(from.$1, to.$1, local),
      _mix(from.$2, to.$2, local),
      _mix(from.$3, to.$3, local),
    );
  }

  static int _mix(int from, int to, double t) =>
      (from + (to - from) * t).round();

  static double _distance(double x0, double y0, double x1, double y1) =>
      math.sqrt((x0 - x1) * (x0 - x1) + (y0 - y1) * (y0 - y1));

  static bool _inRoundedRect(
    double x,
    double y,
    double left,
    double top,
    double right,
    double bottom,
    double radius,
  ) {
    if (x < left || x > right || y < top || y > bottom) return false;
    final cx = x.clamp(left + radius, right - radius);
    final cy = y.clamp(top + radius, bottom - radius);
    return _distance(x, y, cx, cy) <= radius;
  }

  /// Whether (x, y) lies within [halfWidth] of the segment (x0, y0)-(x1, y1).
  static bool _nearSegment(
    double x,
    double y,
    double x0,
    double y0,
    double x1,
    double y1,
    double halfWidth,
  ) {
    final dx = x1 - x0;
    final dy = y1 - y0;
    final t = (((x - x0) * dx + (y - y0) * dy) / (dx * dx + dy * dy)).clamp(
      0.0,
      1.0,
    );
    return _distance(x, y, x0 + t * dx, y0 + t * dy) <= halfWidth;
  }
}
