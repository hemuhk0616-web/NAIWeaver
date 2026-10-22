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
      final set = RegExp(
        r'^\s*\((.*?)\):char_set\(\s*(\d+)\s*,\s*(enabled|disabled)\s*\)\s*$',
        caseSensitive: false,
      ).firstMatch(line);
      final replace = RegExp(
        r'^\s*\((.*?)\):char_replace\(\s*(\d+)\s*,\s*(.*?)\s*,\s*(.*?)\s*\)\s*$',
      ).firstMatch(line);
      final rule = set ?? replace;
      if (rule == null || !matches(rule.group(1)!, current, enabled)) continue;
      final index = int.parse(rule.group(2)!) - 1;
      if (index < 0 || index >= current.length) continue;
      if (set != null) {
        enabled[index] = set.group(3)!.toLowerCase() == 'enabled';
      } else {
        final oldTag = _stripWeight(replace!.group(3)!);
        final newTag = replace.group(4)!.trim();
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
