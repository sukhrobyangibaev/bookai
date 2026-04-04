import '../models/highlight.dart';
import '../models/sync_snapshot.dart';
import 'database_service.dart';
import 'settings_service.dart';

class SyncSnapshotImportResult {
  final bool settingsApplied;
  final int matchedBooks;
  final int skippedBooks;
  final int importedProgressCount;
  final int importedResumeMarkerCount;
  final int importedHighlightCount;
  final int replacedHighlightCount;

  const SyncSnapshotImportResult({
    required this.settingsApplied,
    required this.matchedBooks,
    required this.skippedBooks,
    required this.importedProgressCount,
    required this.importedResumeMarkerCount,
    required this.importedHighlightCount,
    required this.replacedHighlightCount,
  });

  int get totalHighlightChanges =>
      importedHighlightCount + replacedHighlightCount;
}

class SyncSnapshotService {
  final DatabaseService _databaseService;
  final SettingsService _settingsService;

  SyncSnapshotService({
    DatabaseService? databaseService,
    SettingsService? settingsService,
  })  : _databaseService = databaseService ?? DatabaseService.instance,
        _settingsService = settingsService ?? SettingsService();

  Future<SyncSnapshot> exportSnapshot({
    bool includeApiKeys = false,
    DateTime? exportedAt,
  }) async {
    final snapshotTime = exportedAt ?? DateTime.now().toUtc();
    final settings = await _settingsService.load();
    final settingsUpdatedAt =
        await _settingsService.loadLastUpdatedAt() ?? snapshotTime;
    final books = await _databaseService.getAllBooks();
    final snapshotBooks = <SyncSnapshotBookState>[];

    for (final book in books) {
      final bookId = book.id;
      final syncKey = book.syncKey?.trim();
      if (bookId == null || syncKey == null || syncKey.isEmpty) {
        continue;
      }

      final progress = await _databaseService.getProgressByBookId(bookId);
      final resumeMarker =
          await _databaseService.getResumeMarkerByBookId(bookId);
      final highlights = await _databaseService.getHighlightsByBookId(bookId);

      snapshotBooks.add(
        SyncSnapshotBookState(
          syncKey: syncKey,
          progress: progress == null
              ? null
              : SyncSnapshotProgress.fromReadingProgress(progress),
          resumeMarker: resumeMarker == null
              ? null
              : SyncSnapshotResumeMarker.fromResumeMarker(resumeMarker),
          highlights:
              highlights.map(SyncSnapshotHighlight.fromHighlight).toList(),
        ),
      );
    }

    return SyncSnapshot(
      exportedAt: snapshotTime,
      settings: SyncSnapshotSettings.fromReaderSettings(
        settings,
        updatedAt: settingsUpdatedAt,
        includeApiKeys: includeApiKeys,
      ),
      books: snapshotBooks,
    );
  }

  Future<String> exportSnapshotJson({
    bool includeApiKeys = false,
    DateTime? exportedAt,
  }) async {
    final snapshot = await exportSnapshot(
      includeApiKeys: includeApiKeys,
      exportedAt: exportedAt,
    );
    return snapshot.toJson();
  }

  Future<SyncSnapshotImportResult> importSnapshotJson(
    String json, {
    bool clearMissingBookState = false,
    bool overwriteMatchingBookState = false,
  }) {
    return importSnapshot(
      SyncSnapshot.fromJson(json),
      clearMissingBookState: clearMissingBookState,
      overwriteMatchingBookState: overwriteMatchingBookState,
    );
  }

