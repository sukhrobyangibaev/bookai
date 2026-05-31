import 'dart:io';

import 'package:epubx/epubx.dart';

import '../models/chapter.dart';
import 'epub_html_text_extractor.dart';

class ParsedEpub {
  const ParsedEpub({
    required this.title,
    required this.author,
    required this.chapters,
  });

  final String title;
  final String author;
  final List<Chapter> chapters;
}

/// Parses epub files into ordered [Chapter] lists.
///
/// Maintains a simple in-memory cache keyed by file path so that repeated
/// calls within the same session avoid redundant parsing.
class EpubService {
  EpubService._();
  static final EpubService instance = EpubService._();

  /// In-memory chapter cache keyed by absolute file path.
  final Map<String, List<Chapter>> _cache = {};
  static const EpubHtmlTextExtractor _htmlTextExtractor =
      EpubHtmlTextExtractor();

  /// Parses the epub at [filePath] and returns an ordered list of [Chapter]s.
  ///
  /// Results are cached in memory — subsequent calls with the same path return
  /// the cached list immediately.
  Future<List<Chapter>> parseChapters(String filePath) async {
    if (_cache.containsKey(filePath)) {
      return _cache[filePath]!;
    }

    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('Epub file not found', filePath);
    }

    final parsed = await parseBookFile(filePath);
    return parsed.chapters;
  }

  /// Parses the epub at [filePath], returning metadata and extracted chapters.
  Future<ParsedEpub> parseBookFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('Epub file not found', filePath);
    }

    final bytes = await file.readAsBytes();
    final parsed = await parseBookBytes(bytes);
    cacheChapters(filePath, parsed.chapters);
    return parsed;
  }

  /// Parses already-loaded epub [bytes], returning metadata and chapters.
  Future<ParsedEpub> parseBookBytes(List<int> bytes) async {
    final epub = await EpubReader.readBook(bytes);

    final chapters = <Chapter>[];
    final epubChapters = epub.Chapters;

    if (epubChapters != null && epubChapters.isNotEmpty) {
      _flattenChapters(epubChapters, chapters, 0);
    }

    // If no chapters were extracted (some epubs store content differently),
    // try to fall back to the HTML content map.
    if (chapters.isEmpty) {
      _extractFromContent(epub, chapters);
    }

    return ParsedEpub(
      title: (epub.Title ?? '').trim(),
      author: (epub.Author ?? '').trim(),
      chapters: List<Chapter>.unmodifiable(chapters),
    );
  }

  /// Seeds the in-memory cache for [filePath].
  void cacheChapters(String filePath, List<Chapter> chapters) {
    _cache[filePath] = List<Chapter>.unmodifiable(chapters);
  }

  /// Removes the cached chapters for [filePath], if any.
  void evict(String filePath) {
    _cache.remove(filePath);
  }

  /// Clears the entire in-memory cache.
  void clearCache() {
    _cache.clear();
  }

  // ── Private helpers ──────────────────────────────────────────────────────

  /// Recursively flattens [EpubChapter] trees (including sub-chapters) into
  /// the given [out] list. [startIndex] is the index offset for numbering.
  /// Returns the next available index.
  int _flattenChapters(
    List<EpubChapter> source,
    List<Chapter> out,
    int startIndex,
  ) {
    var idx = startIndex;
    for (final ec in source) {
      final title = (ec.Title ?? '').trim();
      final html = ec.HtmlContent ?? '';
      final extracted = _htmlTextExtractor.extract(html);
      final text = extracted.content;

      // Skip empty chapters (e.g. cover pages with no readable content).
      if (text.trim().isNotEmpty) {
        out.add(Chapter(
          index: idx,
          title: title.isNotEmpty ? title : 'Chapter ${idx + 1}',
          content: text,
          styledContentJson: extracted.styledContent.toJson(),
        ));
        idx++;
      }

      // Recurse into sub-chapters.
      final subs = ec.SubChapters;
      if (subs != null && subs.isNotEmpty) {
        idx = _flattenChapters(subs, out, idx);
      }
    }
    return idx;
  }

  /// Fallback: extract content from the epub's HTML content map when the
  /// chapter list is empty.
  void _extractFromContent(EpubBook epub, List<Chapter> out) {
    final htmlFiles = epub.Content?.Html;
    if (htmlFiles == null || htmlFiles.isEmpty) return;

    var idx = 0;
    for (final entry in htmlFiles.entries) {
      final html = entry.value.Content ?? '';
      final extracted = _htmlTextExtractor.extract(html);
      final text = extracted.content;
      if (text.trim().isEmpty) continue;

      out.add(Chapter(
        index: idx,
        title: 'Chapter ${idx + 1}',
        content: text,
        styledContentJson: extracted.styledContent.toJson(),
      ));
      idx++;
    }
  }
}
