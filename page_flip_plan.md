# Page Flip Plan

## Project Analysis

- The current reader is tightly coupled to scroll mode. The main implementation lives in `lib/screens/reader_screen.dart`, which is 4088 lines and uses a single `ScrollController` as the core reading-position primitive.
- Reading persistence is scroll-only today. `ReadingProgress` stores `chapterIndex` and `scrollOffset`, and the `progress` table mirrors that shape. `ResumeMarker` also stores `scrollOffset`, although it already has stable text anchors via `selectionStart` and `selectionEnd`.
- Text actions assume one full-chapter `SelectableText.rich`. Highlight, Resume Here, Catch Me Up, Simplify Text, Ask AI, Define & Translate, and Generate Image all read selection offsets from one large chapter string.
- The current reader content is plain text, not EPUB HTML layout. That is good for a first paginated mode because a pagination engine can work on text slices without solving rich layout yet.
- Settings already persist font, font size, theme, API keys, and AI model choices, but there is no reading mode setting.
- Existing automated coverage around the reader/settings/persistence seams is strong enough to use as a safety net.

## Baseline Verified On 2026-03-23

- `flutter test test/screens/reader_screen_test.dart`
- `flutter test test/services/settings_test.dart`
- `flutter test test/services/database_service_test.dart`

All three passed before this plan was written.

## Scope Decision

- MVP for this plan means paginated horizontal page turns with snap-based navigation.
- A literal page-curl animation is not part of the first delivery. It should only be attempted after pagination, persistence, and text actions are stable.
- Keep the current chapter-by-chapter reader structure. Page mode should paginate the current chapter, not redesign the whole book model.
- Persist page-mode location with a text anchor such as `contentOffset`, not with `pageIndex` alone. Page counts change when font size, font family, screen size, or safe-area geometry changes.
- Preserve scroll mode behavior while page mode is being added.
- Do not widen the project to rich EPUB rendering in the same workstream.

## Risks To Respect

- `SelectableText` inside a paginated UI will produce page-local offsets, so page mode must map local selection ranges back to chapter-global offsets.
- The current highlight model is text-based, not offset-based. That already causes repeated-text ambiguity in scroll mode; page mode should not try to solve that unless it becomes a blocker.
- Pagination depends on typography and viewport size. Restore logic must repaginate first, then resolve the saved anchor to a page.
- The current reader screen and reader widget tests are large. Refactor work should create seams before major feature work, not after.

## Session Workflow

1. Start every new AI session by reading this file and the latest entry in `## Session Summaries`.
2. Implement one numbered task at a time unless the task clearly finishes early and the tests are green.
3. Do not silently expand scope. If a task uncovers a blocker, document it in the session summary before moving on.
4. After each completed task, append a short summary to `## Session Summaries` with files changed, tests run, and follow-up notes.
5. Keep scroll mode working until the final hardening task is done.

## Recommended Task Order

### Task 1: Add Reading Mode To Settings

Why this task exists:
- A persisted feature flag is the safest first seam. It lets later sessions branch behavior without guessing state.

Definition of done:
- Add a new reader setting with values `scroll` and `pageFlip`.
- Default remains `scroll`.
- Persist it through `ReaderSettings`, `SettingsService`, and `SettingsController`.
- Expose it in `SettingsScreen`.
- Add or update tests for settings model, settings service/controller, and settings screen.
- Do not change reader behavior yet.

Likely files:
- `lib/models/reader_settings.dart`
- `lib/services/settings_service.dart`
- `lib/services/settings_controller.dart`
- `lib/screens/settings_screen.dart`
- `test/models/reader_settings_test.dart`
- `test/services/settings_test.dart`
- `test/screens/settings_screen_test.dart`

Prompt to use for this session:

