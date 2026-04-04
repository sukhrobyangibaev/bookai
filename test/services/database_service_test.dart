import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:bookai/models/book.dart';
import 'package:bookai/models/chapter.dart';
import 'package:bookai/models/generated_image.dart';
import 'package:bookai/services/book_sync_identity_service.dart';
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

  test('openDatabaseAt migrates version 5 databases to version 6', () async {
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

  test('openDatabaseAt migrates version 6 databases to version 7', () async {
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
      },
    );
    await oldDb.close();

    final migrated = await service.openDatabaseAt(databasePath);
    addTearDown(() async => migrated.close());

    final columns =
        await migrated.rawQuery('PRAGMA table_info(ai_request_logs)');
    expect(columns, isNotEmpty);
    expect(columns.any((column) => column['name'] == 'provider'), isTrue);
    expect(columns.any((column) => column['name'] == 'requestBody'), isTrue);
    expect(columns.any((column) => column['name'] == 'responseBody'), isTrue);

    final indexes = await migrated.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'index'",
    );
    expect(
      indexes.any(
        (index) => index['name'] == 'idx_ai_request_logs_createdAt',
      ),
      isTrue,
    );
  });

  test(
      'openDatabaseAt migrates version 7 databases to version 8 and backfills sync keys',
      () async {
    final existingEpub = File(p.join(tempDir.path, 'migrated.epub'));
    await existingEpub.writeAsString('same epub bytes on every device');
    final expectedSyncKey = BookSyncIdentityService.instance
        .computeSyncKeyForBytes(await existingEpub.readAsBytes());

    final oldDb = await openDatabase(
      databasePath,
      version: 7,
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
        await db.insert('books', {
          'id': 1,
          'title': 'Migrated Book',
          'author': 'Author',
          'filePath': existingEpub.path,
          'coverPath': null,
          'totalChapters': 1,
          'createdAt': DateTime.utc(2025, 2, 1).toIso8601String(),
        });
        await db.insert('books', {
          'id': 2,
          'title': 'Pasted Book',
          'author': 'Author',
          'filePath': p.join(tempDir.path, 'pasted_123.bookai'),
          'coverPath': null,
          'totalChapters': 1,
          'createdAt': DateTime.utc(2025, 2, 2).toIso8601String(),
        });
      },
    );
    await oldDb.close();

    final migrated = await service.openDatabaseAt(databasePath);
    addTearDown(() async => migrated.close());

    final bookColumns = await migrated.rawQuery('PRAGMA table_info(books)');
    expect(bookColumns.any((column) => column['name'] == 'syncKey'), isTrue);

    final bookIndexes = await migrated.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'index' AND tbl_name = 'books'",
    );
    expect(
      bookIndexes.any((index) => index['name'] == 'idx_books_syncKey'),
      isTrue,
    );

    final migratedBook = await service.getBookByFilePath(existingEpub.path);
    expect(migratedBook?.syncKey, expectedSyncKey);

    final pastedBook = await service
        .getBookByFilePath(p.join(tempDir.path, 'pasted_123.bookai'));
    expect(pastedBook?.syncKey, isNull);

    final bySyncKey = await service.getBookBySyncKey(expectedSyncKey);
    expect(bySyncKey?.id, migratedBook?.id);
  });

  test('ai request logs support pagination, count, and clear', () async {
    final db = await service.database;

    for (var i = 0; i < 3; i++) {
      await db.insert('ai_request_logs', {
        'createdAt': DateTime.utc(2026, 3, 29, 16, 0, i).toIso8601String(),
        'provider': 'openrouter',
        'requestKind': 'chat_generation',
        'attempt': 1,
        'method': 'POST',
        'url': 'https://example.com/$i',
        'requestHeaders': '{}',
        'requestBody': '{"i":$i}',
      });
    }

    final count = await service.countAiRequestLogEntries();
    expect(count, 3);

    final page = await service.getAiRequestLogEntries(limit: 2, offset: 1);
    expect(page, hasLength(2));
    expect(page.first.url, 'https://example.com/1');
    expect(page.last.url, 'https://example.com/0');

    final removed = await service.clearAiRequestLogEntries();
    expect(removed, 3);
    expect(await service.countAiRequestLogEntries(), 0);
  });
}
