# Streaming Migration Plan

## Goal

Migrate text AI responses from "wait for full response" to true streaming.

## Reference docs (keep for future sessions)

- OpenRouter Streaming API:
  - https://openrouter.ai/docs/api/reference/streaming
- Gemini streaming responses:
  - https://ai.google.dev/gemini-api/docs/text-generation#streaming-responses

Key protocol notes from docs:

- OpenRouter uses chat-completions SSE with `stream: true` and chunked delta payloads.
- Gemini uses `:streamGenerateContent?alt=sse` for REST streaming.

Target UX:

1. User triggers an AI text request.
2. Show the current loading UI ("thinking" indicator) immediately.
3. As soon as the first chunk arrives, hide loading UI and open the AI bottom sheet.
4. Append chunks in real time in the assistant response area.
5. Keep existing fallback/error behavior.

## Constraints

- Keep each task small enough for one coding-agent session.
- Avoid breaking existing non-stream image flows.
- Preserve current cancellation semantics where possible.
- Add tests with each task, not only at the end.

## AI agent instructions (must follow every session)

1. Work on exactly one task per session (or one clearly scoped sub-part of a task).
2. Implement only that task's scope and deliverables.
3. Run relevant tests before finishing the session.
4. If blocked, document the blocker in the handoff log instead of silently skipping.
5. After implementation, update this file in two places:
   - mark task status in the "Task status board",
   - append a new entry in "Session handoff log (append-only)".
6. Never delete previous handoff entries; only append.
7. In each handoff entry include:
   - what was implemented,
   - files changed,
   - tests run and results,
   - follow-ups/risks for next session.

## Task 1 - Shared streaming primitives and SSE parsing helper

### Scope

- Introduce reusable stream primitives for text streaming.
- Add a minimal SSE parser helper that converts byte chunks into logical SSE `data:` events.

### Deliverables

- New lightweight model(s), e.g. stream delta/final/error event structures.
- Helper for incremental SSE line parsing (supports partial lines across chunks).
- Unit tests for parser behavior.

### Suggested files

- `lib/models/ai_text_stream_event.dart` (new)
- `lib/services/sse_decoder.dart` (new)
- `test/services/sse_decoder_test.dart` (new)

### Done when

- Parser handles:
  - split/chunked lines,
  - multiple events per chunk,
  - comment lines (`:`),
  - `[DONE]` markers,
  - blank line event boundaries.

---

## Task 2 - OpenRouter streaming service API

### Scope

- Add streaming text method(s) to `OpenRouterService`.
- Use OpenRouter SSE mode (`stream: true`).
- Keep current non-stream APIs working.

### Deliverables

- New streaming methods, e.g. `streamText(...)` and/or `streamTextMessages(...)`.
- Proper request payload with `stream: true`.
- SSE parsing for `choices[0].delta.content`, `[DONE]`, and mid-stream errors.
- Existing `generateText*` can optionally aggregate stream internally or stay as-is.

### Suggested files

- `lib/services/openrouter_service.dart`
- `test/services/openrouter_service_test.dart`

### Done when

- Streaming emits text deltas in order.
- Mid-stream error event is surfaced as exception/event.
- Non-stream methods still pass existing tests.

---

## Task 3 - Gemini streaming service API

### Scope

- Add streaming text method(s) to `GeminiService`.
- Use Gemini streaming endpoint (`:streamGenerateContent?alt=sse`).
- Keep current non-stream APIs working.

### Deliverables

- New `streamText*` methods for Gemini.
- Streaming request path and payload parity with existing generation config.
- SSE parsing for chunked `GenerateContentResponse` payloads.

### Suggested files

- `lib/services/gemini_service.dart`
- `test/services/gemini_service_test.dart`

### Done when

- Streaming emits incremental text for normal responses.
- Handles empty/no-text chunks safely.
- Existing non-stream behavior unchanged.

---

## Task 4 - Reader provider-agnostic streaming bridge

### Scope

- Add one reader-level abstraction that selects provider streaming method.
- Keep current model/key selection and validation flow.

### Deliverables

- New helper(s) in `ReaderScreen` to start text stream by provider and model.
- Reuse existing model selection logic from `_generateTextForSelection` / `_generateTextForMessages`.

### Suggested files

