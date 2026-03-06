import '../models/book.dart';
import '../models/chapter.dart';
import 'database_service.dart';
import 'epub_service.dart';

typedef StoredChapterReader = Future<List<Chapter>> Function(int bookId);
typedef StoredChapterWriter = Future<void> Function(
  int bookId,
  List<Chapter> chapters,
);
typedef ChapterParser = Future<List<Chapter>> Function(String filePath);
typedef ChapterCacheWriter = void Function(
  String filePath,
  List<Chapter> chapters,
);

/// Loads chapters from persistent storage first, falling back to EPUB parsing.
class ChapterLoaderService {
  ChapterLoaderService({
    StoredChapterReader? readStoredChapters,
    StoredChapterWriter? writeStoredChapters,
    ChapterParser? parseChapters,
    ChapterCacheWriter? cacheChapters,
  })  : _readStoredChapters =
            readStoredChapters ?? DatabaseService.instance.getChaptersByBookId,
        _writeStoredChapters = writeStoredChapters ??
            DatabaseService.instance.replaceChaptersForBook,
        _parseChapters = parseChapters ?? EpubService.instance.parseChapters,
        _cacheChapters = cacheChapters ?? EpubService.instance.cacheChapters;

  static final ChapterLoaderService instance = ChapterLoaderService();

  final StoredChapterReader _readStoredChapters;
  final StoredChapterWriter _writeStoredChapters;
  final ChapterParser _parseChapters;
  final ChapterCacheWriter _cacheChapters;

  Future<List<Chapter>> loadChapters(Book book) async {
    final bookId = book.id;
    if (bookId != null) {
      final stored = await _readStoredChapters(bookId);
      if (stored.isNotEmpty) {
        _cacheChapters(book.filePath, stored);
        return stored;
      }
    }

    final parsed = await _parseChapters(book.filePath);

    if (bookId != null && parsed.isNotEmpty) {
      await _writeStoredChapters(bookId, parsed);
    }

    return parsed;
  }
}
