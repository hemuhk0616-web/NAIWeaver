/// Static diagnostics for the subset implemented by NaiaOrderedRuleEngine.
/// A clean result does not guarantee that a condition matches at runtime.
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
      final original = lines[i].trim();
      if (original.isEmpty || original.startsWith('#')) continue;
      final line = i + 1;
      var rule = original;
      // The generation pipeline routes char:N rules to the corresponding
      // character prompt before the ordered main rules are evaluated.
      final scope = RegExp(r'^char:([1-9]\\d*)\\s+').firstMatch(rule);
      if (scope != null) {
        rule = rule.substring(scope.end).trimLeft();
      }
      if (!rule.startsWith('(')) {
        issues.add(NaiaRuleDiagnostic(line, '조건은 ( 로 시작해야 합니다.'));
        continue;
      }
      final end = _matchingParen(rule);
      if (end < 0 || end + 1 >= rule.length || rule[end + 1] != ':') {
        issues.add(NaiaRuleDiagnostic(line, '조건 뒤에는 ):동작 형식이 필요합니다.'));
        continue;
      }
      final condition = rule.substring(1, end).trim();
      final action = rule.substring(end + 2).trim();
      if (condition.isEmpty) {
        issues.add(NaiaRuleDiagnostic(line, '조건이 비어 있습니다.'));
      } else {
        _checkCondition(condition, line, issues);
      }
      if (action.isEmpty) {
        issues.add(NaiaRuleDiagnostic(line, '동작이 비어 있습니다.'));
        continue;
      }
      final fn = RegExp(r'^([a-zA-Z_]\w*)\s*\(').firstMatch(action);
      if (fn != null) {
        final function = fn.group(1)!.toLowerCase();
        final match = RegExp(r'^char_(set|replace)\((.*)\)$',
            caseSensitive: false).firstMatch(action);
        if (match == null) {
          issues.add(NaiaRuleDiagnostic(line,
              '지원되지 않거나 형식이 잘못된 함수 동작: ${fn.group(1)}',
              warning: true));
          continue;
        }
        final args = _splitArguments(match.group(2)!);
        final validCount = args.length == (function == 'char_set' ? 2 : 3);
        final validIndex = args.isNotEmpty && (int.tryParse(args.first) ?? 0) > 0;
        final validState = function != 'char_set' ||
            (args.length > 1 && const {'enabled', 'disabled'}
                .contains(args[1].toLowerCase()));
        if (!validCount || !validIndex || !validState) {
          issues.add(NaiaRuleDiagnostic(line,
              '캐릭터 함수 인자가 잘못되어 실행 시 무시됩니다.', warning: true));
        }
        continue;
      }
      final assignment = RegExp(r'^(.+?)(\+=|\+:|=)(.*)$').firstMatch(action);
      if (assignment == null) {
        issues.add(NaiaRuleDiagnostic(line, '지원되는 동작 형식이 아닙니다.'));
        continue;
      }
      final target = assignment.group(1)!.trim();
      final operator = assignment.group(2)!;
      if (target.isEmpty) {
        issues.add(NaiaRuleDiagnostic(line, '동작 대상이 비어 있습니다.'));
        continue;
      }
      if (target == 'global_uc') {
        issues.add(NaiaRuleDiagnostic(line,
            'global_uc는 현재 실행 엔진에서 무시됩니다.', warning: true));
      } else if (RegExp(r'^(char|uc):').hasMatch(target)) {
        if (!RegExp(r'^(char|uc):(\*|[1-9]\d*)$', caseSensitive: false)
            .hasMatch(target)) {
          issues.add(NaiaRuleDiagnostic(line,
              '캐릭터 대상은 char:1, uc:1 또는 char:*, uc:* 형식이어야 합니다.',
              warning: true));
        }
        if (operator == '+:') {
          issues.add(NaiaRuleDiagnostic(line,
              '캐릭터/UC의 +:는 위치 지정이 아니라 끝에 추가됩니다.', warning: true));
        }
      } else if (const {'main', 'prefix', 'postfix'}.contains(target) &&
          operator == '=') {
        issues.add(NaiaRuleDiagnostic(line,
            '$target=은 영역 전체 대입이 아니라 동일 이름의 태그 치환입니다.',
            warning: true));
      } else if (target == 'neg' && operator == '+:') {
        issues.add(NaiaRuleDiagnostic(line,
            'neg+:는 위치 지정이 아니라 Negative 끝에 추가됩니다.',
            warning: true));
      } else if (operator == '+:' &&
          !const {'main', 'prefix', 'postfix', 'neg'}.contains(target)) {
        issues.add(NaiaRuleDiagnostic(line,
            '이 +: 동작은 대상 태그 뒤가 아니라 Main 끝에 추가됩니다.',
            warning: true));
      }
    }
    return issues;
  }

  static int _matchingParen(String value) {
    var depth = 0;
    for (var i = 0; i < value.length; i++) {
      if (value[i] == '(') depth++;
      if (value[i] == ')') {
        depth--;
        if (depth < 0) return -1;
        if (depth == 0) return i;
      }
    }
    return -1;
  }

  static List<String> _splitArguments(String value) {
    final parts = <String>[];
    var depth = 0;
    var start = 0;
    for (var i = 0; i < value.length; i++) {
      if (value[i] == '(') depth++;
      if (value[i] == ')') depth--;
      if (value[i] == ',' && depth == 0) {
        parts.add(value.substring(start, i).trim());
        start = i + 1;
      }
    }
    parts.add(value.substring(start).trim());
    return parts;
  }

  static void _checkCondition(String condition, int line,
      List<NaiaRuleDiagnostic> issues) {
    var depth = 0;
    for (var i = 0; i < condition.length; i++) {
      if (condition[i] == '(') depth++;
      if (condition[i] == ')') depth--;
      if (depth < 0) break;
    }
    if (depth != 0) {
      issues.add(NaiaRuleDiagnostic(line, '조건식 괄호가 맞지 않습니다.'));
    }
    if (RegExp(r'(^|[(&|])\s*[&|]|[&|]\s*([)&|]|$)')
        .hasMatch(condition)) {
      issues.add(NaiaRuleDiagnostic(line,
          '조건식에 비어 있는 AND/OR 항목이 있어 실행 시 일치하지 않습니다.',
          warning: true));
    }
    final predicates = RegExp(r'~?char_(?:on|in)\s*\([^)]*\)',
        caseSensitive: false).allMatches(condition);
    for (final predicate in predicates) {
      final value = predicate.group(0)!;
      if (!RegExp(r'^~?char_on\s*\(\s*[1-9]\d*\s*\)$|^~?char_in\s*\(\s*[1-9]\d*\s*,\s*.+\)$',
          caseSensitive: false).hasMatch(value)) {
        issues.add(NaiaRuleDiagnostic(line,
            '캐릭터 조건식 인자가 올바르지 않아 일반 태그로 해석될 수 있습니다.',
            warning: true));
      }
    }
  }
}
