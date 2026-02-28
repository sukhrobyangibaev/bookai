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

## Prompt 04 - Reader Settings Service [DONE]

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

## Prompt 05 - EPUB Import + Local Storage [DONE]

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

### Summary of what was done:
- Created `lib/services/storage_service.dart` — singleton `StorageService` with:
  - `getBooksDirectory()` — returns (and lazily creates) `<documents>/books/` directory via `path_provider`.
  - `copyEpubToStorage(File, {overwrite})` — copies a source epub into the books directory; returns the destination `File`; skips overwrite by default if destination already exists.
  - `deleteBookFile(String)` — deletes the epub file from storage if it exists.
- Created `lib/services/library_service.dart` — singleton `LibraryService` with a sealed `ImportResult` union (`ImportSuccess`, `ImportCancelled`, `ImportDuplicate`, `ImportError`) and:
  - `importEpub()` — full import flow: opens `file_picker` (epub only), checks for duplicates by destination path via new `DatabaseService.getBookByFilePath`, copies file via `StorageService`, parses title/author with `epubx` (falls back to filename / "Unknown Author"), persists `Book` via `DatabaseService`; rolls back copied file on DB failure.
  - `getAllBooks()` — thin wrapper over `DatabaseService.getAllBooks()`.
- Added `getBookByFilePath(String)` to `DatabaseService` — queries `books` table by `filePath`.
- Updated `lib/screens/library_screen.dart` — converted to `StatefulWidget`:
  - Loads books on `initState`; shows `CircularProgressIndicator` while loading.
  - Empty state with icon and "Tap Import EPUB" hint when no books exist.
  - `ListView` with `Card`/`ListTile` items (title, author, book icon) when books are present; pull-to-refresh supported.
  - `FloatingActionButton.extended` ("Import EPUB") triggers import and shows a loading spinner while in progress; displays `SnackBar` for success, duplicate, or error outcomes.
- `flutter analyze` passed with **no issues**.

## Prompt 06 - EPUB Parsing Service [DONE]

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

### Summary of what was done:
- Created `lib/services/epub_service.dart` — singleton `EpubService` (private constructor + `instance` static field) with:
  - `Future<List<Chapter>> parseChapters(String filePath)` — reads the epub file, extracts chapters via `epubx`, returns an ordered list of `Chapter` model objects.
  - In-memory cache keyed by file path (`Map<String, List<Chapter>>`) — subsequent calls with the same path skip parsing; `evict(path)` and `clearCache()` methods provided.
  - `_flattenChapters` — recursively walks `EpubChapter` trees (including `SubChapters`) into a flat list; assigns sequential indices; uses chapter title with fallback to "Chapter N".
  - `_extractFromContent` — fallback for epubs that store content only in `Content.Html` map rather than `Chapters` list.
  - `_stripHtml` — removes HTML tags, decodes common HTML entities (`&nbsp;`, `&amp;`, `&lt;`, `&gt;`, `&quot;`, `&#39;`, `&apos;`), and collapses whitespace to plain text.
  - Empty/malformed chapters are safely skipped (no content = no chapter entry).
- `flutter analyze` passed with **no issues**.

## Prompt 07 - Reader Screen Baseline [DONE]

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

### Summary of what was done:
- Rewrote `lib/screens/reader_screen.dart` — converted from placeholder `StatelessWidget` to full `StatefulWidget`:
  - Accepts a `Book` argument via constructor.
  - On `initState`, parses chapters via `EpubService.instance.parseChapters(book.filePath)`.
  - Three UI states: loading (`CircularProgressIndicator`), error (icon + message + retry button), empty ("No readable content found").
  - Content view: `SingleChildScrollView` displaying chapter title (`headlineSmall`, bold) and chapter body text (`bodyLarge`, 1.6 line height) with comfortable padding.
  - App bar shows current chapter title (falls back to book title) and "X / N" chapter counter badge.
  - Bottom navigation bar with Previous/Next `OutlinedButton.icon` buttons; buttons are disabled at first/last chapter boundaries.
  - `_goToChapter(index)` centralises chapter switching and resets scroll position.
  - `ScrollController` is properly disposed.
- Updated `lib/screens/library_screen.dart`:
  - Added import for `reader_screen.dart`.
  - Added `_openReader(Book)` method that navigates via `MaterialPageRoute` to `ReaderScreen(book: book)`.
  - `_BookTile` now accepts an optional `onTap` callback; wired to `_openReader` from the list builder.
- `flutter analyze` passed with **no issues**.

## Prompt 08 - Table of Contents + Chapter Jump [DONE]

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

### Summary of what was done:
- Added a TOC icon button (`Icons.toc`) in the `ReaderScreen` app bar actions, placed before the chapter counter badge.
- `_showTableOfContents()` opens a `showModalBottomSheet` with a `DraggableScrollableSheet` (initial 60%, max 90%) containing:
  - A header row with "Table of Contents" title and a close button.
  - A `ListView.builder` listing all chapters with their 1-based index number and title.
  - The current chapter is highlighted: bold text in primary color, with a tinted `selectedTileColor` background.
