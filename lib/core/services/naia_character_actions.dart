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
      final parsed = _parseRule(line);
      if (parsed == null ||
          !matches(parsed.condition, current, enabled)) continue;
      final index = parsed.index - 1;
      if (index < 0 || index >= current.length) continue;
      if (parsed.action == 'char_set') {
        enabled[index] = parsed.arguments[1].toLowerCase() == 'enabled';
      } else {
        final oldTag = _stripWeight(parsed.arguments[1]);
        final newTag = parsed.arguments[2];
        current[index] = current[index].split(',').map((tag) {
          return _stripWeight(tag) == oldTag ? newTag : tag.trim();
        }).join(', ');
      }
    }
    return (prompts: current, enabled: enabled);
  }

  static ({String condition, String action, int index, List<String> arguments})?
      _parseRule(String line) {
    final text = line.trim();
    if (!text.startsWith('(')) return null;
    var depth = 0;
    var end = -1;
    for (var i = 0; i < text.length; i++) {
      if (text[i] == '(') depth++;
      if (text[i] == ')') {
        depth--;
        if (depth == 0) { end = i; break; }
      }
    }
    if (end < 0 || end + 1 >= text.length || text[end + 1] != ':') {
      return null;
    }
    final actionText = text.substring(end + 2).trim();
    final action = RegExp(r'^(char_set|char_replace)\((.*)\)$',
        caseSensitive: false).firstMatch(actionText);
    if (action == null) return null;
    final args = action.group(2)!.split(',').map((s) => s.trim()).toList();
    final kind = action.group(1)!.toLowerCase();
    if (args.length != (kind == 'char_set' ? 2 : 3)) return null;
    final index = int.tryParse(args[0]);
    if (index == null || index < 1) return null;
    if (kind == 'char_set' &&
        !const {'enabled', 'disabled'}.contains(args[1].toLowerCase())) {
      return null;
    }
    return (condition: text.substring(1, end), action: kind,
        index: index, arguments: args);
  }

  static String _stripWeight(String text) {
    final value = text.trim();
    final match = RegExp(r'^[-+]?\d+(?:\.\d+)?::(.*?)\s*::$').firstMatch(value);
    return match == null ? value : match.group(1)!.trim();
  }
}
