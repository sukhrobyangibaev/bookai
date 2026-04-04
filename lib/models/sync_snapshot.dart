import 'dart:convert';

import 'ai_feature_config.dart';
import 'ai_model_selection.dart';
import 'highlight.dart';
import 'reader_settings.dart';
import 'reading_progress.dart';
import 'resume_marker.dart';

class SyncSnapshot {
  static const int currentSchemaVersion = 1;

  final int schemaVersion;
  final DateTime exportedAt;
  final SyncSnapshotSettings settings;
  final List<SyncSnapshotBookState> books;

  const SyncSnapshot({
    this.schemaVersion = currentSchemaVersion,
    required this.exportedAt,
    required this.settings,
    this.books = const <SyncSnapshotBookState>[],
  });

  Map<String, dynamic> toMap() {
    return {
      'schemaVersion': schemaVersion,
      'exportedAt': exportedAt.toIso8601String(),
      'settings': settings.toMap(),
      'books': books.map((book) => book.toMap()).toList(),
    };
  }

  String toJson() => jsonEncode(toMap());

  factory SyncSnapshot.fromMap(Map<String, dynamic> map) {
    final schemaVersion = (map['schemaVersion'] as num?)?.toInt() ?? 0;
    if (schemaVersion != currentSchemaVersion) {
      throw FormatException(
        'Unsupported sync snapshot schema version: $schemaVersion',
      );
    }

    final rawSettings = map['settings'];
    if (rawSettings is! Map) {
      throw const FormatException('Sync snapshot is missing settings');
    }

    final rawBooks = map['books'];
    final books = rawBooks is List
        ? rawBooks
            .whereType<Map>()
            .map((book) => SyncSnapshotBookState.fromMap(
                  Map<String, dynamic>.from(book),
                ))
            .toList()
        : const <SyncSnapshotBookState>[];

    return SyncSnapshot(
      schemaVersion: schemaVersion,
      exportedAt: DateTime.parse(map['exportedAt'] as String),
      settings: SyncSnapshotSettings.fromMap(
        Map<String, dynamic>.from(rawSettings),
      ),
      books: books,
    );
  }

  factory SyncSnapshot.fromJson(String json) {
    final decoded = jsonDecode(json);
    if (decoded is! Map) {
      throw const FormatException('Sync snapshot JSON must be an object');
    }
    return SyncSnapshot.fromMap(Map<String, dynamic>.from(decoded));
  }

  @override
  String toString() {
    return 'SyncSnapshot(schemaVersion: $schemaVersion, '
        'exportedAt: $exportedAt, books: ${books.length})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SyncSnapshot &&
        other.schemaVersion == schemaVersion &&
        other.exportedAt == exportedAt &&
        other.settings == settings &&
        _listEquals(other.books, books);
  }

  @override
  int get hashCode => Object.hash(
        schemaVersion,
        exportedAt,
        settings,
        Object.hashAll(books),
      );
}

class SyncSnapshotSettings {
  final DateTime updatedAt;
  final double fontSize;
  final AppThemeMode themeMode;
  final ReaderFontFamily fontFamily;
  final AiModelSelection defaultModelSelection;
  final AiModelSelection fallbackModelSelection;
  final AiModelSelection imageModelSelection;
  final Map<String, AiFeatureConfig> aiFeatureConfigs;
  final String? openRouterApiKey;
  final String? geminiApiKey;

  const SyncSnapshotSettings({
    required this.updatedAt,
    required this.fontSize,
    required this.themeMode,
    required this.fontFamily,
    required this.defaultModelSelection,
    required this.fallbackModelSelection,
    required this.imageModelSelection,
    required this.aiFeatureConfigs,
    this.openRouterApiKey,
    this.geminiApiKey,
  });

