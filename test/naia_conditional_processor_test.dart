import 'package:flutter_test/flutter_test.dart';
import 'package:naiweaver/core/services/naia_conditional_processor.dart';

void main() {
  const engine = NaiaConditionalProcessor();

  test('NAIA append and insert-after', () {
    expect(engine.apply('solo', '(solo):main+=smile'), 'solo, smile');
    expect(engine.apply('solo, blue eyes', '(solo):solo+=pink hair'),
        'solo, pink hair, blue eyes');
  });

  test('nested boolean conditions respect parentheses', () {
    expect(engine.apply('solo, hat', '((solo|1girl)&hat):main+=smile'),
        'solo, hat, smile');
    expect(engine.apply('solo', '(solo&(hat|glasses)):main+=smile'), 'solo');
  });

  test('char_in and char_on inspect expanded character context', () {
    expect(engine.apply('solo', '(char_in(1, pink hair)&char_on(1)):main+=smile',
        characterPrompts: ['pink hair, blue eyes'], characterEnabled: [true]),
        'solo, smile');
    expect(engine.apply('solo', '(~char_on(1)):main+=smile',
        characterPrompts: ['pink hair'], characterEnabled: [false]),
        'solo, smile');
  });

  test('NAIA plus-colon appends to fixed targets', () {
    expect(engine.apply('solo', '(solo):main+:smile'), 'solo, smile');
    expect(engine.apply('solo', '(solo):postfix+:blush'), 'solo, blush');
  });

  test('NAIA replacement handles weighted tags', () {
    expect(engine.apply('1.2::solo::, smile', '(solo):solo=1girl'),
        '1girl, smile');
    expect(engine.apply('long blue hair', '(*blue):*blue=pink hair'),
        'pink hair');
  });

  test('NAIA condition and bracket-aware splitting', () {
    expect(engine.apply('solo', '(solo&~hat):postfix+=<a,b|c>, blush'),
        'solo, <a,b|c>, blush');
    expect(engine.apply('solo, hat', '(solo&~hat):main+=blush'),
        'solo, hat');
  });
}
