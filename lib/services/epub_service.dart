import 'dart:io';

import 'package:epubx/epubx.dart';

import '../models/chapter.dart';

/// Parses epub files into ordered [Chapter] lists.
///
/// Maintains a simple in-memory cache keyed by file path so that repeated
/// calls within the same session avoid redundant parsing.
class EpubService {
  EpubService._();
  static final EpubService instance = EpubService._();

  /// In-memory chapter cache keyed by absolute file path.
  final Map<String, List<Chapter>> _cache = {};

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

    final bytes = await file.readAsBytes();
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

    _cache[filePath] = chapters;
    return chapters;
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
      final text = _stripHtml(html).trim();

      // Skip empty chapters (e.g. cover pages with no readable content).
      if (text.isNotEmpty) {
        out.add(Chapter(
          index: idx,
          title: title.isNotEmpty ? title : 'Chapter ${idx + 1}',
          content: text,
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
      final text = _stripHtml(html).trim();
      if (text.isEmpty) continue;

      out.add(Chapter(
        index: idx,
        title: 'Chapter ${idx + 1}',
        content: text,
      ));
      idx++;
    }
  }

  /// Strips HTML tags and collapses whitespace to produce plain text.
  static String _stripHtml(String html) {
    // Remove non-visible elements entirely (tag + content), e.g. <head>,
    // <style>, <script>. Without this, text inside <title>Unknown</title>
    // and similar tags leaks into the visible chapter content.
    var text = html.replaceAll(
        RegExp(r'<head[^>]*>[\s\S]*?</head>', caseSensitive: false), ' ');
    text = text.replaceAll(
        RegExp(r'<style[^>]*>[\s\S]*?</style>', caseSensitive: false), ' ');
    text = text.replaceAll(
        RegExp(r'<script[^>]*>[\s\S]*?</script>', caseSensitive: false), ' ');
    // Remove all remaining HTML tags.
    text = text.replaceAll(RegExp(r'<[^>]*>'), ' ');
    // Decode common HTML entities.
    text = text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'");
    // Collapse multiple whitespace chars into a single space.
    text = text.replaceAll(RegExp(r'\s+'), ' ');
    return text;
  }
}
