import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'wildcard_service.dart';

/// Imports nested UTF-8/Korean wildcard TXT files from a ZIP archive.
class NaiaWildcardZipImporter {
  const NaiaWildcardZipImporter(this.service);

  final WildcardService service;

  Future<int> importFile(String zipPath) async {
    final bytes = await File(zipPath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final root = p.normalize(p.absolute(service.wildcardDir));
    var imported = 0;
    for (final entry in archive) {
      if (!entry.isFile) continue;
      final name = entry.name.replaceAll('\\', '/');
      if (!name.toLowerCase().endsWith('.txt')) continue;
      if (name.startsWith('/') || name.split('/').contains('..')) continue;
      final destination = p.normalize(p.join(root, name));
      if (!p.isWithin(root, destination)) continue;
      final data = entry.readBytes();
      if (data == null) continue;
      await Directory(p.dirname(destination)).create(recursive: true);
      await File(destination).writeAsBytes(data, flush: true);
      imported++;
    }
    await service.refresh();
    return imported;
  }
}