- Tapping a chapter in the TOC dismisses the bottom sheet and calls the existing centralised `_goToChapter(index)` method, which resets scroll position.
- `flutter analyze` passed with **no issues**.

## Prompt 09 - Reading Progress Tracking [DONE]

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

### Summary of what was done:
- Updated `lib/screens/reader_screen.dart`:
  - Added `DatabaseService` reference and a `Timer`-based debounce (`_saveTimer`, 2-second `_saveDebounceDuration`).
  - `_onScroll()` listener resets the debounce timer on every scroll event; when it fires, `_saveProgressNow()` persists current `chapterIndex` and `scrollOffset` via `DatabaseService.upsertProgress`.
  - `_goToChapter()` now calls `_saveProgressNow()` immediately on chapter change (in addition to resetting scroll).
  - `dispose()` cancels the timer and calls `_saveProgressNow()` to persist final position before the screen is destroyed.
  - `_loadChapters()` now restores saved progress: after parsing chapters, it queries `DatabaseService.getProgressByBookId`; if a saved progress exists it restores `_currentIndex` and uses `addPostFrameCallback` to restore `scrollOffset` (clamped to `maxScrollExtent`) after the frame renders.
- Updated `lib/screens/library_screen.dart`:
  - Added `DatabaseService` reference and a `_progressMap` (`Map<int, ReadingProgress>`) that is populated during `_loadBooks()` by querying progress for each book.
  - `_openReader()` now awaits the `Navigator.push` and calls `_loadBooks()` on return, so progress subtitles refresh after reading.
  - `_BookTile` now accepts an optional `ReadingProgress?` parameter; `_buildSubtitle()` appends "Chapter X/N (Y%)" alongside the author when progress exists and `totalChapters > 0`.
- `flutter analyze` passed with **no issues**.

## Prompt 10 - Bookmarks [DONE]

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

### Summary of what was done:
- Added bookmark add icon (`Icons.bookmark_add_outlined`) to the `ReaderScreen` app bar — one tap saves a bookmark at the current chapter with an auto-generated excerpt (first 80 characters of the chapter content).
- Added bookmarks list icon (`Icons.bookmarks_outlined`) to open a `DraggableScrollableSheet` bottom sheet listing all bookmarks for the current book, ordered most-recent first, with chapter title and excerpt preview.
- Tapping a bookmark in the list dismisses the sheet and jumps the reader to the saved chapter via the existing `_goToChapter()` method.
- Bookmark deletion supported via both swipe-to-dismiss (`Dismissible`) and a delete icon button on each list tile; deletes from both in-memory list and SQLite via `DatabaseService.deleteBookmark`.
- Empty state shown when no bookmarks exist (icon + hint text).
- Bookmarks loaded from the database alongside chapters during `_loadChapters()`.
- `SnackBar` confirmation shown after adding a bookmark, with a "View All" action to open the bookmarks panel.
- `flutter analyze` passed with **no issues**.

## Prompt 11 - Text Highlights [DONE]

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

### Summary of what was done:
- Replaced `Text` with `SelectableText.rich` for the chapter body content, enabling native text selection.
- Added a custom `contextMenuBuilder` that appends a "Highlight" button to the default selection toolbar (Copy, Select All, etc.) via `AdaptiveTextSelectionToolbar.buttonItems`.
- Selecting text and tapping "Highlight" saves it via `DatabaseService.addHighlight` with the current chapter index, selected text, and a default warm-yellow color (`#FFEB3B`).
- Inline highlight rendering: `_buildHighlightedText()` finds all saved highlight text occurrences in the current chapter content, merges overlapping ranges, and renders them as `TextSpan` children with a semi-transparent yellow background.
- Added highlights list icon (`Icons.highlight_outlined`) in the app bar to open a `DraggableScrollableSheet` bottom sheet showing all highlights for the book, with italic quoted text and chapter name.
- Highlight deletion via both swipe-to-dismiss (`Dismissible`) and delete icon button; removes from in-memory list and SQLite.
- Tapping a highlight in the list jumps the reader to that chapter.
- Empty state shown when no highlights exist.
- Highlights loaded from the database during `_loadChapters()` alongside bookmarks.
- `SnackBar` confirmation shown after saving a highlight, with a "View All" action.
- `flutter analyze` passed with **no issues**.

## Prompt 12 - Settings Screen UI [DONE]

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

### Summary of what was done:
- Rewrote `lib/screens/settings_screen.dart` — replaced placeholder with full settings UI wired to `SettingsController` via `SettingsControllerScope.of(context)`:
  - **Font Size** section: `Slider` with range 14–28 (14 discrete divisions), small "A" and large "A" labels on either side, current value shown as slider label, and a live preview box displaying sample text at the selected size.
  - **Theme** section: `SegmentedButton<AppThemeMode>` with three options — Light (sun icon), Dark (moon icon), Sepia (book icon).
  - Both controls call `controller.setFontSize()` / `controller.setThemeMode()` directly on change, persisting immediately via `SharedPreferences` through the existing `SettingsService`.
  - Entire body wrapped in `ListenableBuilder` so UI rebuilds reactively when the controller notifies.
