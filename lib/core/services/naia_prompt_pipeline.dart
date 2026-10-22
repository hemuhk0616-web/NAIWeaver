import 'naia_conditional_processor.dart';
import 'wildcard_processor.dart';

/// Expands wildcards, then evaluates the supported NAIA conditional rules.
class NaiaPromptPipeline {
  NaiaPromptPipeline(this.wildcards);

  final WildcardProcessor wildcards;
  final NaiaConditionalProcessor conditions = const NaiaConditionalProcessor();

  Future<String> process(String prompt, {
    String rules = '',
    List<String> characterPrompts = const [],
    List<bool> characterEnabled = const [],
  }) async {
    final expanded = await wildcards.process(prompt);
    if (rules.trim().isEmpty) return expanded;
    final expandedRules = await expandActionValues(rules);
    return conditions.apply(expanded, expandedRules,
      characterPrompts: characterPrompts,
      characterEnabled: characterEnabled);
  }

  Future<String> expandActionValues(String rules) async {
    final output = <String>[];
    for (final line in rules.split(RegExp(r'\r?\n'))) {
      final match = RegExp(r'^(\(.*\):.*?(?:\+=|\+:|(?<![+])=))(.*)$').firstMatch(line);
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
