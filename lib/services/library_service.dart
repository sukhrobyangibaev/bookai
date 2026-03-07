import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

import '../models/book.dart';
import '../models/generated_image.dart';
import 'database_service.dart';
import 'epub_service.dart';
import 'storage_service.dart';

/// Outcome of an [LibraryService.importEpub] call.
sealed class ImportResult {}

/// The epub was imported successfully.
final class ImportSuccess extends ImportResult {
  final Book book;
  ImportSuccess(this.book);
}

/// The user cancelled the file picker without selecting a file.
final class ImportCancelled extends ImportResult {}

/// An epub with the same file path already exists in the library.
final class ImportDuplicate extends ImportResult {
  final Book existing;
  ImportDuplicate(this.existing);
}

/// Something went wrong during import.
final class ImportError extends ImportResult {
  final String message;
  ImportError(this.message);
}

/// Orchestrates the EPUB import flow and library queries.
class LibraryService {
  LibraryService._();
  static final LibraryService instance = LibraryService._();

  final _db = DatabaseService.instance;
  final _storage = StorageService.instance;

  // ── Import ─────────────────────────────────────────────────────────────────

  /// Opens a file picker, copies the selected epub into storage, parses its
  /// metadata, and persists a [Book] record.
  ///
  /// Returns an [ImportResult] discriminated union — callers switch on the
  /// concrete type to react appropriately.
  Future<ImportResult> importEpub() async {
    // 1. Pick file
    FilePickerResult? picked;
    try {
      picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['epub'],
      );
    } catch (e) {
      return ImportError('File picker failed: $e');
    }

    if (picked == null || picked.files.isEmpty) {
      return ImportCancelled();
    }

    final platformFile = picked.files.first;
    final sourcePath = platformFile.path;
    if (sourcePath == null) {
      return ImportError('Could not access selected file path.');
    }

    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) {
      return ImportError('Selected file no longer exists.');
    }

    // 2. Check for duplicate by destination path (same filename in books dir)
    final booksDir = await _storage.getBooksDirectory();
    final destPath = p.join(booksDir.path, p.basename(sourcePath));

    final existing = await _db.getBookByFilePath(destPath);
    if (existing != null) {
      return ImportDuplicate(existing);
    }

    // 3. Copy file into app storage
    final File destFile;
    try {
      destFile = await _storage.copyEpubToStorage(sourceFile);
    } catch (e) {
      return ImportError('Failed to copy file: $e');
    }

    // 4. Parse metadata + chapters in one pass so newly imported books open
    // quickly without reparsing the epub on first read.
    ParsedEpub? parsed;
    try {
      parsed = await EpubService.instance.parseBookFile(destFile.path);
    } catch (_) {
      parsed = null;
    }

    final title = _resolveTitle(parsed?.title, destFile.path);
    final author = _resolveAuthor(parsed?.author);

    // 5. Persist book record
    final draft = Book(
      title: title,
      author: author,
      filePath: destFile.path,
      totalChapters: parsed?.chapters.length ?? 0,
      createdAt: DateTime.now(),
    );

    final Book saved;
    try {
      saved = await _db.insertBook(draft);
    } catch (e) {
      // Roll back copied file on DB failure
      await _storage.deleteBookFile(destFile.path);
      return ImportError('Failed to save book record: $e');
    }

    // insertBook returns id == 0 on ConflictAlgorithm.ignore (duplicate filePath)
    if (saved.id == null || saved.id == 0) {
      final dup = await _db.getBookByFilePath(destFile.path);
      if (dup != null) return ImportDuplicate(dup);
      return ImportError('Duplicate book entry detected.');
    }

    if (saved.id != null && parsed != null && parsed.chapters.isNotEmpty) {
      try {
        await _db.replaceChaptersForBook(saved.id!, parsed.chapters);
      } catch (e) {
        await _db.deleteBook(saved.id!);
        await _storage.deleteBookFile(destFile.path);
        EpubService.instance.evict(destFile.path);
        return ImportError('Failed to store chapters: $e');
      }
    }

    return ImportSuccess(saved);
  }

  // ── Delete ──────────────────────────────────────────────────────────────────

  /// Deletes a book and all associated data (progress, highlights,
  /// generated images, local epub file, and in-memory epub cache).
  Future<void> deleteBook(Book book) async {
    if (book.id != null) {
      // CASCADE deletes handle progress, highlights, and generated images.
      await _db.deleteBook(book.id!);
      await _storage.deleteGeneratedImagesForBook(book.id!);
    }

    // Remove the epub file from local storage.
    await _storage.deleteBookFile(book.filePath);

    // Evict from EpubService in-memory cache so stale data isn't served.
    EpubService.instance.evict(book.filePath);
  }

  // ── Library queries ────────────────────────────────────────────────────────

  Future<List<Book>> getAllBooks() => _db.getAllBooks();
  Future<List<GeneratedImage>> getAllGeneratedImages() =>
      _db.getAllGeneratedImages();

  Future<void> deleteGeneratedImage(GeneratedImage generatedImage) async {
    final id = generatedImage.id;
    if (id != null) {
      await _db.deleteGeneratedImage(id);
    }
    await _storage.deleteGeneratedImageFile(generatedImage.filePath);
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _resolveTitle(String? title, String filePath) {
    final normalized = (title ?? '').trim();
    return normalized.isNotEmpty ? normalized : _titleFromPath(filePath);
  }

  String _resolveAuthor(String? author) {
    final normalized = (author ?? '').trim();
    return normalized.isNotEmpty ? normalized : 'Unknown Author';
  }

  String _titleFromPath(String filePath) {
    final name = p.basenameWithoutExtension(filePath);
    // Replace underscores/hyphens with spaces for a cleaner title.
    return name.replaceAll(RegExp(r'[_\-]+'), ' ').trim();
  }
}
