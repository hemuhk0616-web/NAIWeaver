import 'package:flutter_test/flutter_test.dart';
import 'package:naiweaver/core/services/naia_rule_validator.dart';
import 'package:naiweaver/core/services/naia_ordered_rule_engine.dart';

void main() {
  group('NAIA rule validator', () {
    const validator = NaiaRuleValidator();

    test('accepts ordinary conditional append', () {
      expect(validator.validate('(solo):main+=smile'), isEmpty);
    });

    test('rejects malformed rule boundaries', () {
      expect(validator.validate('solo:main+=smile'), isNotEmpty);
      expect(validator.validate('(solo)main+=smile'), isNotEmpty);
    });

    test('reports unsupported global UC', () {
      final result = validator.validate('(solo):global_uc+=bad');
      expect(result.any((d) => d.warning && d.message.contains('global_uc')), isTrue);
    });

    test('validates character function arguments', () {
      expect(validator.validate('(solo):char_set(1,enabled)'), isEmpty);
      expect(validator.validate('(solo):char_replace(1,old,new)'), isEmpty);
      expect(validator.validate('(solo):char_set(0,enabled)'), isNotEmpty);
      expect(validator.validate('(solo):char_set(1,unknown)'), isNotEmpty);
      expect(validator.validate('(solo):char_replace(1,old)'), isNotEmpty);
    });

    test('accepts character-scoped rules handled by the generation pipeline', () {
      expect(validator.validate('char:1 (solo):main+=smile'), isEmpty);
      expect(validator.validate('char:2 (solo):main+=happy'), isEmpty);
    });

    test('detects empty logical operands', () {
      expect(validator.validate('(solo&):main+=smile'), isNotEmpty);
    });

    test('tracks physical line numbers', () {
      final result = validator.validate('# comment\n\ninvalid');
      expect(result.single.line, 3);
    });
  });

  group('NAIA ordered engine', () {
    const engine = NaiaOrderedRuleEngine();

    test('appends to main when condition matches', () {
      final result = engine.apply('solo', <String>[], '(solo):main+=smile');
      expect(result.main, 'solo, smile');
    });

    test('preserves commas inside angle-bracket prompt constructs', () {
      final result = engine.apply(
        'solo, <character:blue hair, golden eyes>, outdoors',
        <String>[],
        '(solo):main+=smile',
      );
      expect(result.main,
          'solo, <character:blue hair, golden eyes>, outdoors, smile');
    });

    test('preserves commas inside LoRA angle-bracket constructs', () {
      final result = engine.apply(
        'solo, <lora:style,0.8>, blue hair', <String>[],
        '(solo):main+=smile',
      );
      expect(result.main, 'solo, <lora:style,0.8>, blue hair, smile');
    });

    test('can match a complete angle-bracket construct', () {
      final result = engine.apply(
        '<lora:style,0.8>, solo', <String>[],
        '(<lora:style,0.8>):main+=smile',
      );
      expect(result.main, '<lora:style,0.8>, solo, smile');
    });

    test('does not append when condition fails', () {
      final result = engine.apply('solo', <String>[], '(duo):main+=smile');
      expect(result.main, 'solo');
    });

    test('later rules observe earlier main mutations', () {
      final result = engine.apply('solo', <String>[],
          '(solo):main+=smile\n(smile):main+=happy');
      expect(result.main, 'solo, smile, happy');
    });

    test('character state changes are visible to later conditions', () {
      final result = engine.apply('solo', <String>['blue hair'],
          '(solo):char_set(1,disabled)\n(~char_on(1)):main+=disabled');
      expect(result.enabled, <bool>[false]);
      expect(result.main, 'solo, disabled');
    });

    test('character replacement is isolated to working copy', () {
      final source = <String>['blue hair'];
      final result = engine.apply('solo', source,
          '(solo):char_replace(1,blue hair,red hair)');
      expect(result.characters.single, 'red hair');
      expect(source.single, 'blue hair');
    });

    test('UC and negative assignments update separate outputs', () {
      final result = engine.apply('solo', <String>['blue hair'],
          '(solo):neg+=bad anatomy\n(solo):uc:1+=blurry',
          negative: 'lowres', characterUc: <String>['']);
      expect(result.negative, 'lowres, bad anatomy');
      expect(result.characterUc.single, 'blurry');
    });
  });
}
