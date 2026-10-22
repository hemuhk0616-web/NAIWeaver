import 'naia_character_actions.dart';
import 'naia_conditional_processor.dart';

/// Source-ordered NAIA rule subset; inputs are already wildcard-expanded.
class NaiaOrderedRuleEngine {
  const NaiaOrderedRuleEngine();

  ({String main, String negative, List<String> characters,
    List<String> characterUc, List<bool> enabled}) apply(
    String main, List<String> characters, String rules, {
    String negative = '',
    List<String> characterUc = const [],
  }) {
    const conditions = NaiaConditionalProcessor();
    const actions = NaiaCharacterActions();
    var currentMain = main;
    var currentNegative = negative;
    var currentCharacters = List<String>.from(characters);
    final currentUc = List<String>.from(characterUc);
    var enabled = List<bool>.filled(characters.length, true);
    for (final line in rules.split(RegExp(r'\r?\n'))) {
      final rule = line.trim();
      if (rule.isEmpty || rule.startsWith('#')) continue;
      if (RegExp(r'^\(.*\):char_(set|replace)\(').hasMatch(rule)) {
        final result = actions.apply(currentCharacters, rule,
          initialEnabled: enabled,
          matches: (condition, prompts, states) => conditions.matches(
            condition, currentMain,
            characterPrompts: prompts, characterEnabled: states));
        currentCharacters = result.prompts;
        enabled = result.enabled;
        continue;
      }
      if (!rule.startsWith('(')) continue;
      var depth = 0;
      var end = -1;
      for (var i = 0; i < rule.length; i++) {
        if (rule[i] == '(') depth++;
        if (rule[i] == ')') {
          depth--;
          if (depth == 0) { end = i; break; }
        }
      }
      if (end < 0 || end + 1 >= rule.length || rule[end + 1] != ':') continue;
      final condition = rule.substring(1, end);
      final action = rule.substring(end + 2).trim();
      if (!conditions.matches(condition, currentMain,
          characterPrompts: currentCharacters, characterEnabled: enabled)) continue;

      final neg = RegExp(r'^neg(\+=|\+:|=)(.*)$').firstMatch(action);
      if (neg != null) {
        final value = neg.group(2)!.trim();
        currentNegative = neg.group(1) == '=' ? value :
          [currentNegative, value].where((v) => v.isNotEmpty).join(', ');
        continue;
      }
      final uc = RegExp(r'^uc:(\d+)(\+=|\+:|=)(.*)$').firstMatch(action);
      if (uc != null) {
        final index = int.parse(uc.group(1)!) - 1;
        if (index >= 0 && index < currentUc.length) {
          final value = uc.group(3)!.trim();
          currentUc[index] = uc.group(2) == '=' ? value :
            [currentUc[index], value].where((v) => v.isNotEmpty).join(', ');
        }
        continue;
      }
      currentMain = conditions.apply(currentMain, rule,
        characterPrompts: currentCharacters, characterEnabled: enabled);
    }
    return (main: currentMain, negative: currentNegative,
      characters: currentCharacters, characterUc: currentUc, enabled: enabled);
  }
}
