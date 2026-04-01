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

- [x] Task 1 - Shared streaming primitives and SSE parsing helper
- [x] Task 2 - OpenRouter streaming service API
- [x] Task 3 - Gemini streaming service API
- [x] Task 4 - Reader provider-agnostic streaming bridge
- [x] Task 5 - Initial response UX: thinking indicator -> streaming bottom sheet
- [x] Task 6 - Conversation sheet streaming state (initial assistant message)
- [x] Task 7 - Follow-up streaming in bottom sheet (phase 2)
- [x] Task 8 - Regression pass, tests, and rollout safety

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

### 2026-03-31 - Task 1 - Shared streaming primitives and SSE parser
Status: completed

What was done:
- Added a shared AI text streaming event model with delta/done/error variants.
- Implemented a reusable incremental SSE decoder that supports partial lines across chunks, blank-line event boundaries, comments, and `[DONE]` marker detection.
- Added parser-focused unit tests covering split chunks, multiple events per chunk, comment handling, done markers, CRLF handling, and close behavior.

Files changed:
- `lib/models/ai_text_stream_event.dart`
- `lib/services/sse_decoder.dart`
- `test/services/sse_decoder_test.dart`
- `streaming_plan.md`

Tests run:
- `flutter test test/services/sse_decoder_test.dart` - pass

Follow-ups / risks:
- Decoder emits only `data:` events; provider-specific payload decoding and error mapping still need to be implemented in service layers.
- `close(emitIncompleteEvent: false)` drops trailing non-delimited events by default; callers must opt in if they need final partial flush behavior.

Next session start point:
- Start Task 2 by adding OpenRouter streaming API methods that use `SseDecoder` and map chunks to `AiTextStreamEvent`.

### 2026-03-31 - Task 2 - OpenRouter streaming service API
Status: completed

What was done:
- Added OpenRouter streaming APIs via `streamText(...)` and `streamTextMessages(...)` while keeping existing non-stream `generateText*` and image flows unchanged.
- Implemented SSE streaming request mode (`stream: true`, `Accept: text/event-stream`) and mapped incoming SSE `data:` payloads to `AiTextStreamEvent` deltas, done markers (`[DONE]`), and error events.
- Added stream payload parsing for `choices[0].delta.content` (string and list parts), provider error extraction for mid-stream error payloads, and retained existing request logging/error messaging patterns.

Files changed:
- `lib/services/openrouter_service.dart`
- `test/services/openrouter_service_test.dart`
- `streaming_plan.md`

Tests run:
- `flutter test test/services/openrouter_service_test.dart` - pass

Follow-ups / risks:
- Stream method currently emits `AiTextStreamEvent.error(...)` on mid-stream error payloads and ends stream; consumer-side UI handling for error-event rendering/fallback is part of later reader tasks.
- Streaming completion currently treats `[DONE]` as canonical done signal and emits a final `done` when the stream closes without it; this is intentional for resilience but should be validated end-to-end in reader integration.

Next session start point:
- Start Task 3 by adding Gemini streaming methods and SSE mapping with the same `AiTextStreamEvent` contract.

### 2026-03-31 - Task 3 - Gemini streaming service API
Status: completed

What was done:
- Added Gemini streaming APIs via `streamText(...)` and `streamTextMessages(...)` while keeping existing non-stream `generateText*` and image flows unchanged.
- Implemented Gemini SSE request mode using `:streamGenerateContent?alt=sse` with `Accept: text/event-stream`, and reused generation payload parity (temperature/thinkingConfig/safetySettings) with the non-stream path.
- Added SSE payload mapping for chunked `GenerateContentResponse` data to `AiTextStreamEvent` deltas, `[DONE]` completion, and mid-stream error events; empty/no-text chunks are ignored safely.

Files changed:
- `lib/services/gemini_service.dart`
- `test/services/gemini_service_test.dart`
- `streaming_plan.md`

Tests run:
- `flutter test test/services/gemini_service_test.dart` - pass

Follow-ups / risks:
- Stream method emits `AiTextStreamEvent.error(...)` for mid-stream Gemini error payloads and ends the stream; reader-side UX handling for these events is covered by later tasks.
- Gemini stream endpoint retries only on request-level transient failures/status codes before streaming starts; in-stream semantic errors are surfaced as stream error events by design.

Next session start point:
- Start Task 4 by adding a reader-level provider-agnostic streaming bridge that selects OpenRouter vs Gemini stream methods.

### 2026-03-31 - Task 4 - Reader provider-agnostic streaming bridge
Status: completed

What was done:
- Added reader-level provider-agnostic streaming helpers in `ReaderScreen` for both prompt-based and message-based text flows.
- Switched reader text generation paths to aggregate provider stream events (`delta`/`done`/`error`) into final text while preserving existing request/model/key validation behavior.
- Added stream-aware reader tests by extending fake AI services with streaming overrides and asserting that initial and follow-up flows route through stream methods.

Files changed:
- `lib/screens/reader_screen.dart`
- `test/screens/reader_screen_test.dart`
- `streaming_plan.md`

Tests run:
- `flutter test test/screens/reader_screen_test.dart` - pass

Follow-ups / risks:
- Reader now consumes stream APIs but still waits for fully aggregated text before opening/rendering result UI; first-chunk UX transition remains for Task 5.
- Fake reader test services currently adapt stream methods by wrapping existing non-stream handlers; dedicated chunk-by-chunk UI streaming behavior still needs explicit coverage in later tasks.

Next session start point:
- Start Task 5 by wiring initial request UX to first-chunk stream events (keep loading indicator until first chunk, then open and append in sheet live).

