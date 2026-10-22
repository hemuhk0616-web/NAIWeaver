import 'package:flutter_test/flutter_test.dart';
import 'package:naiweaver/core/services/naia_rule_validator.dart';

void main() {
  const validator = NaiaRuleValidator();

  test('valid basic and character scoped rules', () {
    final result = validator.validate('(solo):main+=smile\nchar:1 (blue hair):main+=happy\n(blue hair):uc:1+=bad');
    expect(result, isEmpty);
  });

  test('reports unsupported global UC as warning', () {
    final result = validator.validate('(solo):global_uc+=bad');
    expect(result.any((d) => d.warning && d.message.contains('global_uc')), isTrue);
  });

  test('reports malformed character target', () {
    final result = validator.validate('(solo):char:0+=blue');
    expect(result.any((d) => d.warning), isTrue);
  });

  test('reports unknown function and syntax errors', () {
    final result = validator.validate('(solo):unknown_fn(foo)\nsolo:main+=x');
    expect(result.any((d) => d.line == 1 && d.warning), isTrue);
    expect(result.any((d) => d.line == 2 && !d.warning), isTrue);
  });
}
