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
  test('NAIA scoped char and UC targets accept star and 1-based index', () {
    final result = engine.apply(
      'solo', ['blue hair', 'pink hair'],
      '(solo):char:1+=smile\n'
      '(solo):uc:*+=bad hands\n'
      '(char_in(1, smile)):char:2=green eyes',
      characterUc: ['lowres', 'blurry'],
    );
    expect(result.characters, ['blue hair, smile', 'green eyes']);
    expect(result.characterUc, ['lowres, bad hands', 'blurry, bad hands']);
  });

  test('global UC remains unsupported as in NAIA runtime', () {
    final result = engine.apply('solo', ['pink hair'],
      '(solo):global_uc+=bad hands',
      negative: 'lowres', characterUc: ['blurry']);
    expect(result.main, 'solo');
    expect(result.negative, 'lowres');
    expect(result.characterUc, ['blurry']);
  });

  test('unknown plus-colon target appends combined text to main', () {
    final result = engine.apply('solo', [],
      '(solo):mystery+:smile');
    expect(result.main, 'solo, mysterysmile');
  });

  test('negative replacement differs from append', () {
    final result = engine.apply('solo', [],
      '(solo):neg+=blurry\n(solo):neg=lowres',
      negative: 'bad anatomy');
    expect(result.negative, 'lowres');
  });

}