```text
Read page_flip_plan.md first and check the latest session summary.
Implement Task 1 only.
Add a persisted reader setting named readingMode with values scroll and pageFlip.
Default must remain scroll.
Expose the control in Settings UI in a way that matches the existing font/theme controls.
Do not change ReaderScreen behavior yet.
Update all affected settings/model/widget tests.
When done, append a Task 1 summary to page_flip_plan.md.
```

Recommended tests:
- `flutter test test/models/reader_settings_test.dart`
- `flutter test test/services/settings_test.dart`
- `flutter test test/screens/settings_screen_test.dart`

### Task 2: Add Mode-Neutral Reading Progress Persistence

Why this task exists:
- Page mode needs a restore anchor that survives repagination. `scrollOffset` is not enough.

Definition of done:
- Extend `ReadingProgress` with a nullable text anchor field such as `contentOffset`.
- Keep `scrollOffset` for backward compatibility and for scroll mode.
- Add a database migration for the `progress` table.
- Leave `ResumeMarker` schema alone unless a small compatibility helper is clearly needed.
- Update database and model tests.
- Do not expose new UI yet.

Likely files:
- `lib/models/reading_progress.dart`
- `lib/services/database_service.dart`
- `test/models/reading_progress_test.dart`
- `test/services/database_service_test.dart`

Prompt to use for this session:

```text
Read page_flip_plan.md first and check the latest session summary.
Implement Task 2 only.
Add a mode-neutral reading anchor to persisted progress, preferably a nullable contentOffset that stores an absolute character offset inside the current chapter.
Keep scrollOffset for backward compatibility.
Add the required database migration and update the ReadingProgress model/tests.
Do not change visible reader behavior yet except for plumbing that is required to compile.
When done, append a Task 2 summary to page_flip_plan.md.
```

Recommended tests:
- `flutter test test/models/reading_progress_test.dart`
- `flutter test test/services/database_service_test.dart`

### Task 3: Extract Scroll Reader Seams Before Feature Work

Why this task exists:
- `reader_screen.dart` is too large to safely absorb page mode without first separating body rendering and position-saving logic.

Definition of done:
- Split the current scroll-mode implementation into smaller reader-focused helpers or widgets.
- Create a shared abstraction for restoring and saving reader location based on the active reading mode.
- Keep visible scroll-mode behavior unchanged.
- Avoid rewriting AI flows unless extraction requires small interface changes.
- Update reader tests only as needed to preserve current behavior.

Likely files:
- `lib/screens/reader_screen.dart`
- New reader-focused helper files under `lib/`
- `test/screens/reader_screen_test.dart`

Prompt to use for this session:

```text
Read page_flip_plan.md first and check the latest session summary.
Implement Task 3 only.
Refactor the current scroll reader into smaller, reader-focused helpers so page mode can be added without making ReaderScreen worse.
Create a shared seam for saving/restoring reader location by mode, but keep the current scroll-mode UX unchanged.
Do not add page pagination yet.
Preserve all existing reader behavior and update tests only where structure changes require it.
When done, append a Task 3 summary to page_flip_plan.md.
```

Recommended tests:
- `flutter test test/screens/reader_screen_test.dart`

### Task 4: Build A Pure Pagination Engine

Why this task exists:
- Pagination should be testable without the full reader UI.

Definition of done:
- Add a service or helper that paginates plain text into page slices using Flutter text measurement.
- Each page slice should know at least `startOffset`, `endOffset`, and rendered text.
- Add anchor lookup helpers so a saved `contentOffset` can be mapped back to a page index after repagination.
- Cover short text, long text, empty text, and repagination after font or viewport changes.
- Do not integrate into the main reader UI yet beyond any minimal plumbing needed for future tasks.

Likely files:
- New pagination helper/service files under `lib/`
- New pagination tests under `test/`

Prompt to use for this session:

