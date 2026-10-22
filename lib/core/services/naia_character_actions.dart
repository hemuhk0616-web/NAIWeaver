/// Applies character operations to expanded prompts without mutating saved slots.
class NaiaCharacterActions {
  const NaiaCharacterActions();

  /// NAIA uses 1-based character indexes. Conditions see preceding changes.
  ({List<String> prompts, List<bool> enabled}) apply(
    List<String> prompts,
    String rules, {
    required bool Function(String, List<String>, List<bool>) matches,
  }) {
    final current = List<String>.from(prompts);
    final enabled = List<bool>.filled(prompts.length, true);
    for (final line in rules.split(RegExp(r'\r?\n'))) {
      final trimmed = line.trim();
      if (!trimmed.startsWith('(')) continue;
      var depth = 0;
      var closing = -1;
      for (var i = 0; i < trimmed.length; i++) {
        if (trimmed[i] == '(') depth++;
        if (trimmed[i] == ')') {
          depth--;
          if (depth == 0) { closing = i; break; }
        }
      }
      if (closing < 0 || closing + 1 >= trimmed.length ||
          trimmed[closing + 1] != ':') continue;
      final condition = trimmed.substring(1, closing);
      final action = trimmed.substring(closing + 2).trim();
      final set = RegExp(
        r'^char_set\(\s*(\d+)\s*,\s*(enabled|disabled)\s*\)$',
        caseSensitive: false,
      ).firstMatch(action);
      final replace = RegExp(
        r'^char_replace\(\s*(\d+)\s*,\s*(.*?)\s*,\s*(.*?)\s*\)$',
      ).firstMatch(action);
      final rule = set ?? replace;
      if (rule == null || !matches(condition, current, enabled)) continue;
      final index = int.parse(rule.group(1)!) - 1;
      if (index < 0 || index >= current.length) continue;
      if (set != null) {
        enabled[index] = set.group(2)!.toLowerCase() == 'enabled';
      } else {
        final oldTag = _stripWeight(replace!.group(2)!);
        final newTag = replace.group(3)!.trim();
        current[index] = current[index].split(',').map((tag) {
          return _stripWeight(tag) == oldTag ? newTag : tag.trim();
        }).join(', ');
      }
    }
    return (prompts: current, enabled: enabled);
  }

  List<bool> applyEnabled(List<String> prompts, String rules, {
    required bool Function(String, List<String>, List<bool>) matches,
  }) => apply(prompts, rules, matches: matches).enabled;

  List<String> applyReplace(List<String> prompts, String rules, {
    required bool Function(String) matches,
  }) => apply(prompts, rules,
      matches: (condition, current, enabled) => matches(condition)).prompts;

  static String _stripWeight(String text) {
    final value = text.trim();
    final match = RegExp(r'^[-+]?\d+(?:\.\d+)?::(.*?)\s*::$').firstMatch(value);
    return match == null ? value : match.group(1)!.trim();
  }
}
