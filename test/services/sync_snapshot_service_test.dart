import 'dart:io';

import 'package:bookai/models/ai_feature.dart';
import 'package:bookai/models/ai_feature_config.dart';
import 'package:bookai/models/ai_model_selection.dart';
import 'package:bookai/models/ai_provider.dart';
import 'package:bookai/models/book.dart';
import 'package:bookai/models/highlight.dart';
import 'package:bookai/models/reader_settings.dart';
import 'package:bookai/models/reading_progress.dart';
import 'package:bookai/models/resume_marker.dart';
import 'package:bookai/models/sync_snapshot.dart';
import 'package:bookai/services/database_service.dart';
import 'package:bookai/services/settings_service.dart';
import 'package:bookai/services/sync_snapshot_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late String databasePath;
  late DatabaseService databaseService;
  late SettingsService settingsService;
  late SyncSnapshotService snapshotService;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'bookai_sync_snapshot_test_',
    );
    databasePath = p.join(tempDir.path, 'bookai.db');
    databaseService = DatabaseService.instance;
    await databaseService.resetForTesting(databasePath: databasePath);
    SharedPreferences.setMockInitialValues({});
    settingsService = SettingsService();
    snapshotService = SyncSnapshotService(
      databaseService: databaseService,
      settingsService: settingsService,
    );
  });

  tearDown(() async {
    await databaseService.resetForTesting();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('exports only sync-keyed books and can omit API keys', () async {
    final settingsUpdatedAt = DateTime.utc(2026, 4, 4, 9);
    await settingsService.saveAll(
      const ReaderSettings(
        fontSize: 21,
        themeMode: AppThemeMode.dark,
        fontFamily: ReaderFontFamily.bitter,
        openRouterApiKey: 'or-secret',
        geminiApiKey: 'gem-secret',
        defaultModelSelection: AiModelSelection(
          provider: AiProvider.gemini,
          modelId: 'gemini-2.5-flash',
        ),
        fallbackModelSelection: AiModelSelection(
          provider: AiProvider.openRouter,
          modelId: 'openai/gpt-4o-mini',
        ),
        imageModelSelection: AiModelSelection(
          provider: AiProvider.gemini,
          modelId: 'imagen-4.0-generate-001',
        ),
      ),
      updatedAt: settingsUpdatedAt,
    );

    final syncedBook = await databaseService.insertBook(
      Book(
        syncKey: 'epub-sha256:synced',
        title: 'Synced Book',
        author: 'Author',
        filePath: '/tmp/synced.epub',
        totalChapters: 8,
        createdAt: DateTime.utc(2026, 4, 1),
      ),
    );
    final unsyncedBook = await databaseService.insertBook(
      Book(
        title: 'Unsynced Book',
        author: 'Author',
        filePath: '/tmp/unsynced.bookai',
        totalChapters: 4,
        createdAt: DateTime.utc(2026, 4, 2),
      ),
    );

    await databaseService.upsertProgress(
      ReadingProgress(
        bookId: syncedBook.id!,
        chapterIndex: 3,
        scrollOffset: 64,
        updatedAt: DateTime.utc(2026, 4, 4, 8),
      ),
    );
    await databaseService.upsertResumeMarker(
      ResumeMarker(
        bookId: syncedBook.id!,
        chapterIndex: 2,
        selectedText: 'Resume here',
        selectionStart: 5,
        selectionEnd: 16,
        scrollOffset: 24,
        createdAt: DateTime.utc(2026, 4, 4, 7),
      ),
    );
    await databaseService.addHighlight(
      Highlight(
        bookId: syncedBook.id!,
        chapterIndex: 1,
        selectedText: 'Important text',
        colorHex: '#FFF59D',
        createdAt: DateTime.utc(2026, 4, 4, 6),
      ),
    );
    await databaseService.upsertProgress(
      ReadingProgress(
        bookId: unsyncedBook.id!,
        chapterIndex: 1,
        scrollOffset: 10,
        updatedAt: DateTime.utc(2026, 4, 4, 5),
      ),
    );

    final snapshot = await snapshotService.exportSnapshot(
      includeApiKeys: false,
      exportedAt: DateTime.utc(2026, 4, 4, 12),
    );

    expect(snapshot.settings.updatedAt, settingsUpdatedAt);
    expect(snapshot.settings.openRouterApiKey, isNull);
    expect(snapshot.settings.geminiApiKey, isNull);
    expect(snapshot.books, hasLength(1));
    expect(snapshot.books.single.syncKey, 'epub-sha256:synced');
    expect(snapshot.books.single.progress?.chapterIndex, 3);
    expect(snapshot.books.single.resumeMarker?.selectedText, 'Resume here');
    expect(
        snapshot.books.single.highlights.single.selectedText, 'Important text');
  });

  test(
      'imports matching sync state, skips missing books, and preserves local API keys when omitted',
      () async {
    await settingsService.saveAll(
      const ReaderSettings(
        fontSize: 18,
        themeMode: AppThemeMode.system,
        fontFamily: ReaderFontFamily.system,
        openRouterApiKey: 'keep-openrouter',
        geminiApiKey: 'keep-gemini',
        defaultModelSelection: AiModelSelection(
          provider: AiProvider.openRouter,
          modelId: 'openai/gpt-4.1-mini',
        ),
      ),
      updatedAt: DateTime.utc(2026, 1, 1),
    );

    final localBook = await databaseService.insertBook(
      Book(
        syncKey: 'epub-sha256:match',
        title: 'Local Book',
        author: 'Author',
        filePath: '/tmp/local.epub',
        totalChapters: 12,
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    );

    await databaseService.upsertProgress(
      ReadingProgress(
        bookId: localBook.id!,
        chapterIndex: 1,
        scrollOffset: 10,
        updatedAt: DateTime.utc(2026, 1, 5),
      ),
    );
    await databaseService.upsertResumeMarker(
      ResumeMarker(
        bookId: localBook.id!,
        chapterIndex: 2,
        selectedText: 'Keep this marker',
        selectionStart: 3,
        selectionEnd: 8,
        scrollOffset: 12,
        createdAt: DateTime.utc(2026, 1, 10),
      ),
    );
    await databaseService.addHighlight(
      Highlight(
        bookId: localBook.id!,
        chapterIndex: 0,
        selectedText: 'replace me',
        colorHex: '#111111',
        createdAt: DateTime.utc(2026, 1, 2),
      ),
    );
    await databaseService.addHighlight(
      Highlight(
        bookId: localBook.id!,
        chapterIndex: 0,
        selectedText: 'keep local',
        colorHex: '#222222',
        createdAt: DateTime.utc(2026, 3, 1),
      ),
    );

    final snapshot = SyncSnapshot(
      exportedAt: DateTime.utc(2026, 4, 4, 12),
      settings: SyncSnapshotSettings(
        updatedAt: DateTime.utc(2026, 2, 1),
        fontSize: 24,
        themeMode: AppThemeMode.sepia,
        fontFamily: ReaderFontFamily.literata,
        defaultModelSelection: const AiModelSelection(
          provider: AiProvider.gemini,
          modelId: 'gemini-2.5-flash',
        ),
        fallbackModelSelection: const AiModelSelection(
          provider: AiProvider.openRouter,
          modelId: 'openai/gpt-4o-mini',
        ),
        imageModelSelection: const AiModelSelection(
          provider: AiProvider.gemini,
          modelId: 'imagen-4.0-generate-001',
        ),
        aiFeatureConfigs: const {
          AiFeatureIds.resumeSummary: AiFeatureConfig(
            promptTemplate: 'Summarize {source_text}',
          ),
        },
      ),
      books: [
        SyncSnapshotBookState(
          syncKey: 'epub-sha256:match',
          progress: SyncSnapshotProgress(
            chapterIndex: 6,
            scrollOffset: 222,
            updatedAt: DateTime.utc(2026, 2, 2),
          ),
          resumeMarker: SyncSnapshotResumeMarker(
            chapterIndex: 1,
            selectedText: 'Older marker',
            selectionStart: 0,
            selectionEnd: 5,
            scrollOffset: 2,
            createdAt: DateTime.utc(2025, 12, 31),
          ),
          highlights: [
            SyncSnapshotHighlight(
              chapterIndex: 0,
              selectedText: 'replace me',
              colorHex: '#AAAAAA',
              createdAt: DateTime.utc(2026, 2, 1),
            ),
            SyncSnapshotHighlight(
              chapterIndex: 0,
              selectedText: 'keep local',
              colorHex: '#BBBBBB',
              createdAt: DateTime.utc(2026, 2, 15),
            ),
            SyncSnapshotHighlight(
              chapterIndex: 1,
              selectedText: 'new remote',
              colorHex: '#CCCCCC',
              createdAt: DateTime.utc(2026, 2, 10),
            ),
          ],
        ),
        SyncSnapshotBookState(
          syncKey: 'epub-sha256:missing',
          progress: SyncSnapshotProgress(
            chapterIndex: 3,
            scrollOffset: 50,
            updatedAt: DateTime.utc(2026, 2, 2),
          ),
        ),
      ],
    );

    final result = await snapshotService.importSnapshotJson(snapshot.toJson());

    expect(result.settingsApplied, isTrue);
    expect(result.matchedBooks, 1);
    expect(result.skippedBooks, 1);
    expect(result.importedProgressCount, 1);
    expect(result.importedResumeMarkerCount, 0);
    expect(result.importedHighlightCount, 1);
    expect(result.replacedHighlightCount, 1);

    final importedSettings = await settingsService.load();
    expect(importedSettings.fontSize, 24);
    expect(importedSettings.themeMode, AppThemeMode.sepia);
    expect(importedSettings.fontFamily, ReaderFontFamily.literata);
    expect(importedSettings.openRouterApiKey, 'keep-openrouter');
    expect(importedSettings.geminiApiKey, 'keep-gemini');
    expect(
      importedSettings.defaultModelSelection,
      const AiModelSelection(
        provider: AiProvider.gemini,
        modelId: 'gemini-2.5-flash',
      ),
    );
    expect(
      importedSettings.aiFeatureConfigs[AiFeatureIds.resumeSummary],
      const AiFeatureConfig(promptTemplate: 'Summarize {source_text}'),
    );

    final importedProgress =
        await databaseService.getProgressByBookId(localBook.id!);
    expect(importedProgress?.chapterIndex, 6);
    expect(importedProgress?.scrollOffset, 222);

    final importedResumeMarker =
        await databaseService.getResumeMarkerByBookId(localBook.id!);
    expect(importedResumeMarker?.selectedText, 'Keep this marker');
    expect(importedResumeMarker?.createdAt, DateTime.utc(2026, 1, 10));

    final importedHighlights =
        await databaseService.getHighlightsByBookId(localBook.id!);
    expect(
      importedHighlights
          .where((highlight) => highlight.selectedText == 'replace me')
          .single
          .colorHex,
      '#AAAAAA',
    );
    expect(
      importedHighlights
          .where((highlight) => highlight.selectedText == 'keep local')
          .single
          .colorHex,
      '#222222',
    );
    expect(
      importedHighlights.any(
        (highlight) => highlight.selectedText == 'new remote',
      ),
      isTrue,
    );
  });

  test('clearMissingBookState removes local state absent from snapshot',
      () async {
    final localBook = await databaseService.insertBook(
      Book(
        syncKey: 'epub-sha256:clear-me',
        title: 'Local Book',
        author: 'Author',
        filePath: '/tmp/local.epub',
        totalChapters: 3,
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    );

    await databaseService.upsertProgress(
      ReadingProgress(
        bookId: localBook.id!,
        chapterIndex: 1,
        scrollOffset: 10,
        updatedAt: DateTime.utc(2026, 1, 2),
      ),
    );
    await databaseService.upsertResumeMarker(
      ResumeMarker(
        bookId: localBook.id!,
        chapterIndex: 1,
        selectedText: 'Local marker',
        selectionStart: 0,
        selectionEnd: 5,
        scrollOffset: 8,
        createdAt: DateTime.utc(2026, 1, 3),
      ),
    );
    await databaseService.addHighlight(
      Highlight(
        bookId: localBook.id!,
        chapterIndex: 0,
        selectedText: 'remove this',
        colorHex: '#111111',
        createdAt: DateTime.utc(2026, 1, 4),
      ),
    );
    await databaseService.addHighlight(
      Highlight(
        bookId: localBook.id!,
        chapterIndex: 0,
        selectedText: 'keep this',
        colorHex: '#222222',
        createdAt: DateTime.utc(2026, 1, 5),
      ),
    );

    final snapshot = SyncSnapshot(
      exportedAt: DateTime.utc(2026, 4, 4, 12),
      settings: SyncSnapshotSettings.fromReaderSettings(
        ReaderSettings.defaults,
        updatedAt: DateTime.utc(2026, 4, 4, 12),
        includeApiKeys: false,
      ),
      books: [
        SyncSnapshotBookState(
          syncKey: 'epub-sha256:clear-me',
          highlights: [
            SyncSnapshotHighlight(
              chapterIndex: 0,
              selectedText: 'keep this',
              colorHex: '#333333',
              createdAt: DateTime.utc(2026, 2, 1),
            ),
          ],
        ),
      ],
    );

    await snapshotService.importSnapshotJson(
      snapshot.toJson(),
      clearMissingBookState: true,
    );

    final progress = await databaseService.getProgressByBookId(localBook.id!);
    final marker = await databaseService.getResumeMarkerByBookId(localBook.id!);
    final highlights =
        await databaseService.getHighlightsByBookId(localBook.id!);

    expect(progress, isNull);
    expect(marker, isNull);
    expect(highlights, hasLength(1));
    expect(highlights.single.selectedText, 'keep this');
    expect(highlights.single.colorHex, '#333333');
  });

  test('overwriteMatchingBookState forces remote state over newer local data',
      () async {
    final localBook = await databaseService.insertBook(
      Book(
        syncKey: 'epub-sha256:overwrite',
        title: 'Local Book',
        author: 'Author',
        filePath: '/tmp/overwrite.epub',
        totalChapters: 3,
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    );

    await databaseService.upsertProgress(
      ReadingProgress(
        bookId: localBook.id!,
        chapterIndex: 2,
        scrollOffset: 99,
        updatedAt: DateTime.utc(2026, 3, 1),
      ),
    );
    await databaseService.upsertResumeMarker(
      ResumeMarker(
        bookId: localBook.id!,
        chapterIndex: 2,
        selectedText: 'New local marker',
        selectionStart: 0,
        selectionEnd: 5,
        scrollOffset: 20,
        createdAt: DateTime.utc(2026, 3, 1),
      ),
    );
    await databaseService.addHighlight(
      Highlight(
        bookId: localBook.id!,
        chapterIndex: 0,
        selectedText: 'shared',
        colorHex: '#999999',
        createdAt: DateTime.utc(2026, 3, 1),
      ),
    );

    final snapshot = SyncSnapshot(
      exportedAt: DateTime.utc(2026, 4, 4, 12),
      settings: SyncSnapshotSettings.fromReaderSettings(
        ReaderSettings.defaults,
        updatedAt: DateTime.utc(2026, 4, 4, 12),
        includeApiKeys: false,
      ),
      books: [
        SyncSnapshotBookState(
          syncKey: 'epub-sha256:overwrite',
          progress: SyncSnapshotProgress(
            chapterIndex: 1,
            scrollOffset: 10,
            updatedAt: DateTime.utc(2026, 2, 1),
          ),
          resumeMarker: SyncSnapshotResumeMarker(
            chapterIndex: 1,
            selectedText: 'Older remote marker',
            selectionStart: 0,
            selectionEnd: 5,
            scrollOffset: 8,
            createdAt: DateTime.utc(2026, 2, 1),
          ),
          highlights: [
            SyncSnapshotHighlight(
              chapterIndex: 0,
              selectedText: 'shared',
              colorHex: '#333333',
              createdAt: DateTime.utc(2026, 2, 1),
            ),
          ],
        ),
      ],
    );

    await snapshotService.importSnapshot(
      snapshot,
      overwriteMatchingBookState: true,
    );

    final progress = await databaseService.getProgressByBookId(localBook.id!);
    final marker = await databaseService.getResumeMarkerByBookId(localBook.id!);
    final highlights =
        await databaseService.getHighlightsByBookId(localBook.id!);

    expect(progress?.chapterIndex, 1);
    expect(progress?.scrollOffset, 10);
    expect(marker?.selectedText, 'Older remote marker');
    expect(marker?.scrollOffset, 8);
    expect(highlights.single.colorHex, '#333333');
  });
}
