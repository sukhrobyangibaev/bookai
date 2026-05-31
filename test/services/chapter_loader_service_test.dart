import 'package:flutter_test/flutter_test.dart';

import 'package:bookai/models/book.dart';
import 'package:bookai/models/chapter.dart';
import 'package:bookai/models/chapter_style.dart';
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
        Chapter(
          bookId: 42,
          index: 0,
          title: 'Stored',
          content: 'From DB',
          styledContentJson: '{"version":1,"ranges":[]}',
        ),
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

    test('reparses stored EPUB chapters when styled content is missing',
        () async {
      var parseCalls = 0;
      var persistedBookId = -1;
      List<Chapter>? persistedChapters;
      var cachedPath = '';
      List<Chapter>? cachedChapters;

      const storedChapters = [
        Chapter(bookId: 42, index: 0, title: 'Stored', content: 'Plain text'),
      ];
      final parsedChapters = [
        Chapter(
          index: 0,
          title: 'Parsed',
          content: 'Styled text',
          styledContentJson: const StyledChapterContent().toJson(),
        ),
      ];

      final service = ChapterLoaderService(
        readStoredChapters: (_) async => storedChapters,
        writeStoredChapters: (bookId, chapters) async {
          persistedBookId = bookId;
          persistedChapters = chapters;
        },
        parseChapters: (filePath) async {
          parseCalls++;
          expect(filePath, sampleBook.filePath);
          return parsedChapters;
        },
        cacheChapters: (filePath, chapters) {
          cachedPath = filePath;
          cachedChapters = chapters;
        },
      );

      final result = await service.loadChapters(sampleBook);

      expect(result, same(parsedChapters));
      expect(parseCalls, 1);
      expect(persistedBookId, sampleBook.id);
      expect(persistedChapters, same(parsedChapters));
      expect(cachedPath, sampleBook.filePath);
      expect(cachedChapters, same(parsedChapters));
    });

    test('does not reparse stored EPUB chapters with styled content', () async {
      var parseCalls = 0;
      final storedChapters = [
        Chapter(
          bookId: 42,
          index: 0,
          title: 'Stored',
          content: 'Styled text',
          styledContentJson: const StyledChapterContent().toJson(),
        ),
      ];

      final service = ChapterLoaderService(
        readStoredChapters: (_) async => storedChapters,
        writeStoredChapters: (_, __) async {
          fail('Styled chapters should not be written again.');
        },
        parseChapters: (_) async {
          parseCalls++;
          return const [];
        },
        cacheChapters: (_, __) {},
      );

      final result = await service.loadChapters(sampleBook);

      expect(result, same(storedChapters));
      expect(parseCalls, 0);
    });

    test('falls back to stored plain chapters when style refresh fails',
        () async {
      var writeCalls = 0;
      List<Chapter>? cachedChapters;
      const storedChapters = [
        Chapter(bookId: 42, index: 0, title: 'Stored', content: 'Plain text'),
      ];

      final service = ChapterLoaderService(
        readStoredChapters: (_) async => storedChapters,
        writeStoredChapters: (_, __) async {
          writeCalls++;
        },
        parseChapters: (_) async => throw const FormatException('bad epub'),
        cacheChapters: (_, chapters) {
          cachedChapters = chapters;
        },
      );

      final result = await service.loadChapters(sampleBook);

      expect(result, same(storedChapters));
      expect(writeCalls, 0);
      expect(cachedChapters, same(storedChapters));
    });
  });
}
