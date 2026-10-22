/// Parses NAIA wildcard-generated resolution directives without sending
/// the directive itself to NovelAI as a prompt tag.
class NaiaResolutionDirective {
  const NaiaResolutionDirective._();

  static ({String prompt, int? width, int? height}) extract(String prompt) {
    int? width;
    int? height;
    final kept = <String>[];
    for (final tag in prompt.split(',')) {
      final match = RegExp(r'^\s*resolution\s*:\s*(\d+)\s*x\s*(\d+)\s*$', caseSensitive: false).firstMatch(tag);
      if (match == null) {
        kept.add(tag);
        continue;
      }
      final w = int.parse(match.group(1)!);
      final h = int.parse(match.group(2)!);
      // Reject malformed or implausible sizes rather than sending an invalid
      // request. Both dimensions must align with NovelAI's 64px grid.
      if (w >= 64 && h >= 64 && w <= 2048 && h <= 2048 &&
          w % 64 == 0 && h % 64 == 0 && w * h <= 3145728) {
        width = w;
        height = h;
      } else {
        kept.add(tag);
      }
    }
    return (prompt: kept.map((s) => s.trim()).where((s) => s.isNotEmpty).join(', '),
      width: width, height: height);
  }
}
