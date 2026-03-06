import 'package:flutter_test/flutter_test.dart';

import 'package:bookai/models/book.dart';
import 'package:bookai/models/chapter.dart';
import 'package:bookai/services/chapter_loader_service.dart';

void main() {
  final sampleBook = Book(
    id: 42,
    title: 'Sample',
    author: 'Author',
    filePath: '/tmp/sample.epub',
    totalChapters: 0,
    createdAt: DateTime.utc(2025, 1, 1),
  );

  group('ChapterLoaderService', () {
    test('returns stored chapters without reparsing', () async {
      var parserCalled = false;
      var cachedPath = '';
      List<Chapter>? cachedChapters;

      const storedChapters = [
        Chapter(bookId: 42, index: 0, title: 'Stored', content: 'From DB'),
      ];

      final service = ChapterLoaderService(
        readStoredChapters: (bookId) async {
          expect(bookId, 42);
          return storedChapters;
        },
        writeStoredChapters: (_, __) async {
          fail('Stored chapters should not be written again.');
        },
        parseChapters: (_) async {
          parserCalled = true;
          return const [];
        },
        cacheChapters: (filePath, chapters) {
          cachedPath = filePath;
          cachedChapters = chapters;
        },
      );

      final result = await service.loadChapters(sampleBook);

      expect(result, same(storedChapters));
      expect(parserCalled, isFalse);
      expect(cachedPath, sampleBook.filePath);
      expect(cachedChapters, same(storedChapters));
    });

    test('parses and persists chapters when storage is empty', () async {
      var persistedBookId = -1;
      List<Chapter>? persistedChapters;

      const parsedChapters = [
        Chapter(index: 0, title: 'Parsed', content: 'From EPUB'),
      ];

      final service = ChapterLoaderService(
        readStoredChapters: (_) async => const [],
        writeStoredChapters: (bookId, chapters) async {
          persistedBookId = bookId;
          persistedChapters = chapters;
        },
        parseChapters: (filePath) async {
          expect(filePath, sampleBook.filePath);
          return parsedChapters;
        },
        cacheChapters: (_, __) {},
      );

      final result = await service.loadChapters(sampleBook);

      expect(result, same(parsedChapters));
      expect(persistedBookId, sampleBook.id);
      expect(persistedChapters, same(parsedChapters));
    });

    test('does not persist parsed chapters for books without ids', () async {
      var writeCalls = 0;

      final unsavedBook = Book(
        title: sampleBook.title,
        author: sampleBook.author,
        filePath: sampleBook.filePath,
        totalChapters: sampleBook.totalChapters,
        createdAt: sampleBook.createdAt,
      );

      final service = ChapterLoaderService(
        readStoredChapters: (_) async => const [],
        writeStoredChapters: (_, __) async {
          writeCalls++;
        },
        parseChapters: (_) async => const [
          Chapter(index: 0, title: 'Parsed', content: 'Unsaved'),
        ],
        cacheChapters: (_, __) {},
      );

      final result = await service.loadChapters(unsavedBook);

      expect(result, isNotEmpty);
      expect(writeCalls, 0);
    });
  });
}
