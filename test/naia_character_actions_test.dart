import 'package:flutter_test/flutter_test.dart';
import 'package:naiweaver/core/services/naia_character_actions.dart';
import 'package:naiweaver/core/services/naia_conditional_processor.dart';

void main() {
  const actions = NaiaCharacterActions();
  const conditions = NaiaConditionalProcessor();

  test('char_set disables and re-enables a stable 1-based slot', () {
    final prompts = ['pink hair', 'blue hair'];
    final enabled = actions.applyEnabled(
      prompts,
      '(solo):char_set(2, disabled)\n'
      '(~char_on(2)):char_set(2, enabled)',
      matches: (condition, current, states) => conditions.matches(
        condition, 'solo', characterPrompts: current,
        characterEnabled: states,
      ),
    );
    expect(enabled, [true, true]);
    expect(prompts, ['pink hair', 'blue hair']);
  });

  test('char_set does not mutate unrelated slots', () {
    final result = actions.applyEnabled(
      ['pink hair', 'blue hair'],
      '(solo):char_set(1, disabled)',
      matches: (condition, current, states) => conditions.matches(
        condition, 'solo', characterPrompts: current,
        characterEnabled: states,
      ),
    );
    expect(result, [false, true]);
  });
  test('char_replace changes what subsequent char_in conditions see', () {
    final result = actions.apply(
      ['blue hair', 'green eyes'],
      '(solo):char_replace(1, blue hair, pink hair)\n'
      '(char_in(1, pink hair)):char_set(2, disabled)',
      matches: (condition, current, states) => conditions.matches(
        condition, 'solo', characterPrompts: current,
        characterEnabled: states,
      ),
    );
    expect(result.prompts, ['pink hair', 'green eyes']);
    expect(result.enabled, [true, false]);
  });

  test('a disabled character can be re-enabled by a later rule', () {
    final result = actions.apply(
      ['pink hair'],
      '(solo):char_set(1, disabled)\n'
      '(~char_on(1)):char_set(1, enabled)',
      matches: (condition, current, states) => conditions.matches(
        condition, 'solo', characterPrompts: current,
        characterEnabled: states,
      ),
    );
    expect(result.enabled, [true]);
  });

}
