# BookAI

A personal AI-powered EPUB reader for Android, built with Flutter.

## How to Run

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (>=3.4.4)
- Android SDK (for building APKs)
- A connected Android device or emulator

### Development

```bash
# Install dependencies
flutter pub get

# Run on connected device/emulator
flutter run

# Run static analysis
flutter analyze

# Run tests
flutter test
```

### Build APK

```bash
flutter build apk --release
```

The APK will be at `build/app/outputs/flutter-apk/app-release.apk`. Install it directly on your Android device.

## Phase 1 Features (Implemented)

- **EPUB import** -- pick `.epub` files from device storage; files are copied into app-local storage
- **EPUB parsing** -- chapters extracted with titles and plain-text content; in-memory cache avoids redundant parsing
- **Local library** -- list of imported books with title, author, and reading progress; pull-to-refresh; delete with confirmation
- **Reader** -- scrollable chapter content with previous/next navigation
- **Table of contents** -- bottom sheet listing all chapters; tap to jump; current chapter highlighted
- **Reading progress** -- persisted chapter index and scroll offset; debounced saves; restored on reopen; progress shown in library
- **Text highlights** -- select text and tap "Highlight" from context menu; inline highlight rendering; highlights panel; delete support
- **Settings** -- font size slider (14--28), theme selector (light / dark / sepia); persisted via SharedPreferences; applied globally
- **SQLite persistence** -- books, progress, highlights, and resume markers stored locally with cascade deletes

## Tech Stack

- **Flutter** (Dart) -- app and UI
- **SQLite** (`sqflite`) -- local database
- **SharedPreferences** -- reader settings
- **epubx** -- EPUB parsing
- **file_picker** -- file selection

## Known Limitations

- **No cover images** -- book covers are not extracted or displayed; library shows a generic icon
- **Plain text only** -- HTML formatting in EPUB chapters is stripped; no rich text, images, or CSS styling in the reader
- **No search** -- no full-text search within books
- **No pagination** -- chapters render as a single scrollable view rather than paginated pages
- **No annotation export** -- highlights and resume markers cannot be exported
- **Single-device** -- all data is local with no sync or backup mechanism
- **Android only** -- tested on Android; iOS/desktop builds are not validated
- **Highlight matching** -- highlights are matched by plain-text substring; if the same text appears multiple times in a chapter, all occurrences are highlighted
