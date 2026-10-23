import 'dart:math';

import 'naia_conditional_processor.dart';
import 'naia_ordered_rule_engine.dart';
import 'wildcard_processor.dart';

/// Expands wildcards, then evaluates the supported NAIA conditional rules.
class NaiaPromptPipeline {
  NaiaPromptPipeline(this.wildcards);

  final WildcardProcessor wildcards;
  final Random _random = Random();
  final NaiaConditionalProcessor conditions = const NaiaConditionalProcessor();

  Future<String> process(String prompt, {
    String rules = '',
    List<String> characterPrompts = const [],
    List<bool> characterEnabled = const [],
  }) async {
    final expanded = await wildcards.process(prompt);
    if (rules.trim().isEmpty) return expanded;
    final result = await const NaiaOrderedRuleEngine().applyAsync(
      expanded, characterPrompts, rules,
      characterEnabled: characterEnabled,
      expandAction: expandMatchedActionValue,
    );
    return result.main;
  }

  /// Expand only assigned action values. Conditions and function arguments
  /// must remain intact so a wildcard cannot silently rewrite rule syntax.
  // NAIA action alternatives are selected independently for each comma tag.
  // Resolve after wildcard expansion so nested wildcard results can contain ^.
  String _chooseAlternatives(String value) {
    return value.split(',').map((part) {
      final choices = part.split('^');
      if (choices.length == 1) return part.trim();
      final valid = choices.map((item) => item.trim())
          .where((item) => item.isNotEmpty).toList();
      if (valid.isEmpty) return part;
      return valid[_random.nextInt(valid.length)];
    }).join(', ');
  }

  /// Expand only a matched action; unmatched rules must not consume rolls.
  Future<String> expandMatchedActionValue(String value) async =>
      _chooseAlternatives(await wildcards.process(value));

  Future<String> expandActionValues(String rules) async {
    final output = <String>[];
    for (final line in rules.split(RegExp(r'\r?\n'))) {
      final trimmed = line.trimLeft();
      if (!trimmed.startsWith('(')) {
        output.add(line);
        continue;
      }
      var depth = 0;
      var closing = -1;
      for (var i = 0; i < trimmed.length; i++) {
        if (trimmed[i] == '(') depth++;
        if (trimmed[i] == ')') {
          depth--;
          if (depth == 0) {
            closing = i;
            break;
          }
        }
      }
      if (closing < 0 || closing + 1 >= trimmed.length ||
          trimmed[closing + 1] != ':') {
        output.add(line);
        continue;
      }
      final actionStart = line.length - trimmed.length + closing + 2;
      final action = line.substring(actionStart);
      final assignment = RegExp(r'^\s*([^=]+?)(\+=|\+:|=)(.*)$')
          .firstMatch(action);
      if (assignment == null ||
          assignment.group(1)!.trim().startsWith('char_')) {
        output.add(line);
        continue;
      }
      final valueStart = actionStart + assignment.start +
          assignment.group(0)!.length - assignment.group(3)!.length;
      final expandedValue = await wildcards.process(line.substring(valueStart));
      final value = _chooseAlternatives(expandedValue);
      output.add('${line.substring(0, valueStart)}$value');
    }
    return output.join('\n');
  }
}
