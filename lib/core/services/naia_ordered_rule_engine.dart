import 'naia_character_actions.dart';
import 'naia_conditional_processor.dart';

class NaiaOrderedRuleEngine {
  const NaiaOrderedRuleEngine();

  ({String main, String negative, List<String> characters, List<String> characterUc, List<bool> enabled}) apply(
    String main, List<String> characters, String rules, {
    String negative = '',
    List<String> characterUc = const [],
  }) {
    const conditions = NaiaConditionalProcessor();
    const actions = NaiaCharacterActions();
    var currentMain = main;
    var currentNegative = negative;
    final currentUc = List<String>.from(characterUc);
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
      } else if (RegExp(r'^\([^\n]*\):neg(?:\+=|\+:|=)').hasMatch(rule)) {
        final parsed = RegExp(r'^\((.*)\):neg(\+=|\+:|=)(.*)(currentMain, rule,
          characterPrompts: currentCharacters,
          characterEnabled: enabled);
      }
    }
    return (main: currentMain, negative: currentNegative,
      characters: currentCharacters, characterUc: currentUc, enabled: enabled);
  }
}
).firstMatch(rule);
        if (parsed != null && conditions.matches(parsed.group(1)!, currentMain,
            characterPrompts: currentCharacters, characterEnabled: enabled)) {
          final value = parsed.group(3)!.trim();
          currentNegative = parsed.group(2) == '=' ? value :
              [currentNegative, value].where((v) => v.isNotEmpty).join(', ');
        }
      } else if (RegExp(r'^\([^\n]*\):uc:\d+(?:\+=|\+:|=)').hasMatch(rule)) {
        final parsed = RegExp(r'^\((.*)\):uc:(\d+)(\+=|\+:|=)(.*)(currentMain, rule,
          characterPrompts: currentCharacters,
          characterEnabled: enabled);
      }
    }
    return (main: currentMain, characters: currentCharacters, enabled: enabled);
  }
}
).firstMatch(rule);
        if (parsed != null && conditions.matches(parsed.group(1)!, currentMain,
            characterPrompts: currentCharacters, characterEnabled: enabled)) {
          final index = int.parse(parsed.group(2)!) - 1;
          if (index >= 0 && index < currentUc.length) {
            final value = parsed.group(4)!.trim();
            currentUc[index] = parsed.group(3) == '=' ? value :
                [currentUc[index], value].where((v) => v.isNotEmpty).join(', ');
          }
        }
      } else {
        currentMain = conditions.apply(currentMain, rule,
          characterPrompts: currentCharacters,
          characterEnabled: enabled);
      }
    }
    return (main: currentMain, characters: currentCharacters, enabled: enabled);
  }
}
