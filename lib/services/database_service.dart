import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import '../models/book.dart';
import '../models/reading_progress.dart';
import '../models/bookmark.dart';
import '../models/highlight.dart';
import '../models/resume_marker.dart';

class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  static Database? _db;

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'bookai.db');

    return openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
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
      CREATE TABLE bookmarks (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        bookId       INTEGER NOT NULL,
        chapterIndex INTEGER NOT NULL,
        excerpt      TEXT    NOT NULL,
        createdAt    TEXT    NOT NULL,
        FOREIGN KEY (bookId) REFERENCES books(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('CREATE INDEX idx_bookmarks_bookId ON bookmarks(bookId)');

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
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createResumeMarkersTable(db);
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

  Future<void> deleteResumeMarkerByBookId(int bookId) async {
    final db = await database;
    await db.delete('resume_markers', where: 'bookId = ?', whereArgs: [bookId]);
  }

  // ── Bookmarks ─────────────────────────────────────────────────────────────

  Future<Bookmark> addBookmark(Bookmark bookmark) async {
    final db = await database;
    final id = await db.insert('bookmarks', bookmark.toMap());
    return bookmark.copyWith(id: id);
  }

  Future<List<Bookmark>> getBookmarksByBookId(int bookId) async {
    final db = await database;
    final rows = await db.query(
      'bookmarks',
      where: 'bookId = ?',
      whereArgs: [bookId],
      orderBy: 'createdAt DESC',
    );
    return rows.map(Bookmark.fromMap).toList();
  }

  Future<void> deleteBookmark(int bookmarkId) async {
    final db = await database;
    await db.delete('bookmarks', where: 'id = ?', whereArgs: [bookmarkId]);
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
}
