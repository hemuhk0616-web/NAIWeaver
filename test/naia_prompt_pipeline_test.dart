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
  test('character-scoped action values expand after scope removal', () async {
    final directory = await Directory.systemTemp.createTemp('naia_scoped_');
    try {
      await File('${directory.path}/color.txt').writeAsString('pink hair');
      final pipeline = NaiaPromptPipeline(
        WildcardProcessor(wildcardDir: directory.path));
      final result = await pipeline.process('solo',
        rules: '(solo):main+=__color__');
      expect(result, 'solo, pink hair');
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('character-scoped rules can inspect another expanded character', () async {
    final directory = await Directory.systemTemp.createTemp('naia_cross_char_');
    try {
      await File('${directory.path}/color.txt').writeAsString('pink hair');
      final pipeline = NaiaPromptPipeline(
        WildcardProcessor(wildcardDir: directory.path));
      final first = await pipeline.process('__color__');
      final second = await pipeline.process('blue eyes',
        rules: '(char_in(1, pink hair)&char_on(1)):main+=smile',
        characterPrompts: [first, 'blue eyes'],
        characterEnabled: [true, true]);
      expect(second, 'blue eyes, smile');
      final disabled = await pipeline.process('blue eyes',
        rules: '(char_in(1, pink hair)&char_on(1)):main+=smile',
        characterPrompts: [first, 'blue eyes'],
        characterEnabled: [false, true]);
      expect(disabled, 'blue eyes');
    } finally {
      await directory.delete(recursive: true);
    }
  });
}
