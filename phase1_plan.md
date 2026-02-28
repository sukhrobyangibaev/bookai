# Phase 1 Implementation Prompts (BookAI)

Use these prompts in order. Each prompt is scoped to one agent run and only targets Phase 1.

## Prompt 01 - Project Setup + Folder Structure [DONE]

```text
You are working in a Flutter project at the repository root.

Task:
1. Add Phase 1 dependencies in `pubspec.yaml`: `file_picker`, `epubx`, `sqflite`, `path`, `path_provider`, `shared_preferences`.
2. Create folder structure:
   - `lib/app.dart`
   - `lib/models/`
   - `lib/services/`
   - `lib/screens/`
   - `lib/widgets/`
3. Replace template counter app with a minimal app shell:
   - `main.dart` should call `runApp(const BookAiApp())`.
   - `BookAiApp` should render `LibraryScreen` as home.
4. Add placeholder screens:
   - `library_screen.dart`
   - `reader_screen.dart`
   - `settings_screen.dart`
   Each screen can show a centered title for now.

Constraints:
- Keep code compile-safe.
- Do not implement full business logic yet.

Validation:
- Run `flutter pub get`.
- Run `flutter analyze`.
```

### Summary of what was done:
- Added dependencies to `pubspec.yaml`: `file_picker ^8.0.0`, `epubx ^4.0.0`, `sqflite ^2.3.0`, `path ^1.9.0`, `path_provider ^2.1.0`, `shared_preferences ^2.2.0`.
- Created folder structure: `lib/models/`, `lib/services/`, `lib/screens/`, `lib/widgets/`.
- Created `lib/app.dart` with `BookAiApp` widget (MaterialApp using Material 3, indigo color scheme, `LibraryScreen` as home).
- Replaced `lib/main.dart` — now calls `runApp(const BookAiApp())`.
- Created placeholder screens: `lib/screens/library_screen.dart`, `lib/screens/reader_screen.dart`, `lib/screens/settings_screen.dart` — each displays a centered title text.
- Updated `test/widget_test.dart` to match new app structure (verifies `LibraryScreen` renders).
- `flutter pub get` succeeded.
- `flutter analyze` passed with **no issues**.

## Prompt 02 - Core Models for Phase 1 [DONE]

```text
Create Dart models for Phase 1 with `fromMap` and `toMap` helpers:

Files:
- `lib/models/book.dart`
- `lib/models/chapter.dart`
- `lib/models/reading_progress.dart`
- `lib/models/bookmark.dart`
- `lib/models/highlight.dart`
- `lib/models/reader_settings.dart`

Requirements:
1. `Book`: id, title, author, filePath, coverPath(optional), totalChapters, createdAt.
2. `Chapter`: id(optional), bookId(optional), index, title, content.
3. `ReadingProgress`: bookId, chapterIndex, scrollOffset, updatedAt.
4. `Bookmark`: id(optional), bookId, chapterIndex, excerpt, createdAt.
5. `Highlight`: id(optional), bookId, chapterIndex, selectedText, colorHex, createdAt.
6. `ReaderSettings`: fontSize, themeMode (light/dark/sepia as string).

Constraints:
- Keep models immutable where practical.
- Use plain Dart classes (no code generation).

Validation:
- Run `flutter analyze`.
```

### Summary of what was done:
- Created `lib/models/book.dart` — immutable `Book` class with all required fields (`id`, `title`, `author`, `filePath`, `coverPath`, `totalChapters`, `createdAt`), plus `copyWith`, `toMap`, `fromMap`, `==`, and `hashCode`.
- Created `lib/models/chapter.dart` — immutable `Chapter` class with `id` (optional), `bookId` (optional), `index`, `title`, `content`, plus `copyWith`, `toMap`, `fromMap`, `==`, and `hashCode`.
- Created `lib/models/reading_progress.dart` — immutable `ReadingProgress` class with `bookId`, `chapterIndex`, `scrollOffset` (double), `updatedAt`, plus `copyWith`, `toMap`, `fromMap`, `==`, and `hashCode`.
- Created `lib/models/bookmark.dart` — immutable `Bookmark` class with `id` (optional), `bookId`, `chapterIndex`, `excerpt`, `createdAt`, plus `copyWith`, `toMap`, `fromMap`, `==`, and `hashCode`.
- Created `lib/models/highlight.dart` — immutable `Highlight` class with `id` (optional), `bookId`, `chapterIndex`, `selectedText`, `colorHex`, `createdAt`, plus `copyWith`, `toMap`, `fromMap`, `==`, and `hashCode`.
- Created `lib/models/reader_settings.dart` — immutable `ReaderSettings` class with `fontSize` (double) and `themeMode` (`AppThemeMode` enum: `light`, `dark`, `sepia`), includes `defaults` constant, `copyWith`, `toMap`, `fromMap`, `==`, and `hashCode`.
- `flutter analyze` passed with **no issues**.

## Prompt 03 - Local Database Service (SQLite) [DONE]

