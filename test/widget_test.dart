import 'dart:convert';
import 'dart:io';

import 'package:bookai/models/book.dart';
import 'package:bookai/models/generated_image.dart';
import 'package:bookai/models/reader_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:bookai/app.dart';
import 'package:bookai/screens/library_screen.dart';
import 'package:bookai/services/database_service.dart';
import 'package:bookai/services/settings_controller.dart';
import 'package:bookai/services/storage_service.dart';

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
    await StorageService.instance.resetForTesting();
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
      await StorageService.instance.resetForTesting(
        documentsDirectoryProvider: () async => tempDir,
      );
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
      expect(find.text('Books'), findsOneWidget);
      expect(find.text('Images'), findsOneWidget);

      // ── Empty state content ──────────────────────────────────────────────
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Icon &&
              widget.icon == Icons.auto_stories_outlined &&
              widget.size == 96,
        ),
        findsOneWidget,
      );
      expect(find.text('Your library is empty'), findsOneWidget);
      expect(
        find.text(
          'Import an EPUB file to start reading.\n'
          'Your books, progress, highlights, and generated images are stored locally.',
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

    testWidgets('images tab shows generated image empty state',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.runAsync(() async {
        await DatabaseService.instance.database;
      });

      final controller = SettingsController();
      await tester.runAsync(() => controller.load());

      await tester.pumpWidget(BookAiApp(settingsController: controller));

      for (int i = 0; i < 10; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
      }

      await tester.tap(find.text('Images'));
      await tester.pumpAndSettle();

      expect(find.text('No generated images yet'), findsOneWidget);
      expect(
        find.text(
          'Generate an image from the reader and it will appear here for the book it belongs to.',
        ),
        findsOneWidget,
      );
      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets('system theme follows platform brightness',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      addTearDown(tester.platformDispatcher.clearAllTestValues);

      await tester.runAsync(() async {
        await DatabaseService.instance.database;
      });

      final controller = SettingsController();
      await tester.runAsync(() => controller.load());
      await controller.setThemeMode(AppThemeMode.system);

      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      await tester.pumpWidget(BookAiApp(settingsController: controller));
      for (int i = 0; i < 5; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
      }

      expect(
        Theme.of(tester.element(find.byType(LibraryScreen))).brightness,
        Brightness.light,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await tester.pumpWidget(BookAiApp(settingsController: controller));
      for (int i = 0; i < 2; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
      }

      expect(
        Theme.of(tester.element(find.byType(LibraryScreen))).brightness,
        Brightness.dark,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('library image detail shows file size and opens zoom viewer',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.runAsync(() async {
        final imageFile = File(p.join(tempDir.path, 'generated.png'));
        await imageFile.writeAsBytes(base64Decode(_transparentPngBase64));

        final book = await DatabaseService.instance.insertBook(
          Book(
            title: 'Image Test Book',
            author: 'Test Author',
            filePath: p.join(tempDir.path, 'image_test.epub'),
            totalChapters: 1,
            createdAt: DateTime(2024, 1, 1),
          ),
        );

        await DatabaseService.instance.addGeneratedImage(
          GeneratedImage(
            bookId: book.id!,
            chapterIndex: 0,
            featureMode: 'selected_text',
            sourceText: 'A moonlit scene.',
            promptText: 'Generated scene prompt',
            filePath: imageFile.path,
            createdAt: DateTime(2024, 1, 1, 12),
          ),
        );
      });

      final controller = SettingsController();
      await tester.runAsync(() => controller.load());

      await tester.pumpWidget(BookAiApp(settingsController: controller));

      for (int i = 0; i < 10; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
      }

      await tester.tap(find.text('Images'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Image Test Book'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('File size:'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey<String>('library-generated-image-preview')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.byKey(const ValueKey<String>('generated-image-viewer')),
        findsOneWidget,
      );
    });

    testWidgets('library image detail hides file size for missing files',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.runAsync(() async {
        final book = await DatabaseService.instance.insertBook(
          Book(
            title: 'Missing File Book',
            author: 'Test Author',
            filePath: p.join(tempDir.path, 'missing_file.epub'),
            totalChapters: 1,
            createdAt: DateTime(2024, 1, 1),
          ),
        );

        await DatabaseService.instance.addGeneratedImage(
          GeneratedImage(
            bookId: book.id!,
            chapterIndex: 0,
            featureMode: 'selected_text',
            sourceText: 'A missing file scene.',
            promptText: 'Missing image prompt',
            filePath: p.join(tempDir.path, 'does_not_exist.png'),
            createdAt: DateTime(2024, 1, 1, 12),
          ),
        );
      });

      final controller = SettingsController();
      await tester.runAsync(() => controller.load());

      await tester.pumpWidget(BookAiApp(settingsController: controller));

      for (int i = 0; i < 10; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
      }

      await tester.tap(find.text('Images'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Missing image prompt'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('File size:'), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('library-generated-image-preview')),
        findsOneWidget,
      );
    });

    testWidgets('library images prefer custom names over book titles',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.runAsync(() async {
        final imageFile = File(p.join(tempDir.path, 'named-generated.png'));
        await imageFile.writeAsBytes(base64Decode(_transparentPngBase64));

        final book = await DatabaseService.instance.insertBook(
          Book(
            title: 'Fallback Book Title',
            author: 'Test Author',
            filePath: p.join(tempDir.path, 'named_image.epub'),
            totalChapters: 1,
            createdAt: DateTime(2024, 1, 2),
          ),
        );

        await DatabaseService.instance.addGeneratedImage(
          GeneratedImage(
            bookId: book.id!,
            chapterIndex: 0,
            featureMode: 'selected_text',
            sourceText: 'A moonlit scene.',
            promptText: 'Generated scene prompt',
            name: 'Moonlit Harbor',
            filePath: imageFile.path,
            createdAt: DateTime(2024, 1, 2, 12),
          ),
        );
      });

      final controller = SettingsController();
      await tester.runAsync(() => controller.load());

      await tester.pumpWidget(BookAiApp(settingsController: controller));

      for (int i = 0; i < 10; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
      }

      await tester.tap(find.text('Images'));
      await tester.pumpAndSettle();

      expect(find.text('Moonlit Harbor'), findsOneWidget);
      expect(find.text('Fallback Book Title'), findsNothing);

      await tester.tap(find.text('Moonlit Harbor'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Moonlit Harbor'), findsWidgets);
      expect(find.text('Fallback Book Title'), findsNothing);
    });

    testWidgets('library rename updates and clears generated image names',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.runAsync(() async {
        final imageFile = File(p.join(tempDir.path, 'rename-generated.png'));
        await imageFile.writeAsBytes(base64Decode(_transparentPngBase64));

        final book = await DatabaseService.instance.insertBook(
          Book(
            title: 'Fallback Image Title',
            author: 'Test Author',
            filePath: p.join(tempDir.path, 'rename_image.epub'),
            totalChapters: 1,
            createdAt: DateTime(2024, 1, 3),
          ),
        );

        await DatabaseService.instance.addGeneratedImage(
          GeneratedImage(
            bookId: book.id!,
            chapterIndex: 0,
            featureMode: 'selected_text',
            sourceText: 'A stormy harbor.',
            promptText: 'Storm prompt',
            name: 'Original Name',
            filePath: imageFile.path,
            createdAt: DateTime(2024, 1, 3, 12),
          ),
        );
      });

      final controller = SettingsController();
      await tester.runAsync(() => controller.load());

      await tester.pumpWidget(BookAiApp(settingsController: controller));

      for (int i = 0; i < 10; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
      }

      await tester.tap(find.text('Images'));
      await tester.pumpAndSettle();

      expect(find.text('Original Name'), findsOneWidget);

      await tester.tap(find.byTooltip('Image options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Renamed Image');
      await tester.tap(find.text('Save'));
      for (int i = 0; i < 10; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();

      expect(find.text('Renamed Image'), findsOneWidget);
      expect(find.text('Original Name'), findsNothing);

      await tester.tap(find.byTooltip('Image options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '');
      await tester.tap(find.text('Save'));
      for (int i = 0; i < 10; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();

      expect(find.text('Fallback Image Title'), findsOneWidget);
      expect(find.text('Renamed Image'), findsNothing);
    });
  });
}

const _transparentPngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO6V1xQAAAAASUVORK5CYII=';