  factory SyncSnapshotSettings.fromReaderSettings(
    ReaderSettings settings, {
    required DateTime updatedAt,
    required bool includeApiKeys,
  }) {
    return SyncSnapshotSettings(
      updatedAt: updatedAt,
      fontSize: settings.fontSize,
      themeMode: settings.themeMode,
      fontFamily: settings.fontFamily,
      defaultModelSelection: settings.defaultModelSelection,
      fallbackModelSelection: settings.fallbackModelSelection,
      imageModelSelection: settings.imageModelSelection,
      aiFeatureConfigs: settings.aiFeatureConfigs,
      openRouterApiKey: includeApiKeys ? settings.openRouterApiKey : null,
      geminiApiKey: includeApiKeys ? settings.geminiApiKey : null,
    );
  }

  ReaderSettings applyTo(ReaderSettings baseSettings) {
    return ReaderSettings(
      fontSize: fontSize,
      themeMode: themeMode,
      fontFamily: fontFamily,
      openRouterApiKey: openRouterApiKey ?? baseSettings.openRouterApiKey,
      geminiApiKey: geminiApiKey ?? baseSettings.geminiApiKey,
      defaultModelSelection: defaultModelSelection,
      fallbackModelSelection: fallbackModelSelection,
      imageModelSelection: imageModelSelection,
      aiFeatureConfigs: aiFeatureConfigs,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'updatedAt': updatedAt.toIso8601String(),
      'fontSize': fontSize,
      'themeMode': themeMode.name,
      'fontFamily': fontFamily.name,
      'defaultModelSelection': defaultModelSelection.toMap(),
      'fallbackModelSelection': fallbackModelSelection.toMap(),
      'imageModelSelection': imageModelSelection.toMap(),
      'aiFeatureConfigs':
          aiFeatureConfigs.map((key, value) => MapEntry(key, value.toMap())),
      if (openRouterApiKey != null) 'openRouterApiKey': openRouterApiKey,
      if (geminiApiKey != null) 'geminiApiKey': geminiApiKey,
    };
  }

  factory SyncSnapshotSettings.fromMap(Map<String, dynamic> map) {
    final settings = ReaderSettings.fromMap(map);
    final hasOpenRouterApiKey = map.containsKey('openRouterApiKey');
    final hasGeminiApiKey = map.containsKey('geminiApiKey');

    return SyncSnapshotSettings(
      updatedAt: DateTime.parse(map['updatedAt'] as String),
      fontSize: settings.fontSize,
      themeMode: settings.themeMode,
      fontFamily: settings.fontFamily,
      defaultModelSelection: settings.defaultModelSelection,
      fallbackModelSelection: settings.fallbackModelSelection,
      imageModelSelection: settings.imageModelSelection,
      aiFeatureConfigs: settings.aiFeatureConfigs,
      openRouterApiKey: hasOpenRouterApiKey ? settings.openRouterApiKey : null,
      geminiApiKey: hasGeminiApiKey ? settings.geminiApiKey : null,
    );
  }

  @override
  String toString() {
    return 'SyncSnapshotSettings(updatedAt: $updatedAt, '
        'fontSize: $fontSize, themeMode: $themeMode, fontFamily: $fontFamily, '
        'apiKeysIncluded: ${openRouterApiKey != null || geminiApiKey != null})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SyncSnapshotSettings &&
        other.updatedAt == updatedAt &&
        other.fontSize == fontSize &&
        other.themeMode == themeMode &&
        other.fontFamily == fontFamily &&
        other.defaultModelSelection == defaultModelSelection &&
        other.fallbackModelSelection == fallbackModelSelection &&
        other.imageModelSelection == imageModelSelection &&
        other.openRouterApiKey == openRouterApiKey &&
        other.geminiApiKey == geminiApiKey &&
        _mapEquals(other.aiFeatureConfigs, aiFeatureConfigs);
  }

  @override
  int get hashCode => Object.hash(
        updatedAt,
        fontSize,
        themeMode,
        fontFamily,
        defaultModelSelection,
        fallbackModelSelection,
        imageModelSelection,
        openRouterApiKey,
        geminiApiKey,
        Object.hashAllUnordered(
          aiFeatureConfigs.entries.map(
            (entry) => Object.hash(entry.key, entry.value),
          ),
        ),
      );
}

