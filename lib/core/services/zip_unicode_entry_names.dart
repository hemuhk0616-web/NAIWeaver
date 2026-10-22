import 'dart:convert';
import 'dart:typed_data';

/// Reads Info-ZIP Unicode Path (0x7075) fields from ZIP central directory.
/// The archive decoder may expose legacy-encoded names as mojibake.
List<String?> zipUnicodeEntryNames(Uint8List bytes) {
  int u16(int i) => bytes[i] | (bytes[i + 1] << 8);
  int u32(int i) => u16(i) | (u16(i + 2) << 16);
  // EOCD may have up to 65535 bytes of comment.
  var end = -1;
  for (var i = bytes.length - 22; i >= 0 && i >= bytes.length - 65557; i--) {
    if (u32(i) == 0x06054b50 && i + 22 + u16(i + 20) == bytes.length) {
      end = i;
      break;
    }
  }
  if (end < 0) return [];
  final count = u16(end + 10);
  var pos = u32(end + 16);
  final names = <String?>[];
  if (pos > end || count > 10000) return [];
  for (var n = 0; n < count; n++) {
    if (pos + 46 > end || u32(pos) != 0x02014b50) return [];
    final nameLength = u16(pos + 28);
    final extraLength = u16(pos + 30);
    final commentLength = u16(pos + 32);
    final nameStart = pos + 46;
    final extraStart = nameStart + nameLength;
    final next = extraStart + extraLength + commentLength;
    if (next > end) return [];
    String? name;
    // Prefer standard UTF-8 names when ZIP's UTF-8 flag is set.
    if ((u16(pos + 8) & 0x0800) != 0) {
      try { name = utf8.decode(bytes.sublist(nameStart, extraStart)); } catch (_) {}
    }
    var extra = extraStart;
    while (name == null && extra + 4 <= extraStart + extraLength) {
      final type = u16(extra);
      final length = u16(extra + 2);
      final data = extra + 4;
      if (data + length > extraStart + extraLength) break;
      if (type == 0x7075 && length >= 5 && bytes[data] == 1) {
        final expectedCrc = u32(data + 1);
        if (_zipCrc32(bytes.sublist(nameStart, extraStart)) == expectedCrc) {
          try { name = utf8.decode(bytes.sublist(data + 5, data + length)); } catch (_) {}
        }
      }
      extra = data + length;
    }
    names.add(name);
    pos = next;
  }
  return names;
}

int _zipCrc32(List<int> data) {
  var crc = 0xffffffff;
  for (final byte in data) {
    crc ^= byte;
    for (var i = 0; i < 8; i++) {
      crc = (crc >>> 1) ^ ((crc & 1) != 0 ? 0xedb88320 : 0);
    }
  }
  return (crc ^ 0xffffffff) & 0xffffffff;
}
