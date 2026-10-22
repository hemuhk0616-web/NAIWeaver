/// Lightweight syntax diagnostics. This checks structure, not rule semantics.
class NaiaRuleDiagnostic {
  final int line;
  final String message;
  final bool warning;
  const NaiaRuleDiagnostic(this.line, this.message, {this.warning = false});
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
      // These forms parse but the current engine does not execute them.
      if (RegExp(r'^global_uc\s*(?:\+=|\+:|=)').hasMatch(action)) {
        issues.add(NaiaRuleDiagnostic(i + 1,
            'global_uc 동작은 현재 처리되지 않습니다.', warning: true));
      }
      final scoped = RegExp(r'^(?:char|uc):(\d+)\s*(?:\+=|\+:|=)').firstMatch(action);
      if (scoped != null && int.tryParse(scoped.group(1)!) == 0) {
        issues.add(NaiaRuleDiagnostic(i + 1,
            '캐릭터 번호는 1부터 시작합니다.', warning: true));
      }
      if (scope != null && action.startsWith('char_')) {
        issues.add(NaiaRuleDiagnostic(i + 1,
            'char:N 범위와 char_set/char_replace 조합은 적용 결과를 확인하세요.', warning: true));
      }
      final functionName = RegExp(r'^([a-zA-Z_][a-zA-Z_0-9]*)\s*\(').firstMatch(action);
      if (functionName != null &&
          !const {'char_set', 'char_replace'}.contains(functionName.group(1))) {
        issues.add(NaiaRuleDiagnostic(i + 1,
            '알 수 없는 함수 동작입니다: ${functionName.group(1)}', warning: true));
      }
      final assignment = RegExp(r'^(.+?)(\+=|\+:|=)(.*)
        issues.add(NaiaRuleDiagnostic(i + 1, '동작이 비어 있습니다.'));
      } else if (!RegExp(r'^.+?(?:\+=|\+:|=).*$').hasMatch(action) &&
          !RegExp(r'^char_(?:set|replace)\(').hasMatch(action)) {
        issues.add(NaiaRuleDiagnostic(i + 1, '지원되는 동작 형식이 아닙니다 (=, +=, +:, char_set, char_replace).'));
      }
    }
    return issues;
  }
}
).firstMatch(action);
      if (assignment != null) {
        final target = assignment.group(1)!.trim();
        if (target.isEmpty) {
          issues.add(NaiaRuleDiagnostic(i + 1, '동작 대상이 비어 있습니다.'));
        } else if (target.startsWith('char:') || target.startsWith('uc:')) {
          if (!RegExp(r'^(char|uc):(\*|[1-9]\d*)
        issues.add(NaiaRuleDiagnostic(i + 1, '동작이 비어 있습니다.'));
      } else if (!RegExp(r'^.+?(?:\+=|\+:|=).*$').hasMatch(action) &&
          !RegExp(r'^char_(?:set|replace)\(').hasMatch(action)) {
        issues.add(NaiaRuleDiagnostic(i + 1, '지원되는 동작 형식이 아닙니다 (=, +=, +:, char_set, char_replace).'));
      }
    }
    return issues;
  }
}
).hasMatch(target)) {
            issues.add(NaiaRuleDiagnostic(i + 1,
                '캐릭터 대상은 char:1, uc:1 또는 char:*, uc:* 형식이어야 합니다.',
                warning: true));
          }
        } else if (target == 'global_uc') {
          // Unsupported target is reported separately above.
        } else if (target.contains(':') &&
            !const {'prefix', 'main', 'postfix', 'neg'}.contains(target)) {
          issues.add(NaiaRuleDiagnostic(i + 1,
              '이 대상은 현재 엔진에서 의도대로 처리되지 않을 수 있습니다: $target',
              warning: true));
        }
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
