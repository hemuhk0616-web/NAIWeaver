import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naiweaver/core/services/naia_wildcard_zip_importer.dart';
import 'package:naiweaver/core/services/wildcard_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('imports a Korean nested wildcard text file', () async {
    final root = await Directory.systemTemp.createTemp('zip_import_test_');
    try {
      final directory = Directory('${root.path}/wildcards');
      await directory.create();
      final data = 'sample'.codeUnits;
      final archive = Archive()
        ..addFile(ArchiveFile('분류/검증.txt', data.length, data));
      final zip = File('${root.path}/test.zip');
      await zip.writeAsBytes(ZipEncoder().encode(archive));

      final service = WildcardService(wildcardDir: directory.path);
      final imported = await NaiaWildcardZipImporter(service).importFile(zip.path);
      expect(imported, 1);
      expect(await File('${directory.path}/분류/검증.txt').readAsString(), 'sample');
    } finally {
      await root.delete(recursive: true);
    }
  });

  test('does not overwrite an existing wildcard file', () async {
    final root = await Directory.systemTemp.createTemp('zip_conflict_test_');
    try {
      final directory = Directory('${root.path}/wildcards');
      await directory.create();
      final file = File('${directory.path}/sample.txt');
      await file.writeAsString('original');
      final data = 'changed'.codeUnits;
      final archive = Archive()
        ..addFile(ArchiveFile('sample.txt', data.length, data));
      final zip = File('${root.path}/test.zip');
      await zip.writeAsBytes(ZipEncoder().encode(archive));

      final service = WildcardService(wildcardDir: directory.path);
      await expectLater(
        NaiaWildcardZipImporter(service).importFile(zip.path),
        throwsA(isA<FormatException>()),
      );
      expect(await file.readAsString(), 'original');
    } finally {
      await root.delete(recursive: true);
    }
  });
}