```text
Implement SQLite persistence in `lib/services/database_service.dart`.

Task:
1. Create a singleton `DatabaseService`.
2. Initialize DB with tables:
   - books
   - progress
   - bookmarks
   - highlights
3. Add CRUD methods needed for Phase 1:
   - insertBook, getAllBooks, deleteBook
   - upsertProgress, getProgressByBookId
   - addBookmark, getBookmarksByBookId, deleteBookmark
   - addHighlight, getHighlightsByBookId, deleteHighlight
4. Use model map conversion methods.

Constraints:
- Keep schema simple and readable.
- Use indexes for `bookId` columns where useful.

Validation:
- Run `flutter analyze`.
```

### Summary of what was done:
- Created `lib/services/database_service.dart` — singleton `DatabaseService` (private constructor + `instance` static field, lazy-initialized `_db`).
- Database file: `bookai.db` stored in the platform's default databases path.
- Schema (version 1, created in `_onCreate`):
  - `books` — id (PK autoincrement), title, author, filePath (UNIQUE), coverPath (nullable), totalChapters, createdAt.
  - `progress` — bookId (PK, FK → books with CASCADE DELETE), chapterIndex, scrollOffset (REAL), updatedAt.
  - `bookmarks` — id (PK autoincrement), bookId (FK → books CASCADE), chapterIndex, excerpt, createdAt. Index on `bookId`.
  - `highlights` — id (PK autoincrement), bookId (FK → books CASCADE), chapterIndex, selectedText, colorHex, createdAt. Index on `bookId`.
- CRUD methods implemented:
  - `insertBook` / `getAllBooks` (ordered by createdAt DESC) / `deleteBook`
  - `upsertProgress` (INSERT OR REPLACE) / `getProgressByBookId`
  - `addBookmark` / `getBookmarksByBookId` (ordered by createdAt DESC) / `deleteBookmark`
  - `addHighlight` / `getHighlightsByBookId` (ordered by createdAt DESC) / `deleteHighlight`
- All methods use model `toMap()` / `fromMap()` helpers.
- `flutter analyze` passed with **no issues**.

## Prompt 04 - Reader Settings Service

```text
Implement settings persistence in `lib/services/settings_service.dart` using `shared_preferences`.

Task:
1. Store and load:
   - font size (double)
   - theme mode (`light`, `dark`, `sepia`)
2. Provide sensible defaults.
3. Create a `ChangeNotifier`-based controller in `lib/services/settings_controller.dart`:
   - holds current settings
   - exposes `setFontSize`, `setThemeMode`
   - persists changes through `SettingsService`
4. Wire `BookAiApp` (`lib/app.dart`) to use controller and apply theme mode globally.

Constraints:
- Keep sepia as a custom ThemeData mapping (not just light/dark).

Validation:
- Run `flutter analyze`.
```

### Summary of what was done:
- Created `lib/services/settings_service.dart` — loads and saves `fontSize` (double) and `themeMode` (string) using `SharedPreferences` keys `reader_font_size` and `reader_theme_mode`; falls back to `ReaderSettings.defaults` when keys are absent.
- Created `lib/services/settings_controller.dart` — `ChangeNotifier`-based `SettingsController` with:
  - `load()` async initialiser that reads persisted values via `SettingsService` and calls `notifyListeners()`.
  - `setFontSize(double)` and `setThemeMode(AppThemeMode)` — update in-memory state, notify listeners, then persist asynchronously.
  - Accepts an optional `SettingsService` in its constructor for testability.
- Updated `lib/app.dart`:
  - Converted `BookAiApp` to `StatefulWidget`; creates (and disposes) a `SettingsController` unless one is injected.
  - Added `SettingsControllerScope` (`InheritedNotifier<SettingsController>`) so any descendant widget can call `SettingsControllerScope.of(context)` to access the controller.
  - `_buildTheme(AppThemeMode)` maps each mode to a distinct `ThemeData`:
    - `light` — default indigo `ColorScheme.fromSeed` (Material 3).
    - `dark` — dark brightness indigo seed scheme.
    - `sepia` — custom `ColorScheme.light` with warm brown/cream palette; custom `scaffoldBackgroundColor`, `AppBarTheme`, and `TextTheme`.
  - `MaterialApp` is rebuilt reactively via `ListenableBuilder` whenever the controller notifies.
- `flutter analyze` passed with **no issues**.

## Prompt 05 - EPUB Import + Local Storage

```text
Implement file import flow.

Files:
- `lib/services/storage_service.dart`
- `lib/services/library_service.dart`
- update `lib/screens/library_screen.dart`

Task:
1. Use `file_picker` to choose `.epub` files.
2. Copy selected file into app documents directory (`books/`).
3. Parse minimal metadata (title/author if available; fallback to filename).
4. Save book record via `DatabaseService`.
5. In `LibraryScreen`, add floating action button `Import EPUB` to trigger import.
6. Refresh and show imported books in a list.

Constraints:
- Avoid blocking UI; use async loading states.
- Handle duplicate imports gracefully (same filepath or same title+author).

Validation:
- Run `flutter analyze`.
```

