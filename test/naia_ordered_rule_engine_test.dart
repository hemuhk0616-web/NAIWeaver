import 'package:flutter_test/flutter_test.dart';
import 'package:naiweaver/core/services/naia_ordered_rule_engine.dart';

void main() {
  const engine = NaiaOrderedRuleEngine();

  test('character replacement drives later main and enabled rules', () {
    final result = engine.apply(
      'solo',
      ['blue hair', 'green eyes'],
      '(solo):char_replace(1, blue hair, pink hair)\n'
      '(char_in(1, pink hair)):main+=smile\n'
      '(smile):char_set(2, disabled)',
    );
    expect(result.main, 'solo, smile');
    expect(result.characters, ['pink hair', 'green eyes']);
    expect(result.enabled, [true, false]);
  });

  test('negative and character UC follow earlier main changes', () {
    final result = engine.apply(
      'solo',
      ['pink hair'],
      '(solo):main+=smile\n'
      '(smile):neg+=blurry\n'
      '(smile):uc:1+=bad hands',
      negative: 'lowres',
      characterUc: ['bad anatomy'],
    );
    expect(result.negative, 'lowres, blurry');
    expect(result.characterUc, ['bad anatomy, bad hands']);
  });

  test('nested conditions and disabled slots retain source order', () {
    final result = engine.apply(
      'solo',
      ['pink hair', 'blue eyes'],
      '((solo&char_on(2))|hat):char_set(2, disabled)\n'
      '(~char_on(2)):main+=solo focus',
    );
    expect(result.enabled, [true, false]);
    expect(result.main, 'solo, solo focus');
  });

  test('does not mutate original character lists', () {
    final characters = ['blue hair'];
    final uc = ['bad hands'];
    engine.apply('solo', characters, '(solo):char_set(1, disabled)',
      characterUc: uc);
    expect(characters, ['blue hair']);
    expect(uc, ['bad hands']);
  });
}
