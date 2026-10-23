import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'path_service.dart';

/// Portable settings and prompt data. Secrets are intentionally excluded.
class AppBackupService {
  static const format = 'naiweaver-backup-v1';
  static const roots = ['wildcards', 'characters'];
  static const names = ['presets.json', 'prompt_styles.json',
    'reference_library.json'];
  bool safeKey(String key) => !RegExp(
    r'api.?key|token|password|secret|credential|auth|pin|biometric',
    caseSensitive: false).hasMatch(key);
  bool safeFile(String relative) {
    final segments = relative.split('/');
    return !segments.contains('..') && !segments.contains('') &&
      (names.contains(relative) ||
       roots.any((root) => relative.startsWith('$root/')));
  }

  Future<void> exportBackup(PathService paths) async {
    final prefs = await SharedPreferences.getInstance();
    final settings = <String, Object>{};
    for (final key in prefs.getKeys()) {
      if (!safeKey(key)) {
        continue;
      }
      final value = prefs.get(key);
      if (value is String || value is bool || value is int ||
          value is double || value is List<String>) {
        settings[key] = value as Object;
      }
    }
    final files = <String, String>{};
    Future<void> add(File file) async {
      final relative = p.relative(file.path, from: paths.baseDir)
          .replaceAll('\\', '/');
      if (!safeFile(relative) || !await file.exists() ||
          await file.length() > 8 * 1024 * 1024) {
        return;
      }
      files[relative] = base64Encode(await file.readAsBytes());
    }
    for (final name in names) {
      await add(File(p.join(paths.baseDir, name)));
    }
    for (final root in roots) {
      final dir = Directory(p.join(paths.baseDir, root));
      if (!await dir.exists()) {
        continue;
      }
      await for (final item in dir.list(recursive: true, followLinks: false)) {
        if (item is File) {
          await add(item);
        }
      }
    }
    final temp = await getTemporaryDirectory();
    final output = File(p.join(temp.path,
      'NAIWeaver-backup-${DateTime.now().millisecondsSinceEpoch}.json'));
    await output.writeAsString(jsonEncode({
      'format': format,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'settings': settings,
      'files': files,
    }), flush: true);
    await Share.shareXFiles([XFile(output.path)],
        text: 'NAIWeaver 설정 백업 (API 키 제외)');
  }

  Future<bool> importBackup(PathService paths) async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom, allowedExtensions: ['json'], withData: true);
    if (picked == null || picked.files.isEmpty) return false;
    final selection = picked.files.single;
    final bytes = selection.bytes ?? (selection.path == null
        ? null : await File(selection.path!).readAsBytes());
    if (bytes == null || bytes.length > 64 * 1024 * 1024) {
      throw const FormatException('백업 파일이 없거나 너무 큽니다.');
    }
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map || decoded['format'] != format ||
        decoded['settings'] is! Map || decoded['files'] is! Map) {
      throw const FormatException('지원하지 않는 백업 형식입니다.');
    }
    final files = <String, List<int>>{};
    for (final entry in (decoded['files'] as Map).entries) {
      if (entry.key is! String || entry.value is! String ||
          !safeFile(entry.key as String)) {
        throw const FormatException('잘못된 백업 파일 경로입니다.');
      }
      files[entry.key as String] = base64Decode(entry.value as String);
    }
    final settings = <String, Object>{};
    for (final entry in (decoded['settings'] as Map).entries) {
      if (entry.key is! String || !safeKey(entry.key as String)) {
        continue;
      }
      final value = entry.value;
      if (value is String || value is bool || value is int ||
          value is double || (value is List &&
          value.every((v) => v is String))) {
        settings[entry.key as String] = value;
      }
    }
    for (final entry in files.entries) {
      final target = File(p.join(paths.baseDir, entry.key));
      await target.parent.create(recursive: true);
      await target.writeAsBytes(entry.value, flush: true);
    }
    final prefs = await SharedPreferences.getInstance();
    for (final entry in settings.entries) {
      final value = entry.value;
      if (value is String) {
        await prefs.setString(entry.key, value);
      } else if (value is bool) {
        await prefs.setBool(entry.key, value);
      } else if (value is int) {
        await prefs.setInt(entry.key, value);
      } else if (value is double) {
        await prefs.setDouble(entry.key, value);
      } else if (value is List) {
        await prefs.setStringList(entry.key, value.cast<String>());
      }
    }
    return true;
  }
}
