/// A pure Dart subset of NAIA's conditional prompt rules.
///
/// Supported actions: main/prefix/postfix+=, tag+=, tag=, and *tag=.
/// Unsupported actions are deliberately ignored, not misinterpreted.
class NaiaConditionalProcessor {
  const NaiaConditionalProcessor();

  String apply(String prompt, String rules) {
    var tags = _splitTags(prompt);
    for (final line in rules.split(RegExp(r'\r?\n'))) {
      final rule = line.trim();
      if (rule.isEmpty || rule.startsWith('#')) continue;
      final match = RegExp(r'^\((.+)\):(.+)$').firstMatch(rule);
      if (match == null || !_matches(match.group(1)!, tags)) continue;
      final action = match.group(2)!.trim();
      final append = RegExp(r'^(.+?)\+=(.*)$').firstMatch(action);
      if (append != null) {
        final target = append.group(1)!.trim();
        final values = _splitTags(append.group(2)!);
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

  bool _matches(String condition, List<String> tags) {
    return condition.split('|').any((orPart) => orPart.split('&').every((part) {
      var term = part.trim();
      var negative = false;
      if (term.startsWith('~!')) {
        negative = true;
        term = term.substring(2);
      } else if (term.startsWith('~')) {
        negative = true;
        term = term.substring(1);
      }
      if (term.isEmpty) return false;
      final found = tags.any((tag) => _tagMatches(tag, term));
      return negative ? !found : found;
    }));
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
