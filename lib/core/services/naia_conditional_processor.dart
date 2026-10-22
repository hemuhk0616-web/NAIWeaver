/// A pure Dart subset of NAIA's conditional prompt rules.
///
/// Supported actions: main/prefix/postfix+=, tag+=, tag=, and *tag=.
/// Unsupported actions are deliberately ignored, not misinterpreted.
class NaiaConditionalProcessor {
  const NaiaConditionalProcessor();

  bool matches(String condition, String prompt, {
    List<String> characterPrompts = const [],
    List<bool> characterEnabled = const [],
  }) => _matches(condition, _splitTags(prompt),
      characterPrompts: characterPrompts,
      characterEnabled: characterEnabled);

  String apply(String prompt, String rules, {
    List<String> characterPrompts = const [],
    List<bool> characterEnabled = const [],
  }) {
    var tags = _splitTags(prompt);
    for (final line in rules.split(RegExp(r'\r?\n'))) {
      final rule = line.trim();
      if (rule.isEmpty || rule.startsWith('#')) {
        continue;
      }
      if (!rule.startsWith('(')) {
        continue;
      }
      final closing = _matchingParen(rule, 0);
      if (closing < 0 || closing + 1 >= rule.length ||
          rule[closing + 1] != ':') {
        continue;
      }
      final condition = rule.substring(1, closing);
      if (!_matches(condition, tags,
          characterPrompts: characterPrompts,
          characterEnabled: characterEnabled)) {
        continue;
      }
      final action = rule.substring(closing + 2).trim();
      final append = RegExp(r'^(.+?)(\+=|\+:)(.*)).firstMatch(action);
      if (append != null) {
        final target = append.group(1)!.trim();
        final values = _splitTags(append.group(3)!);
        if (target == 'prefix') {
          tags = [...values, ...tags];
        } else if (target == 'main' || target == 'postfix') {
          tags = [...tags, ...values];
        } else if (append.group(2) == '+:') {
          // NAIA's +: on an unrecognized target appends the entire
          // action (minus the first +:) to main, not after a matching tag.
          tags.addAll(_splitTags(action.replaceFirst('+:', '')));
        } else {
          final index = tags.indexWhere((tag) => _tagMatches(tag, target));
          if (index >= 0) tags.insertAll(index + 1, values);
        }
        continue;
      }
      final replace = RegExp(r'^(.+?)=(.*)$').firstMatch(action);
      if (replace == null) continue;
      final target = replace.group(1)!.trim();
      if (const {'prefix', 'main', 'postfix', 'neg', 'global_uc'}.contains(target)) {
        continue; // These have different semantics in NAIA.
      }
      final values = _splitTags(replace.group(2)!);
      final next = <String>[];
      for (final tag in tags) {
        if (_tagMatches(tag, target)) {
          next.addAll(values);
        } else {
          next.add(tag);
        }
      }
      tags = next;
    }
    return tags.join(', ');
  }

  static String _stripWeight(String value) {
    final trimmed = value.trim();
    final match = RegExp(r'^[-+]?\d+(?:\.\d+)?::(.*?)\s*::$').firstMatch(trimmed);
    return match == null ? trimmed : match.group(1)!.trim();
  }

  bool _tagMatches(String tag, String target) {
    final partial = target.startsWith('*');
    final needle = _stripWeight(partial ? target.substring(1) : target);
    final value = _stripWeight(tag);
    return partial ? needle.isNotEmpty && value.contains(needle) : value == needle;
  }

  // Match NAIA's precedence: parentheses, then AND, then OR.
  // Character predicates use expanded character prompt values supplied by caller.
  bool _matches(String condition, List<String> tags,
      {List<String> characterPrompts = const [],
       List<bool> characterEnabled = const []}) {
    bool evaluate(String expression) {
      var value = expression.trim();
      if (value.isEmpty || RegExp(r'(^|[(&|])\s*[&|]|[&|]\s*([)&|]|$)').hasMatch(value)) {
        return false;
      }
      while (value.startsWith('(') && value.endsWith(')') &&
          _matchingParen(value, 0) == value.length - 1) {
        value = value.substring(1, value.length - 1).trim();
      }
      final ors = _splitTopLevel(value, '|');
      if (ors.length > 1) return ors.any(evaluate);
      final ands = _splitTopLevel(value, '&');
      if (ands.length > 1) return ands.every(evaluate);

      final on = RegExp(r'^(~?)char_on\s*\(\s*(\d+)\s*\)$',
          caseSensitive: false).firstMatch(value);
      if (on != null) {
        final index = int.parse(on.group(2)!) - 1;
        final active = index >= 0 && index < characterEnabled.length &&
            characterEnabled[index];
        return on.group(1) == '~' ? !active : active;
      }
      final inside = RegExp(r'^(~?)char_in\s*\(\s*(\d+)\s*,\s*(.*?)\s*\)$',
          caseSensitive: false).firstMatch(value);
      if (inside != null) {
        final index = int.parse(inside.group(2)!) - 1;
        final found = index >= 0 && index < characterPrompts.length &&
            _splitTags(characterPrompts[index])
                .any((tag) => _tagMatches(tag, inside.group(3)!));
        return inside.group(1) == '~' ? !found : found;
      }
      var term = value;
      var negate = false;
      if (term.startsWith('~!')) {
        negate = true;
        term = term.substring(2);
      } else if (term.startsWith('~')) {
        negate = true;
        term = term.substring(1);
      }
      final found = tags.any((tag) => _tagMatches(tag, term.trim()));
      return negate ? !found : found;
    }
    return evaluate(condition);
  }

  static int _matchingParen(String text, int start) {
    var depth = 0;
    for (var i = start; i < text.length; i++) {
      if (text[i] == '(') depth++;
      if (text[i] == ')') {
        depth--;
        if (depth == 0) return i;
      }
    }
    return -1;
  }

  static List<String> _splitTopLevel(String value, String separator) {
    final parts = <String>[];
    var depth = 0;
    var begin = 0;
    for (var i = 0; i < value.length; i++) {
      if (value[i] == '(') depth++;
      if (value[i] == ')') depth--;
      if (value[i] == separator && depth == 0) {
        parts.add(value.substring(begin, i).trim());
        begin = i + 1;
      }
    }
    if (parts.isEmpty) return [value];
    parts.add(value.substring(begin).trim());
    return parts;
  }

  List<String> _splitTags(String text) {
    final result = <String>[];
    final buffer = StringBuffer();
    var depth = 0;
    for (final char in text.split('')) {
      if (char == '<') depth++;
      if (char == '>' && depth > 0) depth--;
      if (char == ',' && depth == 0) {
        final tag = buffer.toString().trim();
        if (tag.isNotEmpty) result.add(tag);
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }
    final last = buffer.toString().trim();
    if (last.isNotEmpty) result.add(last);
    return result;
  }
}
).firstMatch(action);
      if (append != null) {
        final target = append.group(1)!.trim();
        final values = _splitTags(append.group(2)!);
        if (target == 'prefix') {
          tags = [...values, ...tags];
        } else if (target == 'main' || target == 'postfix') {
          tags = [...tags, ...values];
        } else if (action.contains('+:')) {
          // NAIA's +: on an unrecognized target appends the entire
          // action (minus the first +:) to main, not after a matching tag.
          tags.addAll(_splitTags(action.replaceFirst('+:', '')));
        } else {
          final index = tags.indexWhere((tag) => _tagMatches(tag, target));
          if (index >= 0) tags.insertAll(index + 1, values);
        }
        continue;
      }
      final replace = RegExp(r'^(.+?)=(.*)$').firstMatch(action);
      if (replace == null) continue;
      final target = replace.group(1)!.trim();
      if (const {'prefix', 'main', 'postfix', 'neg', 'global_uc'}.contains(target)) {
        continue; // These have different semantics in NAIA.
      }
      final values = _splitTags(replace.group(2)!);
      final next = <String>[];
      for (final tag in tags) {
        if (_tagMatches(tag, target)) {
          next.addAll(values);
        } else {
          next.add(tag);
        }
      }
      tags = next;
    }
    return tags.join(', ');
  }

  static String _stripWeight(String value) {
    final trimmed = value.trim();
    final match = RegExp(r'^[-+]?\d+(?:\.\d+)?::(.*?)\s*::$').firstMatch(trimmed);
    return match == null ? trimmed : match.group(1)!.trim();
  }

  bool _tagMatches(String tag, String target) {
    final partial = target.startsWith('*');
    final needle = _stripWeight(partial ? target.substring(1) : target);
    final value = _stripWeight(tag);
    return partial ? needle.isNotEmpty && value.contains(needle) : value == needle;
  }

  // Match NAIA's precedence: parentheses, then AND, then OR.
  // Character predicates use expanded character prompt values supplied by caller.
  bool _matches(String condition, List<String> tags,
      {List<String> characterPrompts = const [],
       List<bool> characterEnabled = const []}) {
    bool evaluate(String expression) {
      var value = expression.trim();
      if (value.isEmpty || RegExp(r'(^|[(&|])\s*[&|]|[&|]\s*([)&|]|$)').hasMatch(value)) {
        return false;
      }
      while (value.startsWith('(') && value.endsWith(')') &&
          _matchingParen(value, 0) == value.length - 1) {
        value = value.substring(1, value.length - 1).trim();
      }
      final ors = _splitTopLevel(value, '|');
      if (ors.length > 1) return ors.any(evaluate);
      final ands = _splitTopLevel(value, '&');
      if (ands.length > 1) return ands.every(evaluate);

      final on = RegExp(r'^(~?)char_on\s*\(\s*(\d+)\s*\)$',
          caseSensitive: false).firstMatch(value);
      if (on != null) {
        final index = int.parse(on.group(2)!) - 1;
        final active = index >= 0 && index < characterEnabled.length &&
            characterEnabled[index];
        return on.group(1) == '~' ? !active : active;
      }
      final inside = RegExp(r'^(~?)char_in\s*\(\s*(\d+)\s*,\s*(.*?)\s*\)$',
          caseSensitive: false).firstMatch(value);
      if (inside != null) {
        final index = int.parse(inside.group(2)!) - 1;
        final found = index >= 0 && index < characterPrompts.length &&
            _splitTags(characterPrompts[index])
                .any((tag) => _tagMatches(tag, inside.group(3)!));
        return inside.group(1) == '~' ? !found : found;
      }
      var term = value;
      var negate = false;
      if (term.startsWith('~!')) {
        negate = true;
        term = term.substring(2);
      } else if (term.startsWith('~')) {
        negate = true;
        term = term.substring(1);
      }
      final found = tags.any((tag) => _tagMatches(tag, term.trim()));
      return negate ? !found : found;
    }
    return evaluate(condition);
  }

  static int _matchingParen(String text, int start) {
    var depth = 0;
    for (var i = start; i < text.length; i++) {
      if (text[i] == '(') depth++;
      if (text[i] == ')') {
        depth--;
        if (depth == 0) return i;
      }
    }
    return -1;
  }

  static List<String> _splitTopLevel(String value, String separator) {
    final parts = <String>[];
    var depth = 0;
    var begin = 0;
    for (var i = 0; i < value.length; i++) {
      if (value[i] == '(') depth++;
      if (value[i] == ')') depth--;
      if (value[i] == separator && depth == 0) {
        parts.add(value.substring(begin, i).trim());
        begin = i + 1;
      }
    }
    if (parts.isEmpty) return [value];
    parts.add(value.substring(begin).trim());
    return parts;
  }

  List<String> _splitTags(String text) {
    final result = <String>[];
    final buffer = StringBuffer();
    var depth = 0;
    for (final char in text.split('')) {
      if (char == '<') depth++;
      if (char == '>' && depth > 0) depth--;
      if (char == ',' && depth == 0) {
        final tag = buffer.toString().trim();
        if (tag.isNotEmpty) result.add(tag);
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }
    final last = buffer.toString().trim();
    if (last.isNotEmpty) result.add(last);
    return result;
  }
}