- `lib/screens/reader_screen.dart`
- (Optional) `lib/services/ai_text_stream_service.dart` (new)

### Done when

- Reader can request a `Stream` of deltas for:
  - initial feature prompt,
  - chat follow-up messages (API-ready, even if UI not switched yet).

---

## Task 5 - Initial response UX: thinking indicator -> streaming bottom sheet

### Scope

- Replace "wait for full response" initial text flow with streaming.
- Keep current loading indicator visible until first chunk.
- Open bottom sheet on first chunk and keep appending content.

### Deliverables

- State machine for initial request:
  - waiting for first chunk,
  - streaming active,
  - complete,
  - failed.
- Existing loading UI shown before first chunk.
- Bottom sheet opens with partial assistant text once stream starts.

### Suggested files

- `lib/screens/reader_screen.dart`

### Done when

- User sees "thinking" indicator first.
- Bottom sheet appears as soon as first chunk arrives (not after completion).
- Text updates continuously while stream is active.
- Error before first chunk uses existing error sheet behavior.

---

## Task 6 - Conversation sheet streaming state (initial assistant message)

### Scope

- Make `_AiConversationSheet` capable of rendering an in-progress assistant message.
- Do this first for initial response path.

### Deliverables

- Sheet supports editable/appendable assistant message while stream is live.
- "Send" / actions properly disabled while initial stream is unfinished.

### Suggested files

- `lib/screens/reader_screen.dart`
- `test/screens/reader_screen_test.dart`

### Done when

- Streaming text appears in one assistant bubble as it grows.
- No duplicate bubbles per chunk.
- Final bubble is identical to non-stream final text once completed.

---

## Task 7 - Follow-up streaming in bottom sheet (phase 2)

### Scope

- Upgrade follow-up message send path from `Future<String>` to stream.
- Keep same UX pattern inside the already-open sheet.

### Deliverables

- `onSendFollowUp` supports streaming callback.
- While user sends follow-up:
  - append user message,
  - create in-progress assistant message,
  - append chunks,
  - finalize or show inline error.

### Suggested files

- `lib/screens/reader_screen.dart`
- `test/screens/reader_screen_test.dart`

### Done when

- Follow-up responses stream live without closing/reopening the sheet.
- Existing follow-up error handling remains visible inline.

---

## Task 8 - Regression pass, tests, and rollout safety

### Scope

- Stabilize migration with targeted tests and manual checks.

### Deliverables

- Update/add tests for:
  - OpenRouter streaming,
  - Gemini streaming,
  - reader first-chunk transition,
  - cancel/error edge cases.
- Small rollout notes in project docs.

### Suggested files

- `test/services/openrouter_service_test.dart`
- `test/services/gemini_service_test.dart`
- `test/screens/reader_screen_test.dart`
- `README.md` (optional short note)

### Done when

- `flutter test` passes.
- No regressions in non-stream text/image features.
- Manual smoke check confirms required UX.

---

## Recommended execution order

1. Task 1
2. Task 2
3. Task 3
4. Task 4
5. Task 5
6. Task 6
7. Task 7 (optional for first release)
8. Task 8

## First release cut suggestion

For fastest value with minimal risk, ship after Task 6:

- Initial AI response streams with the required UX.
- Follow-up streaming can be delivered in Task 7 as a second increment.

---

## Task status board

- [ ] Task 1 - Shared streaming primitives and SSE parsing helper
- [ ] Task 2 - OpenRouter streaming service API
- [ ] Task 3 - Gemini streaming service API
- [ ] Task 4 - Reader provider-agnostic streaming bridge
- [ ] Task 5 - Initial response UX: thinking indicator -> streaming bottom sheet
- [ ] Task 6 - Conversation sheet streaming state (initial assistant message)
- [ ] Task 7 - Follow-up streaming in bottom sheet (phase 2)
- [ ] Task 8 - Regression pass, tests, and rollout safety

## Session handoff log (append-only)

Use this template for every completed or partial session:

```md
### YYYY-MM-DD - Task X - <short title>
Status: completed | partial | blocked

What was done:
- ...

Files changed:
- `path/to/file`

Tests run:
- `flutter test <target>` - pass/fail

Follow-ups / risks:
- ...

Next session start point:
- ...
```
