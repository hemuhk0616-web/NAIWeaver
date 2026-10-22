import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:naiweaver/core/services/naia_prompt_pipeline.dart';
import 'package:naiweaver/core/services/wildcard_processor.dart';

void main() {
  test('nested conditions preserve syntax and expand only action values', () async {
    final directory = await Directory.systemTemp.createTemp('naia_pipeline_');
    try {
      await File('${directory.path}/color.txt').writeAsString('pink hair');
      final pipeline = NaiaPromptPipeline(
        WildcardProcessor(wildcardDir: directory.path));
      final expanded = await pipeline.expandActionValues(
        '((solo&char_on(1))|hat):main+=__color__\n'
        '(solo):char_replace(1, blue hair, __color__)\n'
        '# (solo):main+=__color__');
      expect(expanded, contains('((solo&char_on(1))|hat):main+=pink hair'));
      expect(expanded, contains('(solo):char_replace(1, blue hair, __color__)'));
      expect(expanded, contains('# (solo):main+=__color__'));
    } finally {
      await directory.delete(recursive: true);
    }
  });
}
