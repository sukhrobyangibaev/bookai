import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:bookai/models/book.dart';
import 'package:bookai/models/chapter.dart';
import 'package:bookai/models/generated_image.dart';
import 'package:bookai/models/reading_progress.dart';
import 'package:bookai/services/database_service.dart';

void main() {
  late Directory tempDir;
  late String databasePath;
  final service = DatabaseService.instance;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('bookai_db_test_');
    databasePath = p.join(tempDir.path, 'bookai.db');
    await service.resetForTesting(databasePath: databasePath);
  });

  tearDown(() async {
    await service.resetForTesting();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('DatabaseService chapters', () {
    test('replaceChaptersForBook stores chapters ordered by chapter index',
        () async {
      final book = await service.insertBook(
        Book(
          title: 'Persisted Book',
          author: 'Author',
          filePath: '/tmp/persisted.epub',
          totalChapters: 0,
          createdAt: DateTime.utc(2025, 1, 1),
        ),
      );

      await service.replaceChaptersForBook(book.id!, const [
        Chapter(index: 2, title: 'Three', content: 'Third'),
        Chapter(index: 0, title: 'One', content: 'First'),
        Chapter(index: 1, title: 'Two', content: 'Second'),
      ]);

      final chapters = await service.getChaptersByBookId(book.id!);

      expect(chapters.map((chapter) => chapter.index).toList(), [0, 1, 2]);
      expect(chapters.map((chapter) => chapter.title).toList(), [
        'One',
        'Two',
        'Three',
      ]);
      expect(chapters.every((chapter) => chapter.bookId == book.id), isTrue);
    });

    test('deleteBook cascades to persisted chapters', () async {
      final book = await service.insertBook(
        Book(
          title: 'Cascade Book',
          author: 'Author',
          filePath: '/tmp/cascade.epub',
          totalChapters: 1,
          createdAt: DateTime.utc(2025, 1, 2),
        ),
      );

      await service.replaceChaptersForBook(book.id!, const [
        Chapter(index: 0, title: 'Chapter 1', content: 'Stored text'),
      ]);

      await service.deleteBook(book.id!);

      expect(await service.getChaptersByBookId(book.id!), isEmpty);
    });
  });

  group('DatabaseService reading progress', () {
    test('stores and loads contentOffset in progress', () async {
      final book = await service.insertBook(
        Book(
          title: 'Progress Book',
          author: 'Author',
          filePath: '/tmp/progress.epub',
          totalChapters: 2,
          createdAt: DateTime.utc(2025, 1, 9),
        ),
      );

      await service.upsertProgress(
        ReadingProgress(
          bookId: book.id!,
          chapterIndex: 1,
          scrollOffset: 42.5,
          contentOffset: 314,
          updatedAt: DateTime.utc(2025, 1, 10),
        ),
      );

      final progress = await service.getProgressByBookId(book.id!);

      expect(progress, isNotNull);
      expect(progress!.chapterIndex, 1);
      expect(progress.scrollOffset, 42.5);
      expect(progress.contentOffset, 314);
    });

    test('stores and loads null contentOffset in progress', () async {
      final book = await service.insertBook(
        Book(
          title: 'Null Progress Book',
          author: 'Author',
          filePath: '/tmp/progress-null.epub',
          totalChapters: 2,
          createdAt: DateTime.utc(2025, 1, 11),
        ),
      );

      await service.upsertProgress(
        ReadingProgress(
          bookId: book.id!,
          chapterIndex: 0,
          scrollOffset: 10.0,
          contentOffset: null,
          updatedAt: DateTime.utc(2025, 1, 12),
        ),
      );

      final progress = await service.getProgressByBookId(book.id!);

      expect(progress, isNotNull);
      expect(progress!.contentOffset, isNull);
    });
  });

  test('stores and cascades generated images', () async {
    final book = await service.insertBook(
      Book(
        title: 'Images Book',
        author: 'Author',
        filePath: '/tmp/images.epub',
        totalChapters: 1,
        createdAt: DateTime.utc(2025, 1, 4),
      ),
    );

    final savedImage = await service.addGeneratedImage(
      GeneratedImage(
        bookId: book.id!,
        chapterIndex: 0,
        featureMode: 'selected_text',
        sourceText: 'The moon over the harbor.',
        promptText: 'A moonlit harbor in watercolor.',
        name: 'Moonlit Harbor',
        filePath: '/tmp/generated.png',
        createdAt: DateTime.utc(2025, 1, 5),
      ),
    );

    final images = await service.getAllGeneratedImages();
    expect(images, hasLength(1));
    expect(images.single, savedImage);

    await service.deleteBook(book.id!);

    expect(await service.getGeneratedImagesByBookId(book.id!), isEmpty);
  });

  test('updates generated image name', () async {
    final book = await service.insertBook(
      Book(
        title: 'Rename Book',
        author: 'Author',
        filePath: '/tmp/rename.epub',
        totalChapters: 1,
        createdAt: DateTime.utc(2025, 1, 7),
      ),
    );

    final savedImage = await service.addGeneratedImage(
      GeneratedImage(
        bookId: book.id!,
        chapterIndex: 0,
        featureMode: 'selected_text',
        sourceText: 'A storm over the city.',
        promptText: 'Storm clouds above a city skyline.',
        filePath: '/tmp/rename.png',
        createdAt: DateTime.utc(2025, 1, 8),
      ),
    );

    await service.updateGeneratedImageName(savedImage.id!, 'City Storm');
    var images = await service.getGeneratedImagesByBookId(book.id!);
    expect(images.single.name, 'City Storm');

    await service.updateGeneratedImageName(savedImage.id!, null);
    images = await service.getGeneratedImagesByBookId(book.id!);
    expect(images.single.name, isNull);
  });

  test('openDatabaseAt migrates version 5 databases to version 7', () async {
    final oldDb = await openDatabase(
      databasePath,
      version: 5,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE books (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            title       TEXT    NOT NULL,
            author      TEXT    NOT NULL,
            filePath    TEXT    NOT NULL UNIQUE,
            coverPath   TEXT,
            totalChapters INTEGER NOT NULL DEFAULT 0,
            createdAt   TEXT    NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE generated_images (
            id           INTEGER PRIMARY KEY AUTOINCREMENT,
            bookId       INTEGER NOT NULL,
            chapterIndex INTEGER NOT NULL,
            featureMode  TEXT    NOT NULL,
            sourceText   TEXT    NOT NULL,
            promptText   TEXT    NOT NULL,
            filePath     TEXT    NOT NULL,
            createdAt    TEXT    NOT NULL,
            FOREIGN KEY (bookId) REFERENCES books(id) ON DELETE CASCADE
          )
        ''');
        await db.insert('books', {
          'id': 1,
          'title': 'Migrated Book',
          'author': 'Author',
          'filePath': '/tmp/migrated.epub',
          'coverPath': null,
          'totalChapters': 1,
          'createdAt': DateTime.utc(2025, 1, 3).toIso8601String(),
        });
        await db.insert('generated_images', {
          'bookId': 1,
          'chapterIndex': 0,
          'featureMode': 'resume_range',
          'sourceText': 'Stored source',
          'promptText': 'Stored prompt',
          'filePath': '/tmp/generated.png',
          'createdAt': DateTime.utc(2025, 1, 6).toIso8601String(),
        });
      },
    );
    await oldDb.close();

    final migrated = await service.openDatabaseAt(databasePath);
    addTearDown(() async => migrated.close());

    final generatedImageColumns =
        await migrated.rawQuery('PRAGMA table_info(generated_images)');
    expect(generatedImageColumns, isNotEmpty);
    expect(
      generatedImageColumns.any((column) => column['name'] == 'name'),
      isTrue,
    );

    final migratedImages = await migrated.query('generated_images');
    expect(migratedImages, hasLength(1));
    expect(migratedImages.single['name'], isNull);

    await migrated.delete('books', where: 'id = ?', whereArgs: [1]);

    final remainingGeneratedImages = await migrated.query('generated_images');
    expect(remainingGeneratedImages, isEmpty);
  });

  test('openDatabaseAt migrates version 6 progress table to version 7',
      () async {
    final oldDb = await openDatabase(
      databasePath,
      version: 6,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE books (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            title       TEXT    NOT NULL,
            author      TEXT    NOT NULL,
            filePath    TEXT    NOT NULL UNIQUE,
            coverPath   TEXT,
            totalChapters INTEGER NOT NULL DEFAULT 0,
            createdAt   TEXT    NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE progress (
            bookId        INTEGER PRIMARY KEY,
            chapterIndex  INTEGER NOT NULL DEFAULT 0,
            scrollOffset  REAL    NOT NULL DEFAULT 0.0,
            updatedAt     TEXT    NOT NULL,
            FOREIGN KEY (bookId) REFERENCES books(id) ON DELETE CASCADE
          )
        ''');
        await db.insert('books', {
          'id': 1,
          'title': 'Migrated Progress Book',
          'author': 'Author',
          'filePath': '/tmp/migrated-progress.epub',
          'coverPath': null,
          'totalChapters': 3,
          'createdAt': DateTime.utc(2025, 1, 13).toIso8601String(),
        });
        await db.insert('progress', {
          'bookId': 1,
          'chapterIndex': 2,
          'scrollOffset': 88.0,
          'updatedAt': DateTime.utc(2025, 1, 14).toIso8601String(),
        });
      },
    );
    await oldDb.close();

    final migrated = await service.openDatabaseAt(databasePath);
    addTearDown(() async => migrated.close());

    final progressColumns =
        await migrated.rawQuery('PRAGMA table_info(progress)');
    expect(progressColumns, isNotEmpty);
    expect(
      progressColumns.any((column) => column['name'] == 'contentOffset'),
      isTrue,
    );

    final migratedProgress = await migrated.query('progress');
    expect(migratedProgress, hasLength(1));
    expect(migratedProgress.single['bookId'], 1);
    expect(migratedProgress.single['chapterIndex'], 2);
    expect(migratedProgress.single['scrollOffset'], 88.0);
    expect(migratedProgress.single['contentOffset'], isNull);
  });
}