```text
Read page_flip_plan.md first and check the latest session summary.
Implement Task 4 only.
Create a pagination engine for the current plain-text chapter model.
Use Flutter text measurement, not rough word counts.
Each page slice must carry stable character offsets so later page-local selections can be mapped back to chapter-global offsets.
Add focused tests for pagination boundaries, empty/short chapters, and restoring a page from a saved contentOffset after layout changes.
Do not wire the engine into ReaderScreen yet unless a tiny amount of plumbing is required.
When done, append a Task 4 summary to page_flip_plan.md.
```

Recommended tests:
- New pagination-specific test file(s)

### Task 5: Add A PageView-Based Reader Body

Why this task exists:
- This is the first task that makes page mode visibly real, but it still keeps scope limited to reading and persistence.

Definition of done:
- Add a page-mode reader body behind `readingMode == pageFlip`.
- Use the pagination engine to render chapter text as pages in a horizontal `PageView`.
- Restore the current page from persisted `contentOffset`.
- Save `contentOffset` when the visible page changes.
- Keep chapter-level navigation model intact. Previous/next chapter controls can stay explicit instead of swipe-across-chapter.
- Keep scroll mode untouched.

Likely files:
- `lib/screens/reader_screen.dart`
- Extracted reader helper/widget files from Task 3
- Pagination files from Task 4
- `test/screens/reader_screen_test.dart`

Prompt to use for this session:

```text
Read page_flip_plan.md first and check the latest session summary.
Implement Task 5 only.
Add a pageFlip reader body using PageView and the pagination engine.
Use contentOffset as the persisted restore anchor for page mode.
Keep chapter navigation chapter-based for now; do not redesign the whole reader flow.
Preserve scroll mode exactly.
Add reader widget tests for basic page navigation and restore behavior in page mode.
When done, append a Task 5 summary to page_flip_plan.md.
```

Recommended tests:
- `flutter test test/screens/reader_screen_test.dart`

### Task 6: Make Text Selection Features Work In Page Mode

Why this task exists:
- The reader is not complete if page mode can read text but cannot use the existing selection-driven workflows.

Definition of done:
- Each rendered page supports text selection.
- Page-local selections are translated back to chapter-global offsets.
- The existing context menu actions work in page mode: Highlight, Resume Here, Catch Me Up, Simplify Text, Ask AI, Define & Translate, and Generate Image.
- Resume marker highlighting and restore behavior work in page mode.

Likely files:
- `lib/screens/reader_screen.dart`
- Reader helper/widget files created earlier
- `lib/services/resume_summary_service.dart` if small helpers are needed
- `test/screens/reader_screen_test.dart`

Prompt to use for this session:

```text
Read page_flip_plan.md first and check the latest session summary.
Implement Task 6 only.
Make pageFlip mode feature-complete for selection-driven reader actions.
Each page must support selection, and page-local offsets must be mapped back to chapter-global offsets before calling existing highlight/resume/AI flows.
Do not rewrite the AI logic unless a narrow adapter is needed.
Add focused reader tests that prove at least one selection flow from each major category works in page mode.
When done, append a Task 6 summary to page_flip_plan.md.
```

Recommended tests:
- `flutter test test/screens/reader_screen_test.dart`

### Task 7: Connect Page Mode To Reader Chrome And Cross-Entry Navigation

Why this task exists:
- Page mode still needs to work with TOC, highlight jumps, progress display, and mode changes.

Definition of done:
- TOC navigation lands on the right chapter and page.
- Highlight list taps land on the right chapter and nearest page.
- Resume restore uses `selectionStart` or persisted anchor correctly in page mode.
- App bar and hidden navigation pill show mode-aware progress information.
- Switching between modes preserves approximate reading location instead of resetting the user.

Likely files:
- `lib/screens/reader_screen.dart`
- Reader helper/widget files
- `test/screens/reader_screen_test.dart`

Prompt to use for this session:

```text
Read page_flip_plan.md first and check the latest session summary.
Implement Task 7 only.
Connect pageFlip mode to the rest of the reader chrome and entry points.
TOC jumps, highlight jumps, and resume restore must land on the correct chapter and page.
Switching between scroll and pageFlip should preserve approximate reading position instead of dumping the user at the top.
Add or update reader widget tests for these navigation paths.
When done, append a Task 7 summary to page_flip_plan.md.
```

