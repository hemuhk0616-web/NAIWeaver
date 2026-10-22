import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'wildcard_service.dart';

/// Imports nested wildcard TXT files without overwriting existing files.
/// Archive limits mitigate decompression bombs and unexpectedly large imports.
class NaiaWildcardZipImporter {
  const NaiaWildcardZipImporter(this.service);

  final WildcardService service;
  static const int maxZipBytes = 32 * 1024 * 1024;
  static const int maxTotalUncompressedBytes = 64 * 1024 * 1024;
  static const int maxEntryBytes = 4 * 1024 * 1024;
  static const int maxFiles = 2000;

  Future<int> importFile(String zipPath) async {
    final source = File(zipPath);
    if (await source.length() > maxZipBytes) {
      throw const FormatException('ZIP 파일이 32MB 제한을 초과했습니다.');
    }
    final archive = ZipDecoder().decodeBytes(await source.readAsBytes());
    final root = p.normalize(p.absolute(service.wildcardDir));
    final planned = <String, ArchiveFile>{};
    var totalBytes = 0;
    for (final entry in archive) {
      if (!entry.isFile) continue;
      final name = entry.name.replaceAll('\\', '/');
      if (!name.toLowerCase().endsWith('.txt')) continue;
      if (name.startsWith('/') || name.split('/').contains('..')) continue;
      final destination = p.normalize(p.join(root, name));
      if (!p.isWithin(root, destination)) continue;
      if (entry.size > maxEntryBytes) {
        throw const FormatException('4MB를 초과하는 와일드카드 파일이 있습니다.');
      }
      totalBytes += entry.size;
      if (totalBytes > maxTotalUncompressedBytes ||
          planned.length >= maxFiles) {
        throw const FormatException('ZIP의 압축 해제 크기 또는 파일 수 제한을 초과했습니다.');
      }
      if (planned.containsKey(destination)) {
        throw const FormatException('ZIP 내부에 중복된 파일 경로가 있습니다.');
      }
      planned[destination] = entry;
    }

    // Never silently replace the user's existing wildcard edits.
    final conflicts = <String>[];
    for (final destination in planned.keys) {
      if (await File(destination).exists()) {
        conflicts.add(p.relative(destination, from: root));
      }
    }
    if (conflicts.isNotEmpty) {
      throw FormatException('이미 존재하는 와일드카드 파일: ${conflicts.take(3).join(', ')}');
    }

    final created = <String>[];
    try {
      for (final item in planned.entries) {
        final data = item.value.readBytes();
        if (data == null || data.length > maxEntryBytes) {
          throw const FormatException('ZIP 항목을 안전하게 읽지 못했습니다.');
        }
        await Directory(p.dirname(item.key)).create(recursive: true);
        await File(item.key).writeAsBytes(data, flush: true);
        created.add(item.key);
      }
      await service.refresh();
      return created.length;
    } catch (_) {
      for (final path in created.reversed) {
        try { await File(path).delete(); } catch (_) {}
      }
      rethrow;
    }
  }
}
