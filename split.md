# Reader Screen Split Plan

## Goal

Split `lib/screens/reader_screen.dart` into a few high-impact files (not too many), while keeping behavior exactly the same.

Current size: ~4,640 lines.

## Target structure (small set of files)

- Keep: `lib/screens/reader_screen.dart` (main screen shell and core state)
- Add: `lib/screens/reader/reader_overlays.dart`
- Add: `lib/screens/reader/reader_content.dart`
- Add: `lib/screens/reader/reader_ai_sheets.dart`
- Add: `lib/screens/reader/reader_ai_flow.dart`
- Optional (only if needed): `lib/screens/reader/reader_models.dart`

Notes:

- Prefer using `part` / `part of` so private names (`_...`) can stay private with minimal churn.
- Keep file count low; do not create extra micro-files unless a session is blocked.

## Session rules for AI agents

1. Work on exactly one session task at a time.
2. Do not change behavior; this is a refactor-only split.
3. Keep public API of `ReaderScreen` unchanged.
4. Run tests after each session.
5. Update this file after each session:
   - mark status in "Task status board",
   - append a new entry in "Session completion log (append-only)" at the end.
6. Never delete previous completion log entries.

---

## Session 1 prompt - Scaffold split + move passive models/types

Use this exact prompt for one AI session:

```md
Task: Session 1 - Create split scaffold and move passive private types

Goal:
- Introduce split file scaffolding for ReaderScreen using part files.
- Move only passive types/classes/enums (no behavior logic yet).

Do:
1) Add part directives in `lib/screens/reader_screen.dart`.
2) Create:
   - `lib/screens/reader/reader_ai_flow.dart`
   - `lib/screens/reader/reader_ai_sheets.dart`
   - `lib/screens/reader/reader_overlays.dart`
   - `lib/screens/reader/reader_content.dart`
   - (optional) `lib/screens/reader/reader_models.dart`
3) Move helper types/enums/classes from the bottom of reader_screen.dart into the most appropriate new part file(s) without renaming behavior.
4) Keep compile/runtime behavior unchanged.

Validation:
- Run: `flutter test test/screens/reader_screen_test.dart`

Before finishing:
- Update `split.md` Task status board for Session 1.
- Append a Session completion log entry at the end of `split.md`.
```

---

## Session 2 prompt - Extract overlays (Highlights + Table of Contents)

```md
Task: Session 2 - Extract overlays into reader_overlays.dart

Goal:
- Move overlay-heavy methods out of `reader_screen.dart`.

Scope:
- Move highlight and TOC overlay methods to `lib/screens/reader/reader_overlays.dart`.
- Keep method names and call sites unchanged from the main screen.
- Use extension(s) on `_ReaderScreenState` if needed.

Primary candidates:
- `_showHighlights`
- `_showTableOfContents`
- Any tiny overlay-only helper methods they require

Validation:
- Run: `flutter test test/screens/reader_screen_test.dart`

Before finishing:
- Update `split.md` Task status board for Session 2.
- Append a Session completion log entry at the end of `split.md`.
```

---

## Session 3 prompt - Extract content rendering + selection toolbar

```md
Task: Session 3 - Extract content rendering into reader_content.dart

Goal:
- Move chapter rendering and selection-toolbar related code out of `reader_screen.dart`.

Scope:
- Move content-build methods into `lib/screens/reader/reader_content.dart`.
- Keep behavior and UI unchanged.

Primary candidates:
- `_buildBody`, `_buildError`, `_buildEmpty`, `_buildContent`
- `_buildChapterEndActions`, `_buildChapterNavigationButton`
- `_buildHighlightedText`
- `_buildSelectionToolbar`
- Optional: `_buildHiddenNavPill` if it keeps the file cleaner

Validation:
- Run: `flutter test test/screens/reader_screen_test.dart`

Before finishing:
- Update `split.md` Task status board for Session 3.
- Append a Session completion log entry at the end of `split.md`.
```

---

## Session 4 prompt - Extract AI sheets/widgets

```md
Task: Session 4 - Extract AI UI sheets/widgets into reader_ai_sheets.dart

Goal:
- Move AI UI components (bottom sheets, conversation widgets, error/loading widgets) into a dedicated file.

Scope:
- Move AI-related widget classes and sheet UI builders into `lib/screens/reader/reader_ai_sheets.dart`.
- Keep all UX behavior and labels the same.

Primary candidates:
- `_AiQuestionComposerSheet`
- `_AiConversationSheet` + `_AiConversationBubble`
- `_AiLoadingSheet`
- `_AiResultError`
- `_AiBasicError`
- Sheet methods that are purely UI composition

Validation:
- Run: `flutter test test/screens/reader_screen_test.dart`

Before finishing:
- Update `split.md` Task status board for Session 4.
- Append a Session completion log entry at the end of `split.md`.
```

---

## Session 5 prompt - Extract AI orchestration/flow

```md
Task: Session 5 - Extract AI request orchestration into reader_ai_flow.dart

Goal:
- Move AI orchestration and request flow methods out of the main screen file.

Scope:
- Move AI flow methods into `lib/screens/reader/reader_ai_flow.dart`.
- Keep state fields in main file if needed, but move as much behavior logic as possible.
- Preserve all request validation, streaming, fallback, and image-generation behavior.

Primary candidates:
- `_showTextAiSourceModePicker` and source-mode runners
- request-spec builders and AI feature spec methods
- stream/generation/provider/model helper methods
- AI request lifecycle methods (start, cancel, finish, fallback)
- image prompt/image generation flow methods

Validation:
- Run: `flutter test test/screens/reader_screen_test.dart`
- Run: `flutter test test/services/openrouter_service_test.dart test/services/gemini_service_test.dart`

Before finishing:
- Update `split.md` Task status board for Session 5.
- Append a Session completion log entry at the end of `split.md`.
```

---

## Session 6 prompt - Final cleanup + full regression

```md
Task: Session 6 - Cleanup, formatting, and full regression pass

Goal:
- Ensure split is complete, readable, and stable.

Scope:
- Clean imports and dead code.
- Keep `reader_screen.dart` focused on screen shell/lifecycle/core state.
- Run formatter on touched files.
- Ensure no behavior regressions.

Validation:
- Run: `flutter test`

Before finishing:
- Update `split.md` Task status board for Session 6.
- Append a Session completion log entry at the end of `split.md`.
```

---

## Task status board

- [ ] Session 1 - Scaffold split + move passive models/types
- [ ] Session 2 - Extract overlays
- [ ] Session 3 - Extract content rendering + selection toolbar
- [ ] Session 4 - Extract AI sheets/widgets
- [ ] Session 5 - Extract AI orchestration/flow
- [ ] Session 6 - Final cleanup + full regression

## Session completion log (append-only)

Each time an AI agent completes a session, append an entry to the end of this file using this template:

```md
### YYYY-MM-DD - Session X - <short title>
Status: completed | partial | blocked

What was done:
- ...

Files changed:
- `path/to/file`

Tests run:
- `flutter test <target>` - pass/fail

Risks / follow-ups:
- ...

Next session start point:
- ...
```
