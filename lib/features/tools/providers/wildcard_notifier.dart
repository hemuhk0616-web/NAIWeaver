import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../../../core/services/wildcard_service.dart';
import '../../../core/services/tag_service.dart';
import '../../../core/services/wildcard_processor.dart';

class WildcardState {
  final List<File> files;
  final File? selectedFile;
  final String content;
  final List<DanbooruTag> tagSuggestions;
  final String currentTagQuery;
  final bool isLoading;
  final List<String> invalidTags;
  final int validCount;

  WildcardState({
    this.files = const [],
    this.selectedFile,
    this.content = '',
    this.tagSuggestions = const [],
    this.currentTagQuery = '',
    this.isLoading = false,
    this.invalidTags = const [],
    this.validCount = 0,
  });

  WildcardState copyWith({
    List<File>? files,
    File? selectedFile,
    String? content,
    List<DanbooruTag>? tagSuggestions,
    String? currentTagQuery,
    bool? isLoading,
    List<String>? invalidTags,
    int? validCount,
  }) {
    return WildcardState(
      files: files ?? this.files,
      selectedFile: selectedFile ?? this.selectedFile,
      content: content ?? this.content,
      tagSuggestions: tagSuggestions ?? this.tagSuggestions,
      currentTagQuery: currentTagQuery ?? this.currentTagQuery,
      isLoading: isLoading ?? this.isLoading,
      invalidTags: invalidTags ?? this.invalidTags,
      validCount: validCount ?? this.validCount,
    );
  }
}

class WildcardNotifier extends ChangeNotifier {
  final String wildcardDir;
  final TagService tagService;
  final WildcardService wildcardService;

  WildcardState _state = WildcardState();
  WildcardState get state => _state;

  final TextEditingController editorController = TextEditingController();

  // Debounce disk writes while the user is typing. Previously every keystroke
  // triggered a full writeAsString of the whole file, which made editing a
  // wildcard with hundreds of entries lag badly. We now coalesce writes and
  // only flush after the user pauses (or on file switch / dispose).
  Timer? _saveDebounce;
  static const _saveDebounceDelay = Duration(milliseconds: 600);

  WildcardNotifier({
    required this.wildcardDir,
    required this.tagService,
    required this.wildcardService,
  }) {
    refreshFiles();
  }

