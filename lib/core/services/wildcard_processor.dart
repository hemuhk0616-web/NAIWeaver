import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'wildcard_service.dart';

enum WildcardMode { random, sequential, shuffle, weighted }

class WildcardProcessor {
  final String wildcardDir;
  final WildcardService? wildcardService;
  final Random _random = Random();
  final Map<String, int> _sequentialIndex = {};
  final Map<String, List<int>> _shuffleRemaining = {};

  WildcardProcessor({required this.wildcardDir, this.wildcardService});

  Future<String> process(String prompt) async {
    String processedPrompt = prompt;
    bool hasChanged = true;
    int depth = 0;
    const int maxDepth = 5;

    while (hasChanged && depth < maxDepth) {
      hasChanged = false;
      final matches = RegExp(r'__([^\r\n]+?)__').allMatches(processedPrompt).toList();

      if (matches.isEmpty) break;

      // Process matches from end to start to avoid index shifts
      for (final match in matches.reversed) {
        final wildcardName = match.group(1);
        if (wildcardName == null) continue;

        final replacement = await _getWildcardReplacement(wildcardName);
        if (replacement != null) {
          processedPrompt = processedPrompt.replaceRange(match.start, match.end, replacement);
          hasChanged = true;
        }
      }
      depth++;
    }

    return processedPrompt;
  }

  Future<String?> _getWildcardReplacement(String name) async {
    if (kIsWeb) {
      // Wildcard .txt content lives on disk on native; web doesn't have a
      // filesystem (yet). Leave the wildcard placeholder unresolved so the
      // raw `__name__` token surfaces to the user instead of crashing.
      return null;
    }
    try {
      final normalizedName = name.replaceAll('\\', '/');
      if (normalizedName.startsWith('/') || normalizedName.split('/').contains('..')) return null;
      final root = p.normalize(p.absolute(wildcardDir));
      var resolved = p.normalize(p.join(root, '$normalizedName.txt'));
      if (!p.isWithin(root, resolved)) return null;
      if (!await File(resolved).exists() && !normalizedName.contains('/')) {
        final matches = wildcardService?.wildcardNames
            .where((item) => item == normalizedName || item.endsWith('/$normalizedName'))
            .toList() ?? [];
        if (matches.length == 1) resolved = p.normalize(p.join(root, '${matches.single}.txt'));
      }
      if (!p.isWithin(wildcardDir, resolved)) return null;
      final file = File(resolved);
      if (await file.exists()) {
        final lines = await file.readAsLines();
        final validLines = lines.where((l) => l.trim().isNotEmpty && !l.trimLeft().startsWith('#')).toList();

        if (validLines.isNotEmpty) {
          final mode = wildcardService?.getMode(name) ?? WildcardMode.random;
          switch (mode) {
            case WildcardMode.random:
              return _selectWeighted(validLines);
            case WildcardMode.sequential:
              return _selectSequential(name, validLines);
            case WildcardMode.shuffle:
              return _selectShuffle(name, validLines);
            case WildcardMode.weighted:
              return _selectWeighted(validLines);
          }
        }
      }
    } catch (e) {
      debugPrint('Error reading wildcard $name: $e');
    }
    return null;
  }

  String _selectSequential(String name, List<String> lines) {
    final index = _sequentialIndex[name] ?? 0;
    final line = lines[index % lines.length].trim();
    _sequentialIndex[name] = (index + 1) % lines.length;
    return line;
  }

  String _selectShuffle(String name, List<String> lines) {
    var remaining = _shuffleRemaining[name];
    if (remaining == null || remaining.isEmpty) {
      remaining = List<int>.generate(lines.length, (i) => i)..shuffle(_random);
      _shuffleRemaining[name] = remaining;
    }
    final index = remaining.removeLast();
    return lines[index].trim();
  }

  String _selectWeighted(List<String> lines) {
    int totalWeight = 0;
    final weights = <int>[];
    final values = <String>[];

    for (final line in lines) {
      final trimmed = line.trim();
      final match = RegExp(r'^(\d+(?:\.\d+)?)\s*:(?!=|:)\s*(.+)
      if (match != null) {
        final weight = (double.parse(match.group(1)!) * 1000).round();
        weights.add(weight);
        values.add(match.group(2)!.trim());
        totalWeight += weight;
      } else {
        weights.add(1000);
        values.add(trimmed);
        totalWeight += 1000;
      }
    }

    var roll = _random.nextInt(totalWeight);
    for (int i = 0; i < weights.length; i++) {
      roll -= weights[i];
      if (roll < 0) return values[i];
    }
    return values.last;
  }
}
).firstMatch(trimmed);
      if (match != null) {
        final weight = int.parse(match.group(1)!);
        weights.add(weight);
        values.add(match.group(2)!.trim());
        totalWeight += weight;
      } else {
        weights.add(1);
        values.add(trimmed);
        totalWeight += 1;
      }
    }

    var roll = _random.nextInt(totalWeight);
    for (int i = 0; i < weights.length; i++) {
      roll -= weights[i];
      if (roll < 0) return values[i];
    }
    return values.last;
  }
}