class SyncSnapshotBookState {
  final String syncKey;
  final SyncSnapshotProgress? progress;
  final SyncSnapshotResumeMarker? resumeMarker;
  final List<SyncSnapshotHighlight> highlights;

  const SyncSnapshotBookState({
    required this.syncKey,
    this.progress,
    this.resumeMarker,
    this.highlights = const <SyncSnapshotHighlight>[],
  });

  Map<String, dynamic> toMap() {
    return {
      'syncKey': syncKey,
      'progress': progress?.toMap(),
      'resumeMarker': resumeMarker?.toMap(),
      'highlights': highlights.map((highlight) => highlight.toMap()).toList(),
    };
  }

  factory SyncSnapshotBookState.fromMap(Map<String, dynamic> map) {
    final rawProgress = map['progress'];
    final rawResumeMarker = map['resumeMarker'];
    final rawHighlights = map['highlights'];

    return SyncSnapshotBookState(
      syncKey: (map['syncKey'] as String? ?? '').trim(),
      progress: rawProgress is Map
          ? SyncSnapshotProgress.fromMap(Map<String, dynamic>.from(rawProgress))
          : null,
      resumeMarker: rawResumeMarker is Map
          ? SyncSnapshotResumeMarker.fromMap(
              Map<String, dynamic>.from(rawResumeMarker),
            )
          : null,
      highlights: rawHighlights is List
          ? rawHighlights
              .whereType<Map>()
              .map(
                (highlight) => SyncSnapshotHighlight.fromMap(
                  Map<String, dynamic>.from(highlight),
                ),
              )
              .toList()
          : const <SyncSnapshotHighlight>[],
    );
  }

  @override
  String toString() {
    return 'SyncSnapshotBookState(syncKey: $syncKey, '
        'hasProgress: ${progress != null}, '
        'hasResumeMarker: ${resumeMarker != null}, '
        'highlights: ${highlights.length})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SyncSnapshotBookState &&
        other.syncKey == syncKey &&
        other.progress == progress &&
        other.resumeMarker == resumeMarker &&
        _listEquals(other.highlights, highlights);
  }

  @override
  int get hashCode => Object.hash(
        syncKey,
        progress,
        resumeMarker,
        Object.hashAll(highlights),
      );
}

class SyncSnapshotProgress {
  final int chapterIndex;
  final double scrollOffset;
  final DateTime updatedAt;

  const SyncSnapshotProgress({
    required this.chapterIndex,
    required this.scrollOffset,
    required this.updatedAt,
  });

  factory SyncSnapshotProgress.fromReadingProgress(ReadingProgress progress) {
    return SyncSnapshotProgress(
      chapterIndex: progress.chapterIndex,
      scrollOffset: progress.scrollOffset,
      updatedAt: progress.updatedAt,
    );
  }

