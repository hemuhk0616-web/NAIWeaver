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
    final prefixTags = <String>[];
    final postfixTags = <String>[];
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

      // NAIA accepts global_uc syntax but does not apply it to the payload.
      if (RegExp(r'^global_uc(?:\+=|\+:|=)').hasMatch(action)) {
        continue;
      }
      // NAIA's unknown-target +: appends its combined text to main.
      final plusColon = action.indexOf('+:');
      if (plusColon >= 0) {
        final target = action.substring(0, plusColon).trim();
        final recognized = const {'prefix', 'main', 'postfix', 'neg', 'global_uc'}
            .contains(target) ||
            RegExp(r'^(char|uc):(\d+|\*)$', caseSensitive: false)
                .hasMatch(target);
        if (!recognized) {
          final value = action.replaceFirst('+:', '').trim();
          currentMain = [currentMain, value]
              .where((v) => v.isNotEmpty).join(', ');
          continue;
        }
      }
      final affix = RegExp(r'^(prefix|postfix)(\+=|\+:)(.*)r'^neg(\+=|\+:|=)(.*)$').firstMatch(action);
      if (neg != null) {
        final value = neg.group(2)!.trim();
        currentNegative = neg.group(1) == '=' ? value :
          [currentNegative, value].where((v) => v.isNotEmpty).join(', ');
        continue;
      }
      final scoped = RegExp(r'^(char|uc):(\d+|\*)(\+=|\+:|=)(.*)$',
          caseSensitive: false).firstMatch(action);
      if (scoped != null) {
        final kind = scoped.group(1)!.toLowerCase();
        final rawIndex = scoped.group(2)!;
        final operator = scoped.group(3)!;
        final value = scoped.group(4)!.trim();
        final target = kind == 'char' ? currentCharacters : currentUc;
        final indexes = rawIndex == '*'
            ? List<int>.generate(target.length, (i) => i)
            : [int.parse(rawIndex) - 1];
        for (final index in indexes) {
          if (index < 0 || index >= target.length) continue;
          target[index] = operator == '=' ? value :
              [target[index], value].where((v) => v.isNotEmpty).join(', ');
        }
        continue;
      }
      currentMain = conditions.apply(currentMain, rule,
        characterPrompts: currentCharacters, characterEnabled: enabled);
    }
    final composedMain = [...prefixTags, currentMain, ...postfixTags]
        .where((v) => v.isNotEmpty).join(', ');
    return (main: composedMain, negative: currentNegative,
      characters: currentCharacters, characterUc: currentUc, enabled: enabled);
  }
}
)
          .firstMatch(action);
      if (affix != null) {
        final value = affix.group(3)!.trim();
        if (value.isNotEmpty) {
          if (affix.group(1) == 'prefix') {
            prefixTags.add(value);
          } else {
            postfixTags.add(value);
          }
        }
        continue;
      }
      // A matching condition can inspect all three prompt segments.
      final appendTag = RegExp(r'^(.+?)\+=(.*)$').firstMatch(action);
      final replaceTag = RegExp(r'^(.+?)=(.*)$').firstMatch(action);
      if (appendTag != null &&
          !const {'main', 'neg', 'global_uc'}.contains(appendTag.group(1)!.trim()) &&
          !RegExp(r'^(char|uc):(\d+|\*)$').hasMatch(appendTag.group(1)!.trim())) {
        final target = appendTag.group(1)!.trim();
        if (target != 'prefix' && target != 'postfix') {
          final value = appendTag.group(2)!.trim();
          bool insertAfter(List<String> tags) {
            final index = tags.indexWhere((tag) => tag.trim() == target);
            if (index < 0) return false;
            tags.insert(index + 1, value);
            return true;
          }
          if (insertAfter(prefixTags) || insertAfter(postfixTags)) continue;
        }
      }
      if (replaceTag != null &&
          !const {'main', 'neg', 'global_uc'}.contains(replaceTag.group(1)!.trim()) &&
          !RegExp(r'^(char|uc):(\d+|\*)$').hasMatch(replaceTag.group(1)!.trim())) {
        final target = replaceTag.group(1)!.trim();
        final value = replaceTag.group(2)!.trim();
        bool replaceIn(List<String> tags) {
          var changed = false;
          for (var i = 0; i < tags.length; i++) {
            if (tags[i].trim() == target) {
              tags[i] = value;
              changed = true;
            }
          }
          return changed;
        }
        if (replaceIn(prefixTags) || replaceIn(postfixTags)) continue;
      }
      final neg = RegExp(r'^neg(\+=|\+:|=)(.*)$').firstMatch(action);
      if (neg != null) {
        final value = neg.group(2)!.trim();
        currentNegative = neg.group(1) == '=' ? value :
          [currentNegative, value].where((v) => v.isNotEmpty).join(', ');
        continue;
      }
      final scoped = RegExp(r'^(char|uc):(\d+|\*)(\+=|\+:|=)(.*)$',
          caseSensitive: false).firstMatch(action);
      if (scoped != null) {
        final kind = scoped.group(1)!.toLowerCase();
        final rawIndex = scoped.group(2)!;
        final operator = scoped.group(3)!;
        final value = scoped.group(4)!.trim();
        final target = kind == 'char' ? currentCharacters : currentUc;
        final indexes = rawIndex == '*'
            ? List<int>.generate(target.length, (i) => i)
            : [int.parse(rawIndex) - 1];
        for (final index in indexes) {
          if (index < 0 || index >= target.length) continue;
          target[index] = operator == '=' ? value :
              [target[index], value].where((v) => v.isNotEmpty).join(', ');
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
