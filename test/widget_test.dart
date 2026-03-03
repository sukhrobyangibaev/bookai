import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:bookai/app.dart';
import 'package:bookai/services/database_service.dart';
import 'package:bookai/services/settings_controller.dart';

void main() {
  // Initialize FFI-based SQLite for desktop/test environment.
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('LibraryScreen', () {
    setUp(() async {
      // Ensure test isolation: library empty-state expectations require no books.
      final db = await DatabaseService.instance.database;
      await db.delete('resume_markers');
      await db.delete('progress');
      await db.delete('highlights');
      await db.delete('books');
    });

    testWidgets('empty state shows correct elements and import buttons',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});

      // Pre-initialize the database so _loadBooks doesn't block on DB init.
      await tester.runAsync(() async {
        await DatabaseService.instance.database;
      });

      final controller = SettingsController();
      await tester.runAsync(() => controller.load());

      await tester.pumpWidget(BookAiApp(settingsController: controller));

      // Pump and flush async work in a loop to let _loadBooks() complete.
      for (int i = 0; i < 10; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pump();
      }

      // ── App bar ──────────────────────────────────────────────────────────
      expect(find.text('BookAI Library'), findsOneWidget);
      expect(find.byIcon(Icons.settings_outlined), findsOneWidget);

      // ── Empty state content ──────────────────────────────────────────────
      expect(find.byIcon(Icons.auto_stories_outlined), findsOneWidget);
      expect(find.text('Your library is empty'), findsOneWidget);
      expect(
        find.text(
          'Import an EPUB file to start reading.\n'
          'Your books, progress, and highlights are stored locally.',
        ),
        findsOneWidget,
      );

      // ── Import CTA button in empty state ─────────────────────────────────
      expect(find.text('Import Your First Book'), findsOneWidget);

      // ── FAB ──────────────────────────────────────────────────────────────
      expect(find.text('Import EPUB'), findsOneWidget);
      final fab = tester.widget<FloatingActionButton>(
        find.byType(FloatingActionButton),
      );
      expect(fab.onPressed, isNotNull);

      // ── No loading indicator (data has loaded) ───────────────────────────
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });
}
