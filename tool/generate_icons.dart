// Regenerates the PNG icons from the procedural AppIcon.
//
// Usage: dart run tool/generate_icons.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:meu_trello_local/src/desktop/tray/app_icon.dart';

const appId = 'io.github.professorbossini.meu_trello_local';

void main() {
  _write('assets/icon/app_icon.png', 256);
  for (final size in [48, 64, 128, 256]) {
    _write('linux/packaging/icons/hicolor/${size}x$size/apps/$appId.png', size);
  }
}

void _write(String path, int size) {
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(encodePng(AppIcon.rgba(size), size, size));
  stdout.writeln('wrote $path');
}

/// Minimal PNG encoder for 8-bit RGBA images.
Uint8List encodePng(Uint8List rgba, int width, int height) {
  final raw = BytesBuilder();
  for (var y = 0; y < height; y++) {
    raw.addByte(0); // No filter.
    raw.add(Uint8List.sublistView(rgba, y * width * 4, (y + 1) * width * 4));
  }

  final header = ByteData(13)
    ..setUint32(0, width)
    ..setUint32(4, height)
    ..setUint8(8, 8) // Bit depth.
    ..setUint8(9, 6); // Color type: RGBA.

  return (BytesBuilder()
        ..add(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        ..add(_chunk('IHDR', header.buffer.asUint8List()))
        ..add(_chunk('IDAT', ZLibCodec(level: 9).encode(raw.takeBytes())))
        ..add(_chunk('IEND', const [])))
      .takeBytes();
}

Uint8List _chunk(String type, List<int> data) {
  final typeBytes = type.codeUnits;
  final length = ByteData(4)..setUint32(0, data.length);
  final crc = ByteData(4)..setUint32(0, _crc32([...typeBytes, ...data]));
  return (BytesBuilder()
        ..add(length.buffer.asUint8List())
        ..add(typeBytes)
        ..add(data)
        ..add(crc.buffer.asUint8List()))
      .takeBytes();
}

final _crcTable = List<int>.generate(256, (n) {
  var c = n;
  for (var k = 0; k < 8; k++) {
    c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
  }
  return c;
});

int _crc32(List<int> bytes) {
  var crc = 0xFFFFFFFF;
  for (final byte in bytes) {
    crc = _crcTable[(crc ^ byte) & 0xFF] ^ (crc >> 8);
  }
  return crc ^ 0xFFFFFFFF;
}
