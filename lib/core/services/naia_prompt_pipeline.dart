import 'naia_conditional_processor.dart';
import 'wildcard_processor.dart';

/// One generation-pass coordinator. A wildcard is rolled only once in the
/// original prompt; newly injected conditional tags are expanded separately.
class NaiaPromptPipeline {
  NaiaPromptPipeline(this.wildcards);

  final WildcardProcessor wildcards;
  final NaiaConditionalProcessor conditions = const NaiaConditionalProcessor();

  Future<String> process(String prompt, {String rules = ''}) async {
    final expanded = await wildcards.process(prompt);
    if (rules.trim().isEmpty) return expanded;
    // Preserve already-rolled wildcard values: do not run the processor again
    // over the complete result. Instead expand rule-authored wildcard tokens
    // before the conditional pass. Conditions still inspect expanded prompt.
    final expandedRules = await _expandActionValues(rules);
    return conditions.apply(expanded, expandedRules);
  }

  Future<String> _expandActionValues(String rules) async {
    final output = <String>[];
    for (final line in rules.split(RegExp(r'\r?\n'))) {
      final match = RegExp(r'^(\(.*\):.*?(?:\+=|=))(.*)$').firstMatch(line);
      if (match == null) {
        output.add(line);
      } else {
        final value = await wildcards.process(match.group(2)!);
        output.add('${match.group(1)}$value');
      }
    }
    return output.join('\n');
  }
}
