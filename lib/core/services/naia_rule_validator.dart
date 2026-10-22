/// Lightweight syntax diagnostics. This checks structure, not rule semantics.
class NaiaRuleDiagnostic {
  final int line;
  final String message;
  const NaiaRuleDiagnostic(this.line, this.message);
}

class NaiaRuleValidator {
  const NaiaRuleValidator();

  List<NaiaRuleDiagnostic> validate(String source) {
    final issues = <NaiaRuleDiagnostic>[];
    final lines = source.split(RegExp(r'\r?\n'));
    for (var i = 0; i < lines.length; i++) {
      var rule = lines[i].trim();
      if (rule.isEmpty || rule.startsWith('#')) continue;
      final scope = RegExp(r'^char:\d+\s+').firstMatch(rule);
      if (scope != null) rule = rule.substring(scope.end).trimLeft();
      if (!rule.startsWith('(')) {
        issues.add(NaiaRuleDiagnostic(i + 1, '조건은 여는 괄호 ( 로 시작해야 합니다.'));
        continue;
      }
      var depth = 0;
      var closing = -1;
      for (var j = 0; j < rule.length; j++) {
        if (rule[j] == '(') depth++;
        if (rule[j] == ')') {
          depth--;
          if (depth < 0) break;
          if (depth == 0) {
            closing = j;
            break;
          }
        }
      }
      if (closing < 0 || closing + 1 >= rule.length ||
          rule[closing + 1] != ':') {
        issues.add(NaiaRuleDiagnostic(i + 1, '조건 괄호 뒤에 ):동작 형식이 필요합니다.'));
        continue;
      }
      final condition = rule.substring(1, closing).trim();
      final action = rule.substring(closing + 2).trim();
      if (condition.isEmpty) {
        issues.add(NaiaRuleDiagnostic(i + 1, '조건이 비어 있습니다.'));
      }
      if (action.isEmpty) {
        issues.add(NaiaRuleDiagnostic(i + 1, '동작이 비어 있습니다.'));
      } else if (!RegExp(r'^.+?(?:\+=|\+:|=).*$').hasMatch(action) &&
          !RegExp(r'^char_(?:set|replace)\(').hasMatch(action)) {
        issues.add(NaiaRuleDiagnostic(i + 1, '지원되는 동작 형식이 아닙니다 (=, +=, +:, char_set, char_replace).'));
      }
    }
    return issues;
  }
}
