/// Applies NAIA's character actions to already-expanded character prompts.
/// Indexes are 1-based, as in NAIA. No new wildcard rolls occur here.
class NaiaCharacterActions {
  const NaiaCharacterActions();

  List<String> applyReplace(List<String> prompts, String rules,
      {required bool Function(String, List<String>) matches}) {
    final output = List<String>.from(prompts);
    final mainTags = <String>[];
    for (final line in rules.split(RegExp(r'\r?\n'))) {
      final rule = RegExp(r'^\s*\((.*?)\):char_replace\(\s*(\d+)\s*,\s*(.*?)\s*,\s*(.*?)\s*\)\s*$')
          .firstMatch(line);
      if (rule == null || !matches(rule.group(1)!, mainTags)) continue;
      final index = int.parse(rule.group(2)!) - 1;
      if (index < 0 || index >= output.length) continue;
      final oldTag = rule.group(3)!.trim();
      final newTag = rule.group(4)!.trim();
      final tags = output[index].split(',').map((s) => s.trim()).toList();
      for (var i = 0; i < tags.length; i++) {
        if (_stripWeight(tags[i]) == _stripWeight(oldTag)) {
          tags[i] = newTag;
        }
      }
      output[index] = tags.join(', ');
    }
    return output;
  }

  static String _stripWeight(String text) {
    final match = RegExp(r'^[-+]?\d+(?:\.\d+)?::(.*?)\s*::$').firstMatch(text);
    return match == null ? text.trim() : match.group(1)!.trim();
  }
}