### 2026-03-31 - Task 5 - Initial response UX streaming transition
Status: completed

What was done:
- Replaced initial text feature request flow in `ReaderScreen` to consume provider stream events directly instead of waiting for a fully aggregated response.
- Added initial request phase handling (`idle`, `waitingForFirstChunk`, `streaming`, `complete`, `failed`) so the existing loading indicator remains visible until the first delta arrives.
- Added a streaming preview bottom sheet that appears on first chunk and appends assistant text live while the stream is active, then transitions to the existing conversation/error result sheets after completion/failure.
- Preserved existing pre-first-chunk failure behavior by routing stream-start failures to the existing error sheet UX.
- Extended reader widget tests to cover the first-chunk transition and pre-first-chunk error case, and extended fake services with stream handler overrides for deterministic chunk-by-chunk tests.

Files changed:
- `lib/screens/reader_screen.dart`
- `test/screens/reader_screen_test.dart`
- `streaming_plan.md`

Tests run:
- `flutter test test/screens/reader_screen_test.dart` - pass

Follow-ups / risks:
- The streaming preview sheet is intentionally read-only for the initial response path; full in-sheet conversation streaming state (single growing assistant bubble and disabled send/actions while initial stream is unfinished) is still Task 6 scope.
- Follow-up message path still uses complete-response behavior in `_AiConversationSheet` and should be upgraded separately in Task 7.

Next session start point:
- Start Task 6 by making `_AiConversationSheet` render the initial assistant response as one in-progress bubble that grows during streaming and keep actions disabled until the initial stream completes.

### 2026-03-31 - Task 6 - Initial conversation sheet streaming state
Status: completed

What was done:
- Replaced the temporary read-only streaming preview with the real `_AiConversationSheet` for the initial response path.
- Made `_AiConversationSheet` accept parent-driven initial message updates so the first assistant response grows inside a single bubble while streaming.
- Disabled copy/regenerate/switch/send/composer interactions until the initial stream completes, while keeping the close button as a cancel action during streaming.
- Kept the same pinned sheet open after completion instead of closing it and reopening a separate modal, so the final assistant bubble matches the streamed text exactly.
- Updated reader widget tests to cover the locked streaming state and the unlocked completed state for the same sheet.

Files changed:
- `lib/screens/reader_screen.dart`
- `test/screens/reader_screen_test.dart`
- `streaming_plan.md`

Tests run:
- `flutter test test/screens/reader_screen_test.dart` - pass

Follow-ups / risks:
- Follow-up messages inside `_AiConversationSheet` still resolve as full responses; live follow-up streaming remains Task 7.
- Mid-stream failures after at least one chunk still fall back to the existing error-sheet path instead of preserving partial text inline.

Next session start point:
- Start Task 7 by changing `_AiConversationSheet.onSendFollowUp` from a complete-response future into a streaming callback and append follow-up assistant chunks in place.

### 2026-04-01 - Task 7 - Follow-up streaming in bottom sheet (phase 2)
Status: completed

What was done:
- Upgraded `_AiConversationSheet.onSendFollowUp` from a `Future<String>` callback to a streaming callback and switched all follow-up call sites to provider stream APIs.
- Reworked follow-up send flow to append the user message, create one in-progress assistant bubble, append deltas chunk-by-chunk, and finalize the same bubble on completion.
- Preserved inline follow-up error behavior and improved it for streaming by keeping partial assistant text visible when an error arrives after some chunks.
- Added/updated widget tests to verify live follow-up streaming in the open sheet, disabled composer state while streaming, and inline error visibility with partial streamed output.

Files changed:
- `lib/screens/reader_screen.dart`
- `test/screens/reader_screen_test.dart`
- `streaming_plan.md`

Tests run:
- `flutter test test/screens/reader_screen_test.dart` - pass

Follow-ups / risks:
- Follow-up stream error mapping in `_AiConversationSheet` now normalizes stream error events into user-facing inline text, but provider-specific exception typing is intentionally not surfaced in-sheet.
- Task 8 still needs broader regression/edge-case validation across service layers and cancellation paths beyond this widget-focused pass.

Next session start point:
- Start Task 8: run full streaming regression pass (services + reader), add targeted cancel/error edge tests, and document rollout safety notes.

### 2026-04-01 - Task 8 - Regression pass, tests, and rollout safety
Status: completed

What was done:
- Added targeted streaming regression tests for OpenRouter and Gemini service layers to cover stream-close-without-`[DONE]` fallback completion and malformed SSE JSON error handling.
- Added reader streaming regression tests for cancel and error edge cases in the first-chunk transition path:
  - cancel from active streaming sheet ignores late chunks/completion,
  - error after first chunk returns to existing error sheet behavior.
- Added rollout safety notes and a manual smoke checklist to `README.md` under a new "Streaming Rollout Notes" section.

Files changed:
- `test/services/openrouter_service_test.dart`
- `test/services/gemini_service_test.dart`
- `test/screens/reader_screen_test.dart`
- `README.md`
- `streaming_plan.md`

Tests run:
- `flutter test test/services/openrouter_service_test.dart test/services/gemini_service_test.dart test/screens/reader_screen_test.dart` - pass
- `flutter test` - pass

Follow-ups / risks:
- Manual on-device smoke validation is still recommended before production rollout (the README checklist now captures the required path checks).
- Debug payload logs in service tests are expected in test output and are non-blocking.

Next session start point:
- Streaming migration plan is complete; next work can focus on unrelated feature backlog or post-rollout telemetry/monitoring.