Recommended tests:
- `flutter test test/screens/reader_screen_test.dart`

### Task 8: Hardening, Performance, And Optional Animation Polish

Why this task exists:
- Pagination and page mode will need one cleanup pass before the work is ready to trust.

Definition of done:
- Add pagination caching keyed by chapter content plus layout inputs if performance needs it.
- Handle repagination on font change, size change, and orientation/window changes without losing the user's place.
- Run `flutter analyze`.
- Run the relevant test suite again.
- Update `README.md` if page mode is ready for users.
- Only now consider a literal page-curl animation, and only if it can sit on top of the stable paginated state model without breaking selection or restore behavior.

Likely files:
- Reader helper/widget files
- `lib/screens/reader_screen.dart`
- `README.md`
- Relevant tests

Prompt to use for this session:

```text
Read page_flip_plan.md first and check the latest session summary.
Implement Task 8 only.
Harden pageFlip mode for real use: performance, repagination, font/size changes, and final verification.
If pagination caching is needed, add it behind clear layout keys.
Run flutter analyze and the relevant test suite.
Only attempt a literal page-curl animation if the existing pageFlip mode is already stable; otherwise document why it should stay out.
When done, append a Task 8 summary to page_flip_plan.md.
```

Recommended checks:
- `flutter analyze`
- `flutter test`

## Session Summaries

### Summary Template

```text
#### YYYY-MM-DD - Task N
- Files changed:
- Behavior changes:
- Tests run:
- Open follow-ups:
```

#### 2026-03-23 - Initial Plan
- Files analyzed: `lib/screens/reader_screen.dart`, `lib/screens/settings_screen.dart`, `lib/models/reader_settings.dart`, `lib/models/reading_progress.dart`, `lib/models/resume_marker.dart`, `lib/services/settings_service.dart`, `lib/services/settings_controller.dart`, `lib/services/database_service.dart`, `lib/services/resume_summary_service.dart`, and related tests.
- Key finding: current reader architecture is scroll-centric at the UI, persistence, and selection-action levels.
- Key decision: first ship page-based snap navigation on top of the plain-text chapter model; defer literal page-curl animation until the state model is stable.
- Baseline verification: targeted reader/settings/database tests passed before planning.

#### 2026-03-23 - Task 1
- Files changed: `lib/models/reader_settings.dart`, `lib/services/settings_service.dart`, `lib/services/settings_controller.dart`, `lib/screens/settings_screen.dart`, `test/models/reader_settings_test.dart`, `test/services/settings_test.dart`, and `test/screens/settings_screen_test.dart`.
- Behavior changes: added a persisted `readingMode` setting with `scroll` and `pageFlip` values, defaulted it to `scroll`, and exposed it in Settings with chip controls; reader behavior remains unchanged.
- Tests run: `flutter test test/models/reader_settings_test.dart`, `flutter test test/services/settings_test.dart`, and `flutter test test/screens/settings_screen_test.dart`.
- Open follow-ups: Task 2 should add a mode-neutral progress anchor before `readingMode` is used by `ReaderScreen`.

#### 2026-03-23 - Task 2
- Files changed: `lib/models/reading_progress.dart`, `lib/services/database_service.dart`, `test/models/reading_progress_test.dart`, and `test/services/database_service_test.dart`.
- Behavior changes: added nullable `contentOffset` to `ReadingProgress` for mode-neutral chapter anchors while keeping `scrollOffset`; upgraded database schema to version 7 with a `progress.contentOffset` migration path from older databases.
- Tests run: `flutter test test/models/reading_progress_test.dart` and `flutter test test/services/database_service_test.dart`.
- Open follow-ups: `ReaderScreen` still persists `scrollOffset` only; Task 3 should add shared mode-aware location plumbing before page mode UI work.
