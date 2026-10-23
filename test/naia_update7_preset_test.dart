import 'dart:io';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:naiweaver/core/services/naia_prompt_pipeline.dart';
import 'package:naiweaver/core/services/wildcard_processor.dart';
import 'package:naiweaver/core/services/naia_prompt_pipeline.dart';
import 'package:naiweaver/core/services/wildcard_processor.dart';
import 'package:naiweaver/core/services/naia_update7_preset.dart';
import 'package:naiweaver/core/services/naia_rule_validator.dart';

void main() {
  test('update7 preset resolves imported wildcard fixture end to end', () async {
    final root = await Directory.systemTemp.createTemp('naia_update7_integration_');
    try {
      for (final name in NaiaUpdate7Preset.requiredWildcards) {
        final file = File('${root.path}/$name.txt');
        await file.parent.create(recursive: true);
        await file.writeAsString('fixture_tag');
      }
      final pipeline = NaiaPromptPipeline(
        WildcardProcessor(wildcardDir: root.path));
      final prompt = await pipeline.process(NaiaUpdate7Preset.leadingPrompt);
      expect(prompt, isNot(contains('__')));
      expect(prompt, contains('fixture_tag'));

      final rules = await pipeline.expandActionValues(NaiaUpdate7Preset.rules);
      expect(rules, isNot(contains('__')));
      expect(rules, contains('fixture_tag'));
      expect(rules, isNot(contains('^')));
      expect(const NaiaRuleValidator().validate(rules)
          .where((issue) => !issue.warning), isEmpty);
    } finally {
      await root.delete(recursive: true);
    }
  });

  test('update7 preset expands imported wildcards and applies ordered rules', () async {
    final root = await Directory.systemTemp.createTemp('naia_update7_integration_');
    try {
      for (final name in NaiaUpdate7Preset.requiredWildcards) {
        final file = File('${root.path}/$name.txt');
        await file.parent.create(recursive: true);
        final value = switch (name) {
          '대분류' => 'masturbation',
          '사정여부' => 'no ejaculation',
          '배경_의상' => 'bedroom',
          '체위/자위' => 'solo pose',
          '의상/의상' => 'casual clothes',
          _ => 'test placeholder',
        };
        await file.writeAsString(value);
      }
      final pipeline = NaiaPromptPipeline(
        WildcardProcessor(wildcardDir: root.path));
      final output = await pipeline.process(
        NaiaUpdate7Preset.leadingPrompt,
        rules: NaiaUpdate7Preset.rules,
      );
      expect(output, contains('solo'));
      expect(output, contains('solo pose'));
      expect(output, contains('casual clothes'));
      expect(output, isNot(contains('__')));
    } finally {
      await root.delete(recursive: true);
    }
  });

  test('update7 manifest covers all wildcard references', () {
    final source = '${NaiaUpdate7Preset.leadingPrompt}\n${NaiaUpdate7Preset.rules}';
    final references = RegExp(r'__([^\r\n]+?)__')
        .allMatches(source).map((m) => m.group(1)!).toSet();
    expect(NaiaUpdate7Preset.requiredWildcards.toSet().containsAll(references), isTrue);
  });

  test('update7 rules have no static syntax errors', () {
    final errors = const NaiaRuleValidator()
        .validate(NaiaUpdate7Preset.rules)
        .where((issue) => !issue.warning).toList();
    expect(errors, isEmpty);
  });
}