- Updated `lib/screens/library_screen.dart`:
  - Added settings icon button (`Icons.settings_outlined`) in the app bar actions.
  - Tapping navigates to `SettingsScreen` via `MaterialPageRoute`.
- Updated `lib/screens/reader_screen.dart`:
  - Imported `app.dart` to access `SettingsControllerScope`.
  - `_buildContent()` now reads `SettingsControllerScope.of(context).fontSize` and applies it to the chapter body `SelectableText.rich` style, so reader content reflects the chosen font size live when reopened.
- `flutter analyze` passed with **no issues**.

## Prompt 13 - Local Library Improvements [DONE]

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

### Summary of what was done:
- Rewrote `lib/screens/library_screen.dart` — replaced `_BookTile` (`ListTile`) with a polished `_BookCard` widget:
  - Book icon container (rounded rectangle, primary container color) on the left.
  - Title (up to 2 lines, bold `titleMedium`) and author (`bodyMedium`, muted color) with proper text overflow handling.
  - `LinearProgressIndicator` bar showing reading progress fraction (0 when not started), with a text label below: "Chapter X of N (Y%)" or "Not started".
  - `PopupMenuButton` (three-dot menu) with a "Delete" option styled in the error color.
- Added `_deleteBook(Book)` method with a confirmation `AlertDialog`:
  - Shows book title and warns that bookmarks, highlights, and progress will be permanently removed.
  - "Cancel" (`TextButton`) and "Delete" (`FilledButton` in error color) actions.
  - On confirmation, calls `LibraryService.deleteBook(book)` then refreshes the list and shows a `SnackBar`.
- Added `deleteBook(Book)` method to `lib/services/library_service.dart`:
  - Calls `DatabaseService.deleteBook(id)` (CASCADE deletes handle progress, bookmarks, highlights).
  - Calls `StorageService.deleteBookFile(filePath)` to remove the local epub file.
  - Calls `EpubService.instance.evict(filePath)` to clear the in-memory chapter cache.
- Improved empty state in `_buildEmptyState()`:
  - Larger icon (`auto_stories_outlined`, 96px, faded primary color).
  - `headlineSmall` title "Your library is empty" with bold weight.
  - Descriptive body text explaining local storage.
  - `FilledButton.icon` CTA: "Import Your First Book" (also shows spinner when importing).
- List refresh is consistent: `_loadBooks()` is called after import success, after delete, and when returning from the reader screen.
- `flutter analyze` passed with **no issues**.

## Prompt 14 - Phase 1 Hardening + Basic Tests [DONE]

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

### Summary of what was done:
- Added `sqflite_common_ffi` as a dev dependency for FFI-based SQLite in the test environment.
- Created **model serialization unit tests** (49 tests total across 6 files):
  - `test/models/book_test.dart` — 8 tests: `toMap`, `fromMap`, roundtrip, `copyWith`, null id/coverPath handling, equality.
  - `test/models/chapter_test.dart` — 6 tests: `toMap`, `fromMap`, roundtrip, `copyWith`, null id/bookId handling.
  - `test/models/reading_progress_test.dart` — 6 tests: `toMap`, `fromMap`, roundtrip, `copyWith`, int-to-double coercion, bookId-only equality.
  - `test/models/bookmark_test.dart` — 6 tests: `toMap`, `fromMap`, roundtrip, `copyWith`, null id handling.
  - `test/models/highlight_test.dart` — 7 tests: `toMap`, `fromMap`, roundtrip, `copyWith`, null id handling, selectedText-based equality.
  - `test/models/reader_settings_test.dart` — 16 tests: defaults, `toMap`/`fromMap` for all theme modes, fallbacks for missing/null/unknown values, int-to-double coercion, empty map defaults, roundtrip, `copyWith`, equality, `AppThemeMode` enum validation.
- Created **settings service and controller tests** (`test/services/settings_test.dart` — 15 tests):
  - `SettingsService`: load defaults from empty `SharedPreferences`, load stored values, unknown theme mode fallback, `saveFontSize`/`saveThemeMode` persistence, save-then-load roundtrip.
  - `SettingsController`: starts with defaults, `load()` reads persisted settings and notifies, `setFontSize`/`setThemeMode` update + notify + persist, skip-if-unchanged (no notification), settings getter returns current state.
- Created **widget test** for `LibraryScreen` (`test/widget_test.dart` — 1 comprehensive test):
  - Initializes `sqflite_common_ffi` and pre-initializes the database for async compatibility.
  - Verifies empty state: app bar title "BookAI Library", empty state icon, "Your library is empty" heading, descriptive text, "Import Your First Book" CTA button, "Import EPUB" FAB, settings icon, and no loading indicator.
- **No analyzer warnings** — `flutter analyze` reports no issues.
- Updated `README.md` with:
  - How to run the app (prerequisites, dev commands, APK build instructions).
  - Complete list of Phase 1 features implemented.
  - Tech stack summary.
  - Known limitations (no covers, plain text only, no search, no pagination, no export, single-device, Android only, substring-based highlight matching).
- `flutter test` — **65 tests passed**.
- `flutter analyze` — **no issues found**.

