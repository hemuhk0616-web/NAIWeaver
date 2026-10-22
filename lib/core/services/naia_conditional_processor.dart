/// A deterministic, pure-Dart prompt-rule pass for NAIA-style conditional rules.
/// The full NAIA grammar is implemented incrementally; unsupported expressions
/// remain untouched rather than silently changing generation semantics.
class NaiaConditionalProcessor {
  const NaiaConditionalProcessor();

  String apply(String prompt, String rules) {
    var tags = _split(prompt);
    for (final line in rules.split(RegExp(r'\r?\n'))) {
      final rule = line.trim();
      if (rule.isEmpty || rule.startsWith('#')) continue;
      final match = RegExp(r'^\((.+)\):(.+)
          .firstMatch(rule);
      if (match == null) continue;
      final condition = match.group(1)!.trim();
      if (!_matches(condition, tags)) continue;
      final action = match.group(2)!.trim();
      final append = RegExp(r'^([^=]+)\\+=(.*)$').firstMatch(action);
      if (append != null) {
        final target = append.group(1)!.trim();
        final values = _split(append.group(2)!);
        if (values.isEmpty) continue;
        if (target == 'prefix') {
          tags = [...values, ...tags];
        } else if (target == 'main' || target == 'postfix') {
          tags = [...tags, ...values];
        } else {
          final index = tags.indexWhere((tag) => _tagMatches(tag, target));
          if (index >= 0) tags.insertAll(index + 1, values);
        }
        continue;
      }
      final replace = RegExp(r'^([^=]+)=(.*)$').firstMatch(action);
      if (replace == null) continue;
      final target = replace.group(1)!.trim();
      final values = _split(replace.group(2)!);
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

  bool _tagMatches(String tag, String target) {\n    final clean = (String value) => value.trim().replaceFirst(RegExp(r\'^[-+]?\\d+(?:\\.\\d+)?::(.*?)\\s*::$\'), r\'$1\');\n    final needle = clean(target.startsWith(\'*\') ? target.substring(1) : target);\n    final value = clean(tag);\n    return target.startsWith(\'*\') ? needle.isNotEmpty && value.contains(needle) : value == needle;\n  }\n\n  bool _matches(String condition, List<String> tags) {
    final orParts = condition.split('|');
    return orParts.any((orPart) => orPart.split('&').every((term) {
      var token = term.trim();
      var negate = false;
      if (token.startsWith('~!')) {
        negate = true;
        token = token.substring(2);
      } else if (token.startsWith('~')) {
        negate = true;
        token = token.substring(1);
      }
      if (token.startsWith('*')) token = token.substring(1);
      if (token.isEmpty) return false;
      final matched = tags.any((tag) => tag.toLowerCase().contains(token.toLowerCase()));
      return negate ? !matched : matched;
    }));
  }

  List<String> _split(String input) =>
      input.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
}
)
          .firstMatch(rule);
      if (match == null) continue;
      final condition = match.group(1)!.trim();
      if (!_matches(condition, tags)) continue;
      final values = _split(match.group(4)!);
      if (values.isEmpty) continue;
      final location = match.group(2)!;
      final append = match.group(3) == '+=';
      if (location == 'prefix') {
        tags = append ? [...values, ...tags] : [...values, ...tags];
      } else {
        tags = append ? [...tags, ...values] : [...tags, ...values];
      }
    }
    return tags.join(', ');
  }

  bool _matches(String condition, List<String> tags) {
    final orParts = condition.split('|');
    return orParts.any((orPart) => orPart.split('&').every((term) {
      var token = term.trim();
      var negate = false;
      if (token.startsWith('~!')) {
        negate = true;
        token = token.substring(2);
      } else if (token.startsWith('~')) {
        negate = true;
        token = token.substring(1);
      }
      if (token.startsWith('*')) token = token.substring(1);
      if (token.isEmpty) return false;
      final matched = tags.any((tag) => tag.toLowerCase().contains(token.toLowerCase()));
      return negate ? !matched : matched;
    }));
  }

  List<String> _split(String input) =>
      input.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
}
