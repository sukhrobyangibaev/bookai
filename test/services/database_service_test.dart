import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:bookai/models/book.dart';
import 'package:bookai/models/chapter.dart';
import 'package:bookai/models/generated_image.dart';
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

  test('openDatabaseAt migrates version 4 databases to version 5', () async {
    final oldDb = await openDatabase(
      databasePath,
      version: 4,
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
        await db.execute('''
          CREATE TABLE highlights (
            id           INTEGER PRIMARY KEY AUTOINCREMENT,
            bookId       INTEGER NOT NULL,
            chapterIndex INTEGER NOT NULL,
            selectedText TEXT    NOT NULL,
            colorHex     TEXT    NOT NULL,
            createdAt    TEXT    NOT NULL,
            FOREIGN KEY (bookId) REFERENCES books(id) ON DELETE CASCADE
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_highlights_bookId ON highlights(bookId)',
        );
        await db.execute('''
          CREATE TABLE resume_markers (
            bookId         INTEGER PRIMARY KEY,
            chapterIndex   INTEGER NOT NULL,
            selectedText   TEXT    NOT NULL,
            selectionStart INTEGER NOT NULL,
            selectionEnd   INTEGER NOT NULL,
            scrollOffset   REAL    NOT NULL DEFAULT 0.0,
            createdAt      TEXT    NOT NULL,
            FOREIGN KEY (bookId) REFERENCES books(id) ON DELETE CASCADE
          )
        ''');
        await db.execute('''
          CREATE TABLE chapters (
            bookId         INTEGER NOT NULL,
            chapterIndex   INTEGER NOT NULL,
            title          TEXT    NOT NULL,
            content        TEXT    NOT NULL,
            PRIMARY KEY (bookId, chapterIndex),
            FOREIGN KEY (bookId) REFERENCES books(id) ON DELETE CASCADE
          )
        ''');
      },
    );
    await oldDb.close();

    final migrated = await service.openDatabaseAt(databasePath);
    addTearDown(() async => migrated.close());

    final chapterColumns =
        await migrated.rawQuery('PRAGMA table_info(chapters)');
    expect(chapterColumns, isNotEmpty);
    final generatedImageColumns =
        await migrated.rawQuery('PRAGMA table_info(generated_images)');
    expect(generatedImageColumns, isNotEmpty);

    await migrated.insert('books', {
      'id': 1,
      'title': 'Migrated Book',
      'author': 'Author',
      'filePath': '/tmp/migrated.epub',
      'coverPath': null,
      'totalChapters': 1,
      'createdAt': DateTime.utc(2025, 1, 3).toIso8601String(),
    });
    await migrated.insert('chapters', {
      'bookId': 1,
      'chapterIndex': 0,
      'title': 'Chapter 1',
      'content': 'Stored content',
    });
    await migrated.insert('generated_images', {
      'bookId': 1,
      'chapterIndex': 0,
      'featureMode': 'resume_range',
      'sourceText': 'Stored source',
      'promptText': 'Stored prompt',
      'filePath': '/tmp/generated.png',
      'createdAt': DateTime.utc(2025, 1, 6).toIso8601String(),
    });

    await migrated.delete('books', where: 'id = ?', whereArgs: [1]);

    final remainingChapters = await migrated.query('chapters');
    final remainingGeneratedImages = await migrated.query('generated_images');
    expect(remainingChapters, isEmpty);
    expect(remainingGeneratedImages, isEmpty);
  });
}
