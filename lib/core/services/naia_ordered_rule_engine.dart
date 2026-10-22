import 'naia_character_actions.dart';
import 'naia_conditional_processor.dart';

class NaiaOrderedRuleEngine {
  const NaiaOrderedRuleEngine();

  ({String main, List<String> characters, List<bool> enabled}) apply(
    String main, List<String> characters, String rules) {
    const conditions = NaiaConditionalProcessor();
    const actions = NaiaCharacterActions();
    var currentMain = main;
    var currentCharacters = List<String>.from(characters);
    var enabled = List<bool>.filled(characters.length, true);
    for (final line in rules.split(RegExp(r'\r?\n'))) {
      final rule = line.trim();
      if (rule.isEmpty || rule.startsWith('#')) continue;
      if (RegExp(r':char_(set|replace)\(').hasMatch(rule)) {
        final result = actions.apply(currentCharacters, rule,
          initialEnabled: enabled,
          matches: (condition, prompts, states) => conditions.matches(
            condition, currentMain,
            characterPrompts: prompts, characterEnabled: states));
        currentCharacters = result.prompts;
        enabled = result.enabled;
      } else {
        currentMain = conditions.apply(currentMain, rule,
          characterPrompts: currentCharacters,
          characterEnabled: enabled);
      }
    }
    return (main: currentMain, characters: currentCharacters, enabled: enabled);
  }
}
