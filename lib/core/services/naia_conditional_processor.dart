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
      final match = RegExp(r'^\((.+)\):(prefix|postfix)(\+=|=)(.*)$')
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
