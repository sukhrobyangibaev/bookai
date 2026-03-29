import 'dart:io';

import 'package:bookai/services/database_service.dart';
import 'package:bookai/services/library_service.dart';
import 'package:bookai/services/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory tempDir;
  late String databasePath;
  final db = DatabaseService.instance;
  final storage = StorageService.instance;
  final library = LibraryService.instance;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('bookai_library_test_');
    databasePath = p.join(tempDir.path, 'bookai_library.db');

    await db.resetForTesting(databasePath: databasePath);
    await storage.resetForTesting(
      documentsDirectoryProvider: () async => tempDir,
    );
  });

  tearDown(() async {
    await db.resetForTesting();
    await storage.resetForTesting();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('LibraryService.importPastedText', () {
    test('uses defaults and stores a single chapter', () async {
      final saved = await library.importPastedText(
        text: '\n\nMy Story\r\n\r\nLine two.\nLine three.\n',
      );

      expect(saved.id, isNotNull);
      expect(saved.title, 'My Story');
      expect(saved.author, 'Unknown Author');
      expect(saved.totalChapters, 1);
      expect(saved.filePath, contains('pasted_'));
      expect(saved.filePath, endsWith('.bookai'));

      final chapters = await db.getChaptersByBookId(saved.id!);
      expect(chapters, hasLength(1));
      expect(chapters.single.index, 0);
      expect(chapters.single.title, 'Chapter 1');
      expect(chapters.single.content, 'My Story\n\nLine two.\nLine three.');
    });

    test('respects provided title and author', () async {
      final saved = await library.importPastedText(
        title: 'Custom Title',
        author: 'Custom Author',
        text: 'Body text',
      );

      expect(saved.title, 'Custom Title');
      expect(saved.author, 'Custom Author');
    });

    test('throws when pasted text is empty', () async {
      expect(
        () => library.importPastedText(text: '   \n\r\n\t  '),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            'Pasted text is empty.',
          ),
        ),
      );
    });
  });
}
