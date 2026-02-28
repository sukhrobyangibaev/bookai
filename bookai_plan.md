# BookAI — Project Plan

A personal AI-powered epub reader for Android.

## Stack

- **Flutter** (Dart) — app, UI, everything
- **SQLite** (sqflite package) — local storage
- **OpenRouter API** — LLM features (companion, summaries, translation)
- **Image generation API** (DALL-E / Replicate) — scene visualization
- **No backend** — all API calls directly from the app

---

## Features

### Phase 1 — Basic Reader (learn Flutter + get something working)

- [x] Load epub files from device storage
- [x] Parse epub and display book content (chapters, pages)
- [x] Basic navigation (table of contents, prev/next chapter buttons)
- [x] Swipe gesture navigation between chapters
- [x] Reading progress tracking
- [x] Bookmarks
- [x] Highlights (tap and hold to select text → highlight)
- [x] Local library — list of your uploaded books
- [x] Settings (font size, theme: light/dark/sepia)

### Phase 2 — AI Reading Companion

- [ ] Select text → "Ask about this" button
- [ ] Chat interface for discussing the book
- [ ] Context-aware — sends current chapter/surrounding text to LLM
- [ ] Conversation history per book (stored locally)
- [ ] Prompt engineering: system prompt that includes book title, author, current position, selected text

### Phase 3 — Tap-to-Learn (Translation & Language)

- [ ] Tap a word → popup with definition + translation
- [ ] Tap a sentence → full translation with context
- [ ] Target language setting (Japanese, Uzbek, Russian, etc.)
- [ ] Save words to a personal vocabulary list
- [ ] Review saved words (simple flashcard view)

### Phase 4 — Smart Recall

- [ ] Auto-generate chapter summaries (triggered on chapter completion)
- [ ] "Remind me who this is" — select a character name → get a summary of who they are and what they've done so far (up to your current position, no spoilers)
- [ ] "What happened so far" — summary up to current reading position
- [ ] Character tracker — auto-detected characters with descriptions, updated as you read

### Phase 5 — Scene Visualizer

- [ ] Select text → "Visualize this" button
- [ ] Sends passage to image generation API
- [ ] Display generated image inline or in a gallery
- [ ] Save generated images per book

---

## Project Structure

```
bookai/
├── lib/
│   ├── main.dart                  # entry point
│   ├── app.dart                   # app config, theme, routes
│   ├── models/
│   │   ├── book.dart              # book metadata model
│   │   ├── highlight.dart         # highlight model
│   │   ├── bookmark.dart          # bookmark model
│   │   ├── chat_message.dart      # AI chat message model
│   │   └── vocabulary.dart        # saved words model
│   ├── services/
│   │   ├── epub_service.dart      # epub parsing & chapter extraction
│   │   ├── database_service.dart  # SQLite operations
│   │   ├── ai_service.dart        # OpenRouter API calls
│   │   ├── image_service.dart     # image generation API calls
│   │   └── storage_service.dart   # file system operations
│   ├── screens/
│   │   ├── library_screen.dart    # book library (home)
│   │   ├── reader_screen.dart     # the actual reader
│   │   ├── chat_screen.dart       # AI companion chat
│   │   ├── summary_screen.dart    # chapter summaries & recall
│   │   ├── vocabulary_screen.dart # saved words
│   │   └── settings_screen.dart   # app settings
│   └── widgets/
│       ├── book_card.dart         # book thumbnail in library
│       ├── reader_page.dart       # single page of content
│       ├── highlight_menu.dart    # popup when text selected
│       ├── word_popup.dart        # tap-to-learn popup
│       └── image_viewer.dart      # scene visualization display
├── assets/
│   └── fonts/                     # reading fonts
└── pubspec.yaml                   # dependencies
```

## Key Flutter Packages

- `epubx` or `epub_parser` — epub parsing
- `sqflite` — local SQLite database
- `http` or `dio` — API requests
- `flutter_html` or `flutter_widget_from_html` — render epub HTML content
- `file_picker` — pick epub files from device
- `shared_preferences` — simple settings storage

---

## Learning Path (for someone with 0 Flutter experience)

### Week 1 — Dart & Flutter basics
- Dart language tour (2-3 hours, very easy coming from Python)
- Flutter official codelabs: https://docs.flutter.dev/codelabs
- Build a throwaway todo app to get the feel
- Learn: widgets, setState, navigation, ListView

### Week 2 — Start Phase 1
- Set up the project
- File picker → load epub → parse chapters
- Display chapter text on screen
- Basic page navigation

### Week 3-4 — Complete Phase 1
- Library screen, bookmarks, highlights
- SQLite for persistence
- Settings, theming
- Polish until it's a reader you'd actually use daily

### Week 5-6 — Phase 2 (AI Companion)
- OpenRouter API integration
- Chat UI
- Context management (what text to send to the LLM)

### Week 7+ — Phases 3-5
- Build one feature at a time
- Each phase is independent, do them in whatever order feels fun

---

## AI Context Strategy

The key challenge: LLMs have context limits, books are long.

**Approach:**
1. When the user asks a question, send:
   - Book title + author
   - Current chapter text (or a chunk around the current position)
   - The selected text (if any)
   - The user's question
2. For "remind me" / summaries:
   - Process chapter-by-chapter, generate + store summaries locally as the user finishes each chapter
   - Use stored summaries as context for recall questions
3. For character tracking:
   - After each chapter, ask LLM to extract/update character info
   - Store character entries locally, update incrementally

This keeps API costs low and avoids hitting context limits.

---

## Notes

- Build for Android first (Sukhrob's phone)
- No app store needed — build APK directly and install
- API key stored in local app settings
- All data stays on device
- No user accounts, no backend, no complexity
