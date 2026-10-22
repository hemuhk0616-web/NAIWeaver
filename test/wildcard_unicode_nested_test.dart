import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:naiweaver/core/services/wildcard_processor.dart';
import 'package:naiweaver/core/services/wildcard_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Unicode and nested wildcard names expand from UTF-8 TXT', () async {
    final root = await Directory.systemTemp.createTemp('nai_wildcards_');
    try {
      final nested = Directory('${root.path}/캐릭터/의상');
      await nested.create(recursive: true);
      await File('${nested.path}/분홍 머리.txt').writeAsString('pink hair\n');
      final service = WildcardService(wildcardDir: root.path);
      await service.refresh();
      expect(service.wildcardNames, contains('캐릭터/의상/분홍 머리'));
      final processor = WildcardProcessor(wildcardDir: root.path, wildcardService: service);
      expect(await processor.process('1girl, __캐릭터/의상/분홍 머리__'), '1girl, pink hair');
      expect(await processor.process('__../escape__'), '__../escape__');
    } finally {
      await root.delete(recursive: true);
    }
  });
  test('Nested expansion, legacy weights and cycles', () async {
    final root = await Directory.systemTemp.createTemp('nai_wildcards_');
    try {
      await File('${root.path}/first.txt').writeAsString('__second__\\n');
      await File('${root.path}/second.txt').writeAsString('100::blue hair\\n');
      await File('${root.path}/cycle.txt').writeAsString('__cycle__\\n');
      final processor = WildcardProcessor(wildcardDir: root.path);
      expect(await processor.process('__first__'), 'blue hair');
      expect(await processor.process('__cycle__'), '__cycle__');
    } finally {
      await root.delete(recursive: true);
    }
  });
}