  Future<SyncSnapshotImportResult> importSnapshot(
    SyncSnapshot snapshot, {
    bool clearMissingBookState = false,
    bool overwriteMatchingBookState = false,
  }) async {
    var settingsApplied = false;
    var matchedBooks = 0;
    var skippedBooks = 0;
    var importedProgressCount = 0;
    var importedResumeMarkerCount = 0;
    var importedHighlightCount = 0;
    var replacedHighlightCount = 0;

    final localSettings = await _settingsService.load();
    final localSettingsUpdatedAt = await _settingsService.loadLastUpdatedAt();
    if (_shouldImportTimestampedValue(
      incoming: snapshot.settings.updatedAt,
      existing: localSettingsUpdatedAt,
    )) {
      final mergedSettings = snapshot.settings.applyTo(localSettings);
      final timestampChanged = localSettingsUpdatedAt == null ||
          !localSettingsUpdatedAt.isAtSameMomentAs(snapshot.settings.updatedAt);
      if (timestampChanged || mergedSettings != localSettings) {
        await _settingsService.saveAll(
          mergedSettings,
          updatedAt: snapshot.settings.updatedAt,
        );
        settingsApplied = true;
      }
    }

    for (final remoteBook in snapshot.books) {
      final syncKey = remoteBook.syncKey.trim();
      if (syncKey.isEmpty) {
        skippedBooks += 1;
        continue;
      }

      final localBook = await _databaseService.getBookBySyncKey(syncKey);
      final localBookId = localBook?.id;
      if (localBookId == null) {
        skippedBooks += 1;
        continue;
      }

      matchedBooks += 1;

      final localProgress =
          await _databaseService.getProgressByBookId(localBookId);
      final localResumeMarker =
          await _databaseService.getResumeMarkerByBookId(localBookId);
      final localHighlights =
          await _databaseService.getHighlightsByBookId(localBookId);

      final remoteProgress = remoteBook.progress;
      if (remoteProgress != null) {
        if (overwriteMatchingBookState ||
            _shouldImportTimestampedValue(
              incoming: remoteProgress.updatedAt,
              existing: localProgress?.updatedAt,
            )) {
          await _databaseService.upsertProgress(
            remoteProgress.toReadingProgress(bookId: localBookId),
          );
          importedProgressCount += 1;
        }
      } else if (clearMissingBookState && localProgress != null) {
        await _databaseService.deleteProgressByBookId(localBookId);
      }

      final remoteResumeMarker = remoteBook.resumeMarker;
      if (remoteResumeMarker != null) {
        if (overwriteMatchingBookState ||
            _shouldImportTimestampedValue(
              incoming: remoteResumeMarker.createdAt,
              existing: localResumeMarker?.createdAt,
            )) {
          await _databaseService.upsertResumeMarker(
            remoteResumeMarker.toResumeMarker(bookId: localBookId),
          );
          importedResumeMarkerCount += 1;
        }
      } else if (clearMissingBookState && localResumeMarker != null) {
        await _databaseService.deleteResumeMarkerByBookId(localBookId);
      }

      final remoteHighlightsByKey =
          _latestRemoteHighlightsByKey(remoteBook.highlights);
      if (remoteHighlightsByKey.isEmpty) {
        if (clearMissingBookState && localHighlights.isNotEmpty) {
          await _databaseService.deleteHighlightsByBookId(localBookId);
        }
        continue;
      }

      final localHighlightsByKey = _latestLocalHighlightsByKey(localHighlights);
      final remoteHighlightKeys = <String>{};

      for (final entry in remoteHighlightsByKey.entries) {
        remoteHighlightKeys.add(entry.key);
        final remoteHighlight = entry.value;
        final localHighlight = localHighlightsByKey[entry.key];

        if (localHighlight == null) {
          await _databaseService.addHighlight(
            remoteHighlight.toHighlight(bookId: localBookId),
          );
          importedHighlightCount += 1;
          continue;
        }

        final shouldReplace = overwriteMatchingBookState ||
            _shouldReplaceHighlight(localHighlight, remoteHighlight);
        if (!shouldReplace) {
          continue;
        }

        await _databaseService.deleteHighlightsBySelection(
          bookId: localBookId,
          chapterIndex: remoteHighlight.chapterIndex,
          selectedText: remoteHighlight.selectedText,
        );
        await _databaseService.addHighlight(
          remoteHighlight.toHighlight(bookId: localBookId),
        );
        replacedHighlightCount += 1;
      }

      if (clearMissingBookState) {
        final staleHighlightKeys =
            localHighlightsByKey.keys.toSet().difference(remoteHighlightKeys);
        for (final staleKey in staleHighlightKeys) {
          final staleHighlight = localHighlightsByKey[staleKey];
          if (staleHighlight == null) {
            continue;
          }
          await _databaseService.deleteHighlightsBySelection(
            bookId: localBookId,
            chapterIndex: staleHighlight.chapterIndex,
            selectedText: staleHighlight.selectedText,
          );
        }
      }
    }

    return SyncSnapshotImportResult(
      settingsApplied: settingsApplied,
      matchedBooks: matchedBooks,
      skippedBooks: skippedBooks,
      importedProgressCount: importedProgressCount,
      importedResumeMarkerCount: importedResumeMarkerCount,
      importedHighlightCount: importedHighlightCount,
      replacedHighlightCount: replacedHighlightCount,
    );
  }

  bool _shouldImportTimestampedValue({
    required DateTime incoming,
    required DateTime? existing,
  }) {
    if (existing == null) {
      return true;
    }
    return !incoming.isBefore(existing);
  }

  Map<String, Highlight> _latestLocalHighlightsByKey(
      List<Highlight> highlights) {
    final latestByKey = <String, Highlight>{};
    for (final highlight in highlights) {
      final key = _highlightKey(
        chapterIndex: highlight.chapterIndex,
        selectedText: highlight.selectedText,
      );
      final existing = latestByKey[key];
      if (existing == null ||
          !highlight.createdAt.isBefore(existing.createdAt)) {
        latestByKey[key] = highlight;
      }
    }
    return latestByKey;
  }

  Map<String, SyncSnapshotHighlight> _latestRemoteHighlightsByKey(
    List<SyncSnapshotHighlight> highlights,
  ) {
    final latestByKey = <String, SyncSnapshotHighlight>{};
    for (final highlight in highlights) {
      final key = _highlightKey(
        chapterIndex: highlight.chapterIndex,
        selectedText: highlight.selectedText,
      );
      final existing = latestByKey[key];
      if (existing == null ||
          !highlight.createdAt.isBefore(existing.createdAt)) {
        latestByKey[key] = highlight;
      }
    }
    return latestByKey;
  }

  bool _shouldReplaceHighlight(
    Highlight localHighlight,
    SyncSnapshotHighlight remoteHighlight,
  ) {
    if (remoteHighlight.createdAt.isAfter(localHighlight.createdAt)) {
      return true;
    }
    if (remoteHighlight.createdAt.isBefore(localHighlight.createdAt)) {
      return false;
    }
    return remoteHighlight.colorHex != localHighlight.colorHex;
  }

  String _highlightKey({
    required int chapterIndex,
    required String selectedText,
  }) {
    return '$chapterIndex\u0000$selectedText';
  }
}