  ReadingProgress toReadingProgress({required int bookId}) {
    return ReadingProgress(
      bookId: bookId,
      chapterIndex: chapterIndex,
      scrollOffset: scrollOffset,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'chapterIndex': chapterIndex,
      'scrollOffset': scrollOffset,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory SyncSnapshotProgress.fromMap(Map<String, dynamic> map) {
    return SyncSnapshotProgress(
      chapterIndex: map['chapterIndex'] as int,
      scrollOffset: (map['scrollOffset'] as num).toDouble(),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }

  @override
  String toString() {
    return 'SyncSnapshotProgress(chapterIndex: $chapterIndex, '
        'scrollOffset: $scrollOffset, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SyncSnapshotProgress &&
        other.chapterIndex == chapterIndex &&
        other.scrollOffset == scrollOffset &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode => Object.hash(chapterIndex, scrollOffset, updatedAt);
}

class SyncSnapshotResumeMarker {
  final int chapterIndex;
  final String selectedText;
  final int selectionStart;
  final int selectionEnd;
  final double scrollOffset;
  final DateTime createdAt;

  const SyncSnapshotResumeMarker({
    required this.chapterIndex,
    required this.selectedText,
    required this.selectionStart,
    required this.selectionEnd,
    required this.scrollOffset,
    required this.createdAt,
  });

  factory SyncSnapshotResumeMarker.fromResumeMarker(ResumeMarker marker) {
    return SyncSnapshotResumeMarker(
      chapterIndex: marker.chapterIndex,
      selectedText: marker.selectedText,
      selectionStart: marker.selectionStart,
      selectionEnd: marker.selectionEnd,
      scrollOffset: marker.scrollOffset,
      createdAt: marker.createdAt,
    );
  }

  ResumeMarker toResumeMarker({required int bookId}) {
    return ResumeMarker(
      bookId: bookId,
      chapterIndex: chapterIndex,
      selectedText: selectedText,
      selectionStart: selectionStart,
      selectionEnd: selectionEnd,
      scrollOffset: scrollOffset,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'chapterIndex': chapterIndex,
      'selectedText': selectedText,
      'selectionStart': selectionStart,
      'selectionEnd': selectionEnd,
      'scrollOffset': scrollOffset,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory SyncSnapshotResumeMarker.fromMap(Map<String, dynamic> map) {
    return SyncSnapshotResumeMarker(
      chapterIndex: map['chapterIndex'] as int,
      selectedText: map['selectedText'] as String,
      selectionStart: map['selectionStart'] as int,
      selectionEnd: map['selectionEnd'] as int,
      scrollOffset: (map['scrollOffset'] as num).toDouble(),
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  @override
  String toString() {
    return 'SyncSnapshotResumeMarker(chapterIndex: $chapterIndex, '
        'selectionStart: $selectionStart, selectionEnd: $selectionEnd, '
        'scrollOffset: $scrollOffset, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SyncSnapshotResumeMarker &&
        other.chapterIndex == chapterIndex &&
        other.selectedText == selectedText &&
        other.selectionStart == selectionStart &&
        other.selectionEnd == selectionEnd &&
        other.scrollOffset == scrollOffset &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode => Object.hash(
        chapterIndex,
        selectedText,
        selectionStart,
        selectionEnd,
        scrollOffset,
        createdAt,
      );
}

class SyncSnapshotHighlight {
  final int chapterIndex;
  final String selectedText;
  final String colorHex;
  final DateTime createdAt;

  const SyncSnapshotHighlight({
    required this.chapterIndex,
    required this.selectedText,
    required this.colorHex,
    required this.createdAt,
  });

  factory SyncSnapshotHighlight.fromHighlight(Highlight highlight) {
    return SyncSnapshotHighlight(
      chapterIndex: highlight.chapterIndex,
      selectedText: highlight.selectedText,
      colorHex: highlight.colorHex,
      createdAt: highlight.createdAt,
    );
  }

  Highlight toHighlight({required int bookId}) {
    return Highlight(
      bookId: bookId,
      chapterIndex: chapterIndex,
      selectedText: selectedText,
      colorHex: colorHex,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'chapterIndex': chapterIndex,
      'selectedText': selectedText,
      'colorHex': colorHex,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory SyncSnapshotHighlight.fromMap(Map<String, dynamic> map) {
    return SyncSnapshotHighlight(
      chapterIndex: map['chapterIndex'] as int,
      selectedText: map['selectedText'] as String,
      colorHex: map['colorHex'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  @override
  String toString() {
    return 'SyncSnapshotHighlight(chapterIndex: $chapterIndex, '
        'selectedText: $selectedText, colorHex: $colorHex, '
        'createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SyncSnapshotHighlight &&
        other.chapterIndex == chapterIndex &&
        other.selectedText == selectedText &&
        other.colorHex == colorHex &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode =>
      Object.hash(chapterIndex, selectedText, colorHex, createdAt);
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i += 1) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

bool _mapEquals<T>(Map<String, T> a, Map<String, T> b) {
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    if (b[entry.key] != entry.value) return false;
  }
  return true;
}