## Prompt 06 - EPUB Parsing Service

```text
Create `lib/services/epub_service.dart` to parse epub content into chapters.

Task:
1. Load epub from local file path using `epubx`.
2. Extract ordered chapter list with:
   - chapter index
   - chapter title (fallback: "Chapter N")
   - plain text content (strip HTML tags if needed)
3. Expose:
   - `Future<List<Chapter>> parseChapters(String filePath)`
4. Add simple in-memory cache by bookId or filepath to avoid repeated heavy parsing in one session.

Constraints:
- Handle malformed/empty chapter content safely.
- Keep API small and easy to test.

Validation:
- Run `flutter analyze`.
```

## Prompt 07 - Reader Screen Baseline

```text
Implement baseline reader UI in `lib/screens/reader_screen.dart`.

Task:
1. Accept a `Book` argument.
2. On load, parse chapters via `EpubService`.
3. Display current chapter title and scrollable chapter content.
4. Add previous/next chapter buttons.
5. From `LibraryScreen`, tap a book item to open `ReaderScreen(book: selectedBook)`.

Constraints:
- Show loading and error states.
- Keep UI simple but clean.

Validation:
- Run `flutter analyze`.
```

## Prompt 08 - Table of Contents + Chapter Jump

```text
Enhance reader navigation.

Task:
1. Add a table of contents drawer/bottom sheet in `ReaderScreen`.
2. TOC should list chapter titles and allow jumping to selected chapter index.
3. Highlight current chapter in TOC.
4. Preserve scroll reset behavior when switching chapters.

Constraints:
- Keep chapter switch logic centralized in one method.

Validation:
- Run `flutter analyze`.
```

## Prompt 09 - Reading Progress Tracking

```text
Add persistent reading progress.

Task:
1. In `ReaderScreen`, track:
   - current chapter index
   - scroll offset
2. Save progress via `DatabaseService.upsertProgress`:
   - periodically (debounced)
   - on chapter change
   - on dispose
3. On opening a book, restore last saved chapter and scroll position.
4. In `LibraryScreen`, show a lightweight subtitle like "Chapter X" or percentage if possible.

Constraints:
- Avoid excessive writes; debounce saves.

Validation:
- Run `flutter analyze`.
```

## Prompt 10 - Bookmarks

```text
Implement bookmarks end-to-end.

Task:
1. In reader app bar, add bookmark action to save current position.
2. Bookmark record should include chapter index and small excerpt.
3. Add bookmarks panel (bottom sheet or separate route) listing bookmarks for current book.
4. Tapping a bookmark jumps reader to saved chapter.
5. Support bookmark deletion from list.

Constraints:
- Keep bookmark creation available in one tap.

Validation:
- Run `flutter analyze`.
```

## Prompt 11 - Text Highlights

```text
Implement basic text highlight flow.

Task:
1. Enable text selection in reader content (`SelectableText`-based approach is fine).
2. When user selects text, show action to save highlight.
3. Persist highlight with chapter index + selected text + default color.
4. Add "Highlights" view for current book (sheet or route).
5. Allow deleting highlights.

Constraints:
- Keep implementation robust even if exact text appears multiple times.
- Do not over-engineer color system; one default highlight color is enough.

Validation:
- Run `flutter analyze`.
```

## Prompt 12 - Settings Screen UI

```text
Build `SettingsScreen` and wire it to `SettingsController`.

Task:
1. Add font size slider (e.g., 14-28).
2. Add theme selector (light/dark/sepia).
3. Persist changes immediately.
4. Add entry point from `LibraryScreen` (app bar action).
5. Ensure reader content uses chosen font size and updates live when reopened.

Constraints:
- Keep settings screen minimal and readable.

Validation:
- Run `flutter analyze`.
```

## Prompt 13 - Local Library Improvements

```text
Polish `LibraryScreen`.

Task:
1. Show each book as card/list tile with title, author, and progress snippet.
2. Add delete book action:
   - remove DB records (book, progress, bookmarks, highlights)
   - delete local epub file from storage
3. Add empty state with clear import CTA.
4. Keep list refresh consistent after import/delete.

Constraints:
- Confirm deletion with dialog.

Validation:
- Run `flutter analyze`.
```

## Prompt 14 - Phase 1 Hardening + Basic Tests

```text
Do a stabilization pass for Phase 1 only.

Task:
1. Add basic unit tests for:
   - settings read/write defaults
   - model map serialization
2. Add one widget test for `LibraryScreen` empty state and import button presence.
3. Fix analyzer warnings.
4. Update `README.md` with:
   - how to run app
   - Phase 1 features implemented
   - known limitations

Constraints:
- Do not start Phase 2/3/4/5 features.

Validation:
- Run `flutter test`.
- Run `flutter analyze`.
```