  Future<void> refreshFiles() async {
    // Wildcard .txt files live on disk; web has no filesystem, so the
    // manager simply shows an empty list instead of throwing `_Namespace`.
    if (kIsWeb) {
      _state = _state.copyWith(files: [], isLoading: false);
      notifyListeners();
      return;
    }

    _state = _state.copyWith(isLoading: true);
    notifyListeners();

    try {
      final directory = Directory(wildcardDir);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      final fileMap = <String, File>{};
      for (final f in directory.listSync(recursive: true, followLinks: false).whereType<File>()) {
        if (p.extension(f.path) == '.txt') {
          fileMap[p.withoutExtension(p.relative(f.path, from: wildcardDir)).replaceAll(r'\', '/')] = f;
        }
      }

      // Use wildcardService.wildcardNames order (respects custom order)
      final orderedFiles = <File>[];
      for (final name in wildcardService.wildcardNames) {
        final file = fileMap[name];
        if (file != null) orderedFiles.add(file);
      }

      _state = _state.copyWith(files: orderedFiles, isLoading: false);
    } catch (e) {
      debugPrint('Error refreshing wildcards: $e');
      _state = _state.copyWith(isLoading: false);
    }
    notifyListeners();
  }

  /// Wildcard settings are keyed by relative path, not filename alone.
  /// This keeps e.g. outfit/common and pose/common independent.
  String wildcardKey(File file) => p.withoutExtension(
      p.relative(file.path, from: wildcardDir)).replaceAll('\\', '/');

  bool isFavorite(File file) {
    return wildcardService.isFavorite(wildcardKey(file));
  }

  Future<void> toggleFavorite(File file) async {
    final name = wildcardKey(file);
    await wildcardService.toggleFavorite(name);
    await refreshFiles();
  }

  Future<void> reorderFiles(int oldIndex, int newIndex) async {
    await wildcardService.reorderWildcard(oldIndex, newIndex);
    await refreshFiles();
  }

  WildcardMode getFileMode(File file) {
    return wildcardService.getMode(wildcardKey(file));
  }

  Future<void> setFileMode(File file, WildcardMode mode) async {
    await wildcardService.setMode(wildcardKey(file), mode);
    notifyListeners();
  }

  Future<void> selectFile(File? file) async {
    // Persist any pending edits to the outgoing file before switching.
    await flushPendingSave();
    if (file == null) {
      _state = _state.copyWith(selectedFile: null, content: '', invalidTags: const [], validCount: 0);
      editorController.text = '';
      notifyListeners();
      return;
    }

    try {
      final content = await file.readAsString();
      _state = _state.copyWith(selectedFile: file, content: content, invalidTags: const [], validCount: 0);
      editorController.text = content;
    } catch (e) {
      debugPrint('Error reading wildcard file: $e');
    }
    notifyListeners();
  }

  void validateCurrentFile() {
    final lines = editorController.text.split('\n');
    final invalid = <String>[];
    int valid = 0;

    for (final line in lines) {
      final tag = line.trim();
      if (tag.isEmpty) continue;
      if (tagService.hasTag(tag)) {
        valid++;
      } else {
        invalid.add(tag);
      }
    }

    _state = _state.copyWith(invalidTags: invalid, validCount: valid);
    notifyListeners();
  }

  void clearValidation() {
    _state = _state.copyWith(invalidTags: const [], validCount: 0);
    notifyListeners();
  }

  /// Queue a save after a short idle delay. Safe to call on every keystroke —
  /// rapid calls collapse into a single disk write once typing pauses.
  void saveCurrentFileDebounced() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(_saveDebounceDelay, () {
      saveCurrentFile();
    });
  }

  /// If a debounced save is pending, run it now (e.g. before switching files or
  /// on dispose) so no edits are lost.
  Future<void> flushPendingSave() async {
    if (_saveDebounce?.isActive ?? false) {
      _saveDebounce!.cancel();
      _saveDebounce = null;
      await saveCurrentFile();
    }
  }

  Future<void> saveCurrentFile() async {
    _saveDebounce?.cancel();
    _saveDebounce = null;
    if (_state.selectedFile == null) return;

    try {
      await _state.selectedFile!.writeAsString(editorController.text);
      _state = _state.copyWith(content: editorController.text);
    } catch (e) {
      debugPrint('Error saving wildcard file: $e');
    }
    notifyListeners();
  }

  String? _safeWildcardName(String input) {
    final normalized = input.trim().replaceAll('\\', '/');
    final name = normalized.toLowerCase().endsWith('.txt')
        ? normalized.substring(0, normalized.length - 4) : normalized;
    final parts = name.split('/');
    if (parts.isEmpty || parts.any((part) =>
        part.isEmpty || part == '.' || part == '..' || part.contains(':'))) {
      return null;
    }
    return parts.join('/');
  }

  Future<void> createFile(String name) async {
    final key = _safeWildcardName(name);
    if (key == null) return;
    final root = p.normalize(p.absolute(wildcardDir));
    final destination = p.normalize(p.join(root, '$key.txt'));
    if (!p.isWithin(root, destination) || await File(destination).exists()) return;
    try {
      await Directory(p.dirname(destination)).create(recursive: true);
      await File(destination).writeAsString('');
      await wildcardService.refresh();
      await refreshFiles();
      final created = _state.files.where((f) => p.normalize(f.path) == destination);
      if (created.isNotEmpty) await selectFile(created.first);
    } catch (e) {
      debugPrint('Error creating wildcard file: $e');
    }
  }

  Future<void> deleteFile(File file) async {
    try {
      await flushPendingSave();
      if (_state.selectedFile?.path == file.path) {
        _state = _state.copyWith(selectedFile: null, content: '');
        editorController.text = '';
      }
      await file.delete();
      await wildcardService.refresh();
      await refreshFiles();
    } catch (e) {
      debugPrint('Error deleting wildcard file: $e');
    }
  }

  Future<bool> renameFile(File file, String newName) async {
    final oldName = wildcardKey(file);
    final raw = newName.trim().replaceAll('\\', '/');
    final folder = p.posix.dirname(oldName);
    final requested = raw.contains('/')
        ? raw : '${folder == '.' ? '' : '$folder/'}$raw';
    final nextName = _safeWildcardName(requested);
    if (nextName == null || nextName == oldName) return false;
    try {
      await flushPendingSave();
      final wasSelected = _state.selectedFile?.path == file.path;
      final success = await wildcardService.renameWildcard(oldName, nextName);
      if (!success) return false;
      await refreshFiles();
      final renamed = _state.files.where((f) => wildcardKey(f) == nextName);
      if (wasSelected && renamed.isNotEmpty) {
        await selectFile(renamed.first);
      }
      return true;
    } catch (e) {
      debugPrint('Error renaming wildcard file: $e');
      return false;
    }
  }

  void handleTagSuggestions(String text, TextSelection selection) {
    if (!selection.isValid || selection.baseOffset != selection.extentOffset) {
      _state = _state.copyWith(tagSuggestions: []);
      notifyListeners();
      return;
    }

    final cursorPosition = selection.baseOffset;
    final beforeCursor = text.substring(0, cursorPosition);

    // Support both commas and line breaks as separators
    final lastDelimiter = beforeCursor.lastIndexOf(RegExp(r'[,|\n]'));
    final currentWord = beforeCursor.substring(lastDelimiter + 1).trimLeft();

    final minLength = TagService.containsNonAscii(currentWord) ? 1 : 3;
    if (currentWord.length >= minLength) {
      final suggestions = tagService.getSuggestions(currentWord);
      _state = _state.copyWith(
        currentTagQuery: currentWord,
        tagSuggestions: suggestions,
      );
    } else {
      _state = _state.copyWith(tagSuggestions: [], currentTagQuery: "");
    }
    notifyListeners();
  }

  void clearTagSuggestions() {
    if (_state.tagSuggestions.isEmpty) return;
    _state = _state.copyWith(tagSuggestions: [], currentTagQuery: "");
    notifyListeners();
  }

  void applyTagSuggestion(DanbooruTag tag) {
    final text = editorController.text;
    final selection = editorController.selection;
    final cursorPosition = selection.baseOffset;
    final beforeCursor = text.substring(0, cursorPosition);
    final afterCursor = text.substring(cursorPosition);

    final lastDelimiterIndex = beforeCursor.lastIndexOf(RegExp(r'[,|\n]'));
    final prefix = beforeCursor.substring(0, lastDelimiterIndex + 1);

    // Determine if we should add a comma or just the tag (if it's a new line)
    String separator = '';
    if (lastDelimiterIndex != -1) {
      final lastChar = beforeCursor[lastDelimiterIndex];
      if (lastChar == ',') separator = ' ';
    }

    final insertText = tag.matchedAlias ?? tag.tag;
    final newBeforeCursor = "$prefix$separator$insertText\n";
    editorController.value = TextEditingValue(
      text: newBeforeCursor + afterCursor,
      selection: TextSelection.collapsed(offset: newBeforeCursor.length),
    );

    _state = _state.copyWith(tagSuggestions: [], currentTagQuery: "");
    saveCurrentFile();
    notifyListeners();
  }

  @override
  void dispose() {
    // Best-effort flush of any pending edit. We can't await in dispose(), but
    // firing the write keeps the common case (close while a save is queued)
    // from dropping the user's last edits.
    if (_saveDebounce?.isActive ?? false) {
      _saveDebounce!.cancel();
      saveCurrentFile();
    }
    _saveDebounce = null;
    editorController.dispose();
    super.dispose();
  }
}
