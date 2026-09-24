import 'dart:math' as math;
import 'dart:typed_data';

/// Procedurally rendered application icon: a rounded blue tile holding three
/// white kanban columns of different heights.
///
/// Drawing it in code keeps a single source of truth for every size the
/// tray and the desktop entry need, with no binary assets to keep in sync.
/// This file is pure Dart on purpose so `tool/generate_icons.dart` can reuse
/// it outside Flutter.
abstract final class AppIcon {
  static const _topColor = (0x1E, 0x90, 0xE0);
  static const _bottomColor = (0x00, 0x5F, 0xA3);

  /// Columns as (left, top, right, bottom) in unit coordinates.
  static const _columns = [
    (0.20, 0.22, 0.38, 0.78),
    (0.41, 0.22, 0.59, 0.56),
    (0.62, 0.22, 0.80, 0.68),
  ];

  /// Samples per axis used for anti-aliasing.
  static const _supersampling = 4;

  /// Renders the icon as non-premultiplied RGBA, row by row.
  static Uint8List rgba(int size) {
    final pixels = Uint8List(size * size * 4);
    const n = _supersampling;
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        var tile = 0;
        var column = 0;
        for (var sy = 0; sy < n; sy++) {
          for (var sx = 0; sx < n; sx++) {
            final u = (x + (sx + 0.5) / n) / size;
            final v = (y + (sy + 0.5) / n) / size;
            if (_insideRoundedRect(u, v, (0, 0, 1, 1), 0.22)) {
              tile++;
              if (_columns.any((c) => _insideRoundedRect(u, v, c, 0.045))) {
                column++;
              }
            }
          }
        }
        if (tile == 0) continue;

        // Vertical gradient on the tile, blended towards white by how much
        // of the pixel the columns cover.
        final t = y / math.max(1, size - 1);
        final white = column / tile;
        int channel(int top, int bottom) {
          final base = top + (bottom - top) * t;
          return (base + (255 - base) * white).round();
        }

        final offset = (y * size + x) * 4;
        pixels[offset] = channel(_topColor.$1, _bottomColor.$1);
        pixels[offset + 1] = channel(_topColor.$2, _bottomColor.$2);
        pixels[offset + 2] = channel(_topColor.$3, _bottomColor.$3);
        pixels[offset + 3] = (255 * tile / (n * n)).round();
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

  static bool _insideRoundedRect(
    double x,
    double y,
    (double, double, double, double) rect,
    double radius,
  ) {
    final (left, top, right, bottom) = rect;
    if (x < left || x > right || y < top || y > bottom) return false;
    final cx = x.clamp(left + radius, right - radius);
    final cy = y.clamp(top + radius, bottom - radius);
    final dx = x - cx;
    final dy = y - cy;
    return dx * dx + dy * dy <= radius * radius;
  }
}
