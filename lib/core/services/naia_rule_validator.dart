/// Structural validation and known unsupported-action diagnostics.
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
        issues.add(NaiaRuleDiagnostic(i + 1, '조건은 ( 로 시작해야 합니다.'));
        continue;
      }
      var depth = 0;
      var closing = -1;
      for (var j = 0; j < rule.length; j++) {
        if (rule[j] == '(') depth++;
        if (rule[j] == ')') {
          depth--;
          if (depth < 0) break;
          if (depth == 0) { closing = j; break; }
        }
      }
      if (closing < 0 || closing + 1 >= rule.length || rule[closing + 1] != ':') {
        issues.add(NaiaRuleDiagnostic(i + 1, '조건 뒤에는 ):동작 형식이 필요합니다.'));
        continue;
      }
      final condition = rule.substring(1, closing).trim();
      final action = rule.substring(closing + 2).trim();
      if (condition.isEmpty) issues.add(NaiaRuleDiagnostic(i + 1, '조건이 비어 있습니다.'));
      if (action.isEmpty) {
        issues.add(NaiaRuleDiagnostic(i + 1, '동작이 비어 있습니다.'));
        continue;
      }
      // Check the executable engine's supported action forms, not syntax alone.
      final supportedFunction = RegExp(r'^char_(set|replace)\\((.*)\\)\s*(?:\+=|\+:|=)').hasMatch(action)) {
        issues.add(NaiaRuleDiagnostic(i + 1, 'global_uc 동작은 현재 처리되지 않습니다.', warning: true));
      }
      final fn = RegExp(r'^([a-zA-Z_][a-zA-Z_0-9]*)\s*\(').firstMatch(action);
      if (fn != null && !const {'char_set', 'char_replace'}.contains(fn.group(1))) {
        issues.add(NaiaRuleDiagnostic(i + 1, '알 수 없는 함수 동작: ${fn.group(1)}', warning: true));
      }
      final assignment = RegExp(r'^(.+?)(\+=|\+:|=)(.*)$').firstMatch(action);
      if (assignment == null && fn == null) {
        issues.add(NaiaRuleDiagnostic(i + 1, '지원되는 동작 형식이 아닙니다.'));
        continue;
      }
      if (fn != null && supportedFunction == null) {
        issues.add(NaiaRuleDiagnostic(i + 1,
            '현재 실행 엔진이 처리하지 않는 함수 호출입니다.', warning: true));
      }
      if (assignment != null) {
        final target = assignment.group(1)!.trim();
        final op = assignment.group(2)!;
        if (target == 'global_uc') {
          // The ordered engine explicitly skips global_uc.
        } else if (target == 'neg' && op == '+=') {
          // Supported.
        } else if (const {'prefix', 'main', 'postfix'}.contains(target) && op == '=') {
          issues.add(NaiaRuleDiagnostic(i + 1,
              '$target=은 영역 전체 대입이 아니라 동일 이름의 태그 치환으로 처리됩니다.', warning: true));
        } else if (target == 'neg' && op == '+:') {
          issues.add(NaiaRuleDiagnostic(i + 1,
              'neg+:는 위치 지정 삽입이 아니라 UC 끝에 추가됩니다.', warning: true));
        } else if (target == 'neg' && op == '=') {
          // Supported.
        } else if (target.startsWith('char:') || target.startsWith('uc:')) {
          if (op == '+:') {
            issues.add(NaiaRuleDiagnostic(i + 1,
                '캐릭터/UC의 +:는 위치 지정이 아니라 끝에 추가됩니다.', warning: true));
          }
        } else if (target.isNotEmpty && op == '+:' &&
            !const {'prefix', 'main', 'postfix'}.contains(target)) {
          issues.add(NaiaRuleDiagnostic(i + 1,
              '이 +: 동작은 대상 태그 뒤가 아닌 Main 끝에 추가됩니다.', warning: true));
        }
        if (target.isEmpty) issues.add(NaiaRuleDiagnostic(i + 1, '동작 대상이 비어 있습니다.'));
        if ((target.startsWith('char:') || target.startsWith('uc:')) &&
            !RegExp(r'^(char|uc):(\*|[1-9]\d*)$').hasMatch(target)) {
          issues.add(NaiaRuleDiagnostic(i + 1, '캐릭터 대상은 char:1, uc:1 또는 char:*, uc:* 형식이어야 합니다.', warning: true));
        }
        if (target.contains(':') && !target.startsWith('char:') && !target.startsWith('uc:') && target != 'global_uc') {
          issues.add(NaiaRuleDiagnostic(i + 1, '대상 해석을 확인하세요: $target', warning: true));
        }
      }
      if (scope != null && action.startsWith('char_')) {
        issues.add(NaiaRuleDiagnostic(i + 1, 'char:N 범위와 캐릭터 함수 조합은 적용 결과를 확인하세요.', warning: true));
      }
    }
    return issues;
  }
}
, caseSensitive: false).firstMatch(action);
      if (supportedFunction != null) {
        final kind = supportedFunction.group(1)!.toLowerCase();
        final args = supportedFunction.group(2)!.split(',').map((e) => e.trim()).toList();
        final valid = args.length == (kind == 'set' ? 2 : 3) &&
            (int.tryParse(args.first) ?? 0) > 0 &&
            (kind != 'set' || const {'enabled', 'disabled'}.contains(args[1].toLowerCase()));
        if (!valid) {
          issues.add(NaiaRuleDiagnostic(i + 1,
              '캐릭터 함수의 인자 형식이 잘못되어 실행 시 무시됩니다.', warning: true));
        }
      }
      if (RegExp(r'^global_uc\s*(?:\+=|\+:|=)').hasMatch(action)) {
        issues.add(NaiaRuleDiagnostic(i + 1, 'global_uc 동작은 현재 처리되지 않습니다.', warning: true));
      }
      final fn = RegExp(r'^([a-zA-Z_][a-zA-Z_0-9]*)\s*\(').firstMatch(action);
      if (fn != null && !const {'char_set', 'char_replace'}.contains(fn.group(1))) {
        issues.add(NaiaRuleDiagnostic(i + 1, '알 수 없는 함수 동작: ${fn.group(1)}', warning: true));
      }
      final assignment = RegExp(r'^(.+?)(\+=|\+:|=)(.*)$').firstMatch(action);
      if (assignment == null && fn == null) {
        issues.add(NaiaRuleDiagnostic(i + 1, '지원되는 동작 형식이 아닙니다.'));
        continue;
      }
      if (assignment != null) {
        final target = assignment.group(1)!.trim();
        if (target.isEmpty) issues.add(NaiaRuleDiagnostic(i + 1, '동작 대상이 비어 있습니다.'));
        if ((target.startsWith('char:') || target.startsWith('uc:')) &&
            !RegExp(r'^(char|uc):(\*|[1-9]\d*)$').hasMatch(target)) {
          issues.add(NaiaRuleDiagnostic(i + 1, '캐릭터 대상은 char:1, uc:1 또는 char:*, uc:* 형식이어야 합니다.', warning: true));
        }
        if (target.contains(':') && !target.startsWith('char:') && !target.startsWith('uc:') && target != 'global_uc') {
          issues.add(NaiaRuleDiagnostic(i + 1, '대상 해석을 확인하세요: $target', warning: true));
        }
      }
      if (scope != null && action.startsWith('char_')) {
        issues.add(NaiaRuleDiagnostic(i + 1, 'char:N 범위와 캐릭터 함수 조합은 적용 결과를 확인하세요.', warning: true));
      }
    }
    return issues;
  }
}
