import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:naiweaver/core/services/zip_unicode_entry_names.dart';

void main() {
  test('restores Korean path from verified Info-ZIP Unicode Path field', () {
    final legacyName = latin1.encode('legacy.txt');
    final unicodeName = utf8.encode('의상/의상.txt');
    final extra = <int>[
      0x75, 0x70, 5 + unicodeName.length, 0,
      1, 0xf5, 0x2b, 0x99, 0x0c, ...unicodeName,
    ];
    // CRC for legacyName is written below.
    var crc = 0xffffffff;
    for (final b in legacyName) {
      crc ^= b;
      for (var i = 0; i < 8; i++) {
        crc = (crc >>> 1) ^ ((crc & 1) != 0 ? 0xedb88320 : 0);
      }
    }
    crc = (crc ^ 0xffffffff) & 0xffffffff;
    for (var i = 0; i < 4; i++) { extra[5 + i] = (crc >>> (8 * i)) & 255; }

    final central = Uint8List(46 + legacyName.length + extra.length);
    final view = ByteData.sublistView(central);
    view.setUint32(0, 0x02014b50, Endian.little);
    view.setUint16(28, legacyName.length, Endian.little);
    view.setUint16(30, extra.length, Endian.little);
    central.setRange(46, 46 + legacyName.length, legacyName);
    central.setRange(46 + legacyName.length, central.length, extra);
    final eocd = Uint8List(22);
    final endView = ByteData.sublistView(eocd);
    endView.setUint32(0, 0x06054b50, Endian.little);
    endView.setUint16(10, 1, Endian.little);
    final bytes = Uint8List.fromList([...central, ...eocd]);
    expect(zipUnicodeEntryNames(bytes), ['의상/의상.txt']);

    bytes[46] ^= 1; // Corrupt the legacy name; CRC must reject Unicode override.
    expect(zipUnicodeEntryNames(bytes), [null]);
  });
}
