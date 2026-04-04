import 'package:bookai/models/ai_feature.dart';
import 'package:bookai/models/ai_feature_config.dart';
import 'package:bookai/models/ai_model_selection.dart';
import 'package:bookai/models/ai_provider.dart';
import 'package:bookai/models/reader_settings.dart';
import 'package:bookai/models/sync_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SyncSnapshot', () {
    test('round-trips versioned JSON and omits API keys when excluded', () {
      final snapshot = SyncSnapshot(
        exportedAt: DateTime.utc(2026, 4, 4, 12),
        settings: SyncSnapshotSettings(
          updatedAt: DateTime.utc(2026, 4, 4, 11),
          fontSize: 22,
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
              promptTemplate: 'Use {source_text}',
            ),
          },
        ),
        books: [
          SyncSnapshotBookState(
            syncKey: 'epub-sha256:abc123',
            progress: SyncSnapshotProgress(
              chapterIndex: 4,
              scrollOffset: 128.5,
              updatedAt: DateTime.utc(2026, 4, 4, 10),
            ),
            resumeMarker: SyncSnapshotResumeMarker(
              chapterIndex: 3,
              selectedText: 'Resume here',
              selectionStart: 10,
              selectionEnd: 21,
              scrollOffset: 80,
              createdAt: DateTime.utc(2026, 4, 4, 9),
            ),
            highlights: [
              SyncSnapshotHighlight(
                chapterIndex: 2,
                selectedText: 'Important line',
                colorHex: '#FFF59D',
                createdAt: DateTime.utc(2026, 4, 4, 8),
              ),
            ],
          ),
        ],
      );

      final encoded = snapshot.toJson();
      final decoded = SyncSnapshot.fromJson(encoded);
      final settingsMap = decoded.toMap()['settings'] as Map<String, dynamic>;

      expect(decoded.schemaVersion, SyncSnapshot.currentSchemaVersion);
      expect(decoded.exportedAt, snapshot.exportedAt);
      expect(decoded.settings.updatedAt, snapshot.settings.updatedAt);
      expect(decoded.settings.fontSize, 22);
      expect(decoded.settings.themeMode, AppThemeMode.sepia);
      expect(decoded.books, hasLength(1));
      expect(decoded.books.single.syncKey, 'epub-sha256:abc123');
      expect(decoded.books.single.progress?.chapterIndex, 4);
      expect(decoded.books.single.resumeMarker?.selectedText, 'Resume here');
      expect(decoded.books.single.highlights.single.selectedText,
          'Important line');
      expect(settingsMap.containsKey('openRouterApiKey'), isFalse);
      expect(settingsMap.containsKey('geminiApiKey'), isFalse);
    });

    test('rejects unsupported schema versions', () {
      expect(
        () => SyncSnapshot.fromMap({
          'schemaVersion': 99,
          'exportedAt': DateTime.utc(2026, 4, 4).toIso8601String(),
          'settings': ReaderSettings.defaults.toMap()
            ..['updatedAt'] = DateTime.utc(2026, 4, 4).toIso8601String(),
          'books': const [],
        }),
        throwsFormatException,
      );
    });
  });
}
