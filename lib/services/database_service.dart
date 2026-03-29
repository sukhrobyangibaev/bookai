import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import '../models/book.dart';
import '../models/chapter.dart';
import '../models/ai_request_log_entry.dart';
import '../models/generated_image.dart';
import '../models/highlight.dart';
import '../models/reading_progress.dart';
import '../models/resume_marker.dart';

class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  static Database? _db;
  String? _databasePathOverride;

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final path =
        _databasePathOverride ?? join(await getDatabasesPath(), 'bookai.db');

    return openDatabaseAt(path);
  }

  /// Opens the app database at an explicit [path].
  ///
  /// Used by the app for the default database and by tests for migration
  /// coverage without disturbing the shared singleton connection.
  Future<Database> openDatabaseAt(String path) {
    return openDatabase(
      path,
      version: 7,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> close() async {
    final db = _db;
    _db = null;
    if (db != null) {
      await db.close();
    }
  }

  Future<void> resetForTesting({String? databasePath}) async {
    await close();
    _databasePathOverride = databasePath;
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _onCreate(Database db, int version) async {
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

    await db
        .execute('CREATE INDEX idx_highlights_bookId ON highlights(bookId)');

    await _createResumeMarkersTable(db);
    await _createChaptersTable(db);
    await _createGeneratedImagesTable(db);
    await _createAiRequestLogsTable(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createResumeMarkersTable(db);
    }
    if (oldVersion < 3) {
      await db.execute('DROP INDEX IF EXISTS idx_bookmarks_bookId');
      await db.execute('DROP TABLE IF EXISTS bookmarks');
    }
    if (oldVersion < 4) {
      await _createChaptersTable(db);
    }
    if (oldVersion < 5) {
      await _createGeneratedImagesTable(db);
    }
    if (oldVersion < 6) {
      await _ensureGeneratedImagesNameColumn(db);
    }
    if (oldVersion < 7) {
      await _createAiRequestLogsTable(db);
    }
  }

  Future<void> _createResumeMarkersTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS resume_markers (
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
  }

  Future<void> _createChaptersTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS chapters (
        bookId         INTEGER NOT NULL,
        chapterIndex   INTEGER NOT NULL,
        title          TEXT    NOT NULL,
        content        TEXT    NOT NULL,
        PRIMARY KEY (bookId, chapterIndex),
        FOREIGN KEY (bookId) REFERENCES books(id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _createGeneratedImagesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS generated_images (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        bookId       INTEGER NOT NULL,
        chapterIndex INTEGER NOT NULL,
        featureMode  TEXT    NOT NULL,
        sourceText   TEXT    NOT NULL,
        promptText   TEXT    NOT NULL,
        name         TEXT,
        filePath     TEXT    NOT NULL,
        createdAt    TEXT    NOT NULL,
        FOREIGN KEY (bookId) REFERENCES books(id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_generated_images_bookId '
      'ON generated_images(bookId)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_generated_images_createdAt '
      'ON generated_images(createdAt DESC)',
    );
  }

  Future<void> _ensureGeneratedImagesNameColumn(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info(generated_images)');
    final hasNameColumn = columns.any((column) => column['name'] == 'name');
    if (!hasNameColumn) {
      await db.execute('ALTER TABLE generated_images ADD COLUMN name TEXT');
    }
  }

  Future<void> _createAiRequestLogsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ai_request_logs (
        id                   INTEGER PRIMARY KEY AUTOINCREMENT,
        createdAt            TEXT    NOT NULL,
        provider             TEXT    NOT NULL,
        requestKind          TEXT    NOT NULL,
        attempt              INTEGER NOT NULL DEFAULT 1,
        method               TEXT    NOT NULL,
        url                  TEXT    NOT NULL,
        modelId              TEXT,
        requestHeaders       TEXT    NOT NULL,
        requestBody          TEXT,
        responseStatusCode   INTEGER,
        responseHeaders      TEXT,
        responseBody         TEXT,
        responseMetadataOnly INTEGER NOT NULL DEFAULT 0,
        durationMs           INTEGER,
        errorMessage         TEXT
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_ai_request_logs_createdAt '
      'ON ai_request_logs(createdAt DESC)',
    );
  }

  // ── Books ─────────────────────────────────────────────────────────────────

  Future<Book> insertBook(Book book) async {
    final db = await database;
    final id = await db.insert(
      'books',
      book.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    return book.copyWith(id: id);
  }

  Future<List<Book>> getAllBooks() async {
    final db = await database;
    final rows = await db.query('books', orderBy: 'createdAt DESC');
    return rows.map(Book.fromMap).toList();
  }

  Future<Book?> getBookByFilePath(String filePath) async {
    final db = await database;
    final rows = await db.query(
      'books',
      where: 'filePath = ?',
      whereArgs: [filePath],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Book.fromMap(rows.first);
  }

  Future<void> deleteBook(int bookId) async {
    final db = await database;
    await db.delete('books', where: 'id = ?', whereArgs: [bookId]);
  }

  Future<void> updateBookTotalChapters(int bookId, int totalChapters) async {
    final db = await database;
    await db.update(
      'books',
      {'totalChapters': totalChapters},
      where: 'id = ?',
      whereArgs: [bookId],
    );
  }

  Future<void> replaceChaptersForBook(
      int bookId, List<Chapter> chapters) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('chapters', where: 'bookId = ?', whereArgs: [bookId]);

      if (chapters.isEmpty) {
        return;
      }

      final batch = txn.batch();
      for (final chapter in chapters) {
        batch.insert('chapters', {
          'bookId': bookId,
          'chapterIndex': chapter.index,
          'title': chapter.title,
          'content': chapter.content,
        });
      }
      await batch.commit(noResult: true);
    });
  }

  Future<List<Chapter>> getChaptersByBookId(int bookId) async {
    final db = await database;
    final rows = await db.query(
      'chapters',
      where: 'bookId = ?',
      whereArgs: [bookId],
      orderBy: 'chapterIndex ASC',
    );
    return rows
        .map(
          (row) => Chapter(
            bookId: bookId,
            index: row['chapterIndex'] as int,
            title: row['title'] as String,
            content: row['content'] as String,
          ),
        )
        .toList();
  }

  // ── Reading Progress ──────────────────────────────────────────────────────

  Future<void> upsertProgress(ReadingProgress progress) async {
    final db = await database;
    await db.insert(
      'progress',
      progress.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<ReadingProgress?> getProgressByBookId(int bookId) async {
    final db = await database;
    final rows = await db.query(
      'progress',
      where: 'bookId = ?',
      whereArgs: [bookId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return ReadingProgress.fromMap(rows.first);
  }

  // ── Resume Markers ────────────────────────────────────────────────────────

  Future<void> upsertResumeMarker(ResumeMarker marker) async {
    final db = await database;
    await db.insert(
      'resume_markers',
      marker.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<ResumeMarker?> getResumeMarkerByBookId(int bookId) async {
    final db = await database;
    final rows = await db.query(
      'resume_markers',
      where: 'bookId = ?',
      whereArgs: [bookId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return ResumeMarker.fromMap(rows.first);
  }

  // ── Highlights ────────────────────────────────────────────────────────────

  Future<Highlight> addHighlight(Highlight highlight) async {
    final db = await database;
    final id = await db.insert('highlights', highlight.toMap());
    return highlight.copyWith(id: id);
  }

  Future<List<Highlight>> getHighlightsByBookId(int bookId) async {
    final db = await database;
    final rows = await db.query(
      'highlights',
      where: 'bookId = ?',
      whereArgs: [bookId],
      orderBy: 'createdAt DESC',
    );
    return rows.map(Highlight.fromMap).toList();
  }

  Future<void> deleteHighlight(int highlightId) async {
    final db = await database;
    await db.delete('highlights', where: 'id = ?', whereArgs: [highlightId]);
  }

  // ── Generated Images ──────────────────────────────────────────────────────

  Future<GeneratedImage> addGeneratedImage(
      GeneratedImage generatedImage) async {
    final db = await database;
    final id = await db.insert(
      'generated_images',
      generatedImage.toMap(),
    );
    return generatedImage.copyWith(id: id);
  }

  Future<List<GeneratedImage>> getAllGeneratedImages() async {
    final db = await database;
    final rows = await db.query(
      'generated_images',
      orderBy: 'createdAt DESC',
    );
    return rows.map(GeneratedImage.fromMap).toList();
  }

  Future<List<GeneratedImage>> getGeneratedImagesByBookId(int bookId) async {
    final db = await database;
    final rows = await db.query(
      'generated_images',
      where: 'bookId = ?',
      whereArgs: [bookId],
      orderBy: 'createdAt DESC',
    );
    return rows.map(GeneratedImage.fromMap).toList();
  }

  Future<void> updateGeneratedImageName(
      int generatedImageId, String? name) async {
    final db = await database;
    await db.update(
      'generated_images',
      {'name': name},
      where: 'id = ?',
      whereArgs: [generatedImageId],
    );
  }

  Future<void> deleteGeneratedImage(int generatedImageId) async {
    final db = await database;
    await db.delete(
      'generated_images',
      where: 'id = ?',
      whereArgs: [generatedImageId],
    );
  }

  // ── AI Request Logs ───────────────────────────────────────────────────────

  Future<AiRequestLogEntry> addAiRequestLogEntry(
      AiRequestLogEntry entry) async {
    final db = await database;
    final id = await db.insert('ai_request_logs', entry.toMap());
    return entry.copyWith(id: id);
  }

  Future<List<AiRequestLogEntry>> getAiRequestLogEntries({
    int limit = 100,
    int offset = 0,
  }) async {
    final db = await database;
    final rows = await db.query(
      'ai_request_logs',
      orderBy: 'createdAt DESC, id DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map(AiRequestLogEntry.fromMap).toList();
  }

  Future<void> trimAiRequestLogEntries({int keepLatest = 1000}) async {
    final db = await database;

    if (keepLatest <= 0) {
      await db.delete('ai_request_logs');
      return;
    }

    await db.delete(
      'ai_request_logs',
      where: 'id NOT IN ('
          'SELECT id FROM ai_request_logs '
          'ORDER BY createdAt DESC, id DESC '
          'LIMIT ?'
          ')',
      whereArgs: [keepLatest],
    );
  }

  Future<int> clearAiRequestLogEntries() async {
    final db = await database;
    return db.delete('ai_request_logs');
  }

  Future<int> countAiRequestLogEntries() async {
    final db = await database;
    final rows = await db.rawQuery('SELECT COUNT(*) FROM ai_request_logs');
    return Sqflite.firstIntValue(rows) ?? 0;
  }
}
