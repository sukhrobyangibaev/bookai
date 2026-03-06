import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:bookai/app.dart';
import 'package:bookai/services/database_service.dart';
import 'package:bookai/services/settings_controller.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  late Directory tempDir;
  late String databasePath;

  // Initialize FFI-based SQLite for desktop/test environment.
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(() async {
    await DatabaseService.instance.resetForTesting();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('LibraryScreen', () {
    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('bookai_widget_test_');
      databasePath = p.join(tempDir.path, 'bookai_test.db');
      await DatabaseService.instance
          .resetForTesting(databasePath: databasePath);
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
