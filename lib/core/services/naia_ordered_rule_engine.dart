import 'naia_character_actions.dart';
import 'naia_conditional_processor.dart';

/// Source-ordered conditional rules across main, character and UC fields.
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
    var mainTags = _split(main);
    final prefix = <String>[];
    final postfix = <String>[];
    var currentNegative = negative;
    var currentCharacters = List<String>.from(characters);
    final uc = List<String>.from(characterUc);
    var enabled = List<bool>.filled(characters.length, true);

    String combined() => [...prefix, ...mainTags, ...postfix].join(', ');
    for (final line in rules.split(RegExp(r'\r?\n'))) {
      final rule = line.trim();
      if (!rule.startsWith('(')) continue;
      final end = _matchingParen(rule);
      if (end < 0 || end + 1 >= rule.length || rule[end + 1] != ':') {
        continue;
      }
      final condition = rule.substring(1, end);
      final action = rule.substring(end + 2).trim();
      if (!conditions.matches(condition, combined(),
          characterPrompts: currentCharacters, characterEnabled: enabled)) {
        continue;
      }

      if (RegExp(r'^char_(set|replace)\(').hasMatch(action)) {
        final result = actions.apply(currentCharacters, rule,
          initialEnabled: enabled,
          matches: (c, prompts, states) => conditions.matches(c, combined(),
            characterPrompts: prompts, characterEnabled: states));
        currentCharacters = result.prompts;
        enabled = result.enabled;
        continue;
      }
      final parsed = RegExp(r'^(.+?)(\+=|\+:|=)(.*)$').firstMatch(action);
      if (parsed == null) continue;
      final target = parsed.group(1)!.trim();
      final operator = parsed.group(2)!;
      final values = _split(parsed.group(3)!);
      if (target == 'global_uc') continue;
      if (target == 'neg') {
        currentNegative = operator == '=' ? values.join(', ') :
          [..._split(currentNegative), ...values].join(', ');
        continue;
      }
      final scoped = RegExp(r'^(char|uc):(\d+|\*)$', caseSensitive: false)
          .firstMatch(target);
      if (scoped != null) {
        final slots = scoped.group(1)!.toLowerCase() == 'char' ? currentCharacters : uc;
        final indexes = scoped.group(2) == '*'
            ? List<int>.generate(slots.length, (i) => i)
            : [int.parse(scoped.group(2)!) - 1];
        for (final i in indexes) {
          if (i < 0 || i >= slots.length) continue;
          slots[i] = operator == '=' ? values.join(', ') :
              [..._split(slots[i]), ...values].join(', ');
        }
        continue;
      }
      if (operator == '+:' &&
          !const {'prefix', 'main', 'postfix'}.contains(target)) {
        mainTags.addAll(_split(action.replaceFirst('+:', '')));
        continue;
      }
      if (operator != '=') {
        if (target == 'prefix') {
          prefix.addAll(values);
        } else if (target == 'postfix') {
          postfix.addAll(values);
        } else if (target == 'main') {
          mainTags.addAll(values);
        } else {
          // NAIA inserts after the first matching tag, scanning segments in order.
          for (final segment in [prefix, mainTags, postfix]) {
            final i = segment.indexWhere((tag) => _matchesTag(tag, target));
            if (i >= 0) {
              segment.insertAll(i + 1, values);
              break;
            }
          }
        }
        continue;
      }
      // NAIA treats ordinary '=' as a tag replacement, even when the\n      // target text happens to be 'main', 'prefix', or 'postfix'.
      for (final segment in [prefix, mainTags, postfix]) {
        final replaced = <String>[];
        for (final tag in segment) {
          if (_matchesTag(tag, target)) {
            replaced.addAll(values);
          } else {
            replaced.add(tag);
          }
        }
        segment..clear()..addAll(replaced);
      }
    }
    return (main: combined(), negative: currentNegative,
      characters: currentCharacters, characterUc: uc, enabled: enabled);
  }

  Future<({String main, String negative, List<String> characters,
    List<String> characterUc, List<bool> enabled})> applyAsync(
    String main, List<String> characters, String rules, {
    String negative = '',
    List<String> characterUc = const [],
    List<bool> characterEnabled = const [],
    required Future<String> Function(String) expandAction,
  }) async {
    const conditions = NaiaConditionalProcessor();
    const actions = NaiaCharacterActions();
    var mainTags = _split(main);
    final prefix = <String>[];
    final postfix = <String>[];
    var currentNegative = negative;
    var currentCharacters = List<String>.from(characters);
    final uc = List<String>.from(characterUc);
    var enabled = List<bool>.generate(characters.length, (i) => i < characterEnabled.length ? characterEnabled[i] : true);

    String combined() => [...prefix, ...mainTags, ...postfix].join(', ');
    for (final line in rules.split(RegExp(r'\r?\n'))) {
      final rule = line.trim();
      if (!rule.startsWith('(')) continue;
      final end = _matchingParen(rule);
      if (end < 0 || end + 1 >= rule.length || rule[end + 1] != ':') {
        continue;
      }
      final condition = rule.substring(1, end);
      final action = rule.substring(end + 2).trim();
      if (!conditions.matches(condition, combined(),
          characterPrompts: currentCharacters, characterEnabled: enabled)) {
        continue;
      }

      if (RegExp(r'^char_(set|replace)\(').hasMatch(action)) {
        final result = actions.apply(currentCharacters, rule,
          initialEnabled: enabled,
          matches: (c, prompts, states) => conditions.matches(c, combined(),
            characterPrompts: prompts, characterEnabled: states));
        currentCharacters = result.prompts;
        enabled = result.enabled;
        continue;
      }
      final parsed = RegExp(r'^(.+?)(\+=|\+:|=)(.*)$').firstMatch(action);
      if (parsed == null) continue;
      final target = parsed.group(1)!.trim();
      final operator = parsed.group(2)!;
      final values = _split(await expandAction(parsed.group(3)!));
      if (target == 'global_uc') continue;
      if (target == 'neg') {
        currentNegative = operator == '=' ? values.join(', ') :
          [..._split(currentNegative), ...values].join(', ');
        continue;
      }
      final scoped = RegExp(r'^(char|uc):(\d+|\*)$', caseSensitive: false)
          .firstMatch(target);
      if (scoped != null) {
        final slots = scoped.group(1)!.toLowerCase() == 'char' ? currentCharacters : uc;
        final indexes = scoped.group(2) == '*'
            ? List<int>.generate(slots.length, (i) => i)
            : [int.parse(scoped.group(2)!) - 1];
        for (final i in indexes) {
          if (i < 0 || i >= slots.length) continue;
          slots[i] = operator == '=' ? values.join(', ') :
              [..._split(slots[i]), ...values].join(', ');
        }
        continue;
      }
      if (operator == '+:' &&
          !const {'prefix', 'main', 'postfix'}.contains(target)) {
        mainTags.addAll(_split(action.replaceFirst('+:', '')));
        continue;
      }
      if (operator != '=') {
        if (target == 'prefix') {
          prefix.addAll(values);
        } else if (target == 'postfix') {
          postfix.addAll(values);
        } else if (target == 'main') {
          mainTags.addAll(values);
        } else {
          // NAIA inserts after the first matching tag, scanning segments in order.
          for (final segment in [prefix, mainTags, postfix]) {
            final i = segment.indexWhere((tag) => _matchesTag(tag, target));
            if (i >= 0) {
              segment.insertAll(i + 1, values);
              break;
            }
          }
        }
        continue;
      }
      // NAIA treats ordinary '=' as a tag replacement, even when the\n      // target text happens to be 'main', 'prefix', or 'postfix'.
      for (final segment in [prefix, mainTags, postfix]) {
        final replaced = <String>[];
        for (final tag in segment) {
          if (_matchesTag(tag, target)) {
            replaced.addAll(values);
          } else {
            replaced.add(tag);
          }
        }
        segment..clear()..addAll(replaced);
      }
    }
    return (main: combined(), negative: currentNegative,
      characters: currentCharacters, characterUc: uc, enabled: enabled);
  }

  static int _matchingParen(String rule) {
    var depth = 0;
    for (var i = 0; i < rule.length; i++) {
      if (rule[i] == '(') depth++;
      if (rule[i] == ')') {
        depth--;
        if (depth == 0) return i;
      }
    }
    return -1;
  }

  // Keep commas inside angle-bracket prompt constructs intact.
  static List<String> _split(String text) {
    final tags = <String>[];
    final buffer = StringBuffer();
    var angleDepth = 0;
    for (final char in text.split('')) {
      if (char == '<') angleDepth++;
      if (char == '>' && angleDepth > 0) angleDepth--;
      if (char == ',' && angleDepth == 0) {
        final tag = buffer.toString().trim();
        if (tag.isNotEmpty) tags.add(tag);
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }
    final last = buffer.toString().trim();
    if (last.isNotEmpty) tags.add(last);
    return tags;
  }

  static String _unweight(String value) {
    final trimmed = value.trim();
    final match = RegExp(r'^[-+]?\d+(?:\.\d+)?::(.*?)(?:::)?$')
        .firstMatch(trimmed);
    if (match == null) return trimmed;
    return match.group(1)!.replaceFirst(RegExp(r'::$'), '').trim();
  }

  static bool _matchesTag(String tag, String target) {
    final partial = target.startsWith('*');
    final needle = _unweight(partial ? target.substring(1) : target);
    final value = _unweight(tag);
    return partial ? needle.isNotEmpty && value.contains(needle) : value == needle;
  }
}
