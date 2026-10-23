import 'package:flutter_test/flutter_test.dart';
import 'package:naiweaver/core/services/naia_update7_preset.dart';
import 'package:naiweaver/core/services/naia_rule_validator.dart';

void main() {
  test('update7 manifest covers all wildcard references', () {
    final source = '${NaiaUpdate7Preset.leadingPrompt}\n${NaiaUpdate7Preset.rules}';
    final references = RegExp(r'__([^\r\n]+?)__')
        .allMatches(source).map((m) => m.group(1)!).toSet();
    expect(NaiaUpdate7Preset.requiredWildcards.toSet().containsAll(references), isTrue);
  });

  test('update7 rules have no static syntax errors', () {
    final errors = const NaiaRuleValidator()
        .validate(NaiaUpdate7Preset.rules)
        .where((issue) => !issue.warning).toList();
    expect(errors, isEmpty);
  });
}
