# GitHub Sync Plan

## Goal

Add an optional manual sync feature for personal use.

Constraints:

- Remote storage is a single JSON file in a private GitHub repo.
- Sync is manual only: `Upload` and `Download`.
- EPUB files are not synced.
- Books are not synced.
- Generated images are not synced.
- AI request logs are not synced.
- The user imports the same EPUBs manually on each device.
- Sync should apply only to books that already exist locally.

Data to sync:

- Reading progress
- Highlights
- Resume markers
- Reader settings
- AI settings and model selections
- API keys only if explicitly enabled by the user

## Non-Goals

- No background sync
- No live conflict resolution UI
- No multi-user support
- No cloud database
- No Git clone workflow inside the app
- No merge of book libraries across devices

## Task 1: Stable Book Sync Identity

```text
Implement a stable per-book sync identity so the app can match the same EPUB across devices without syncing books.

Context:
- The user will manually import the same EPUB on each device.
- Existing local database rows are keyed by device-local integer book ids, so they cannot be used for cross-device sync.
- We need a stable sync key stored on each book.
- Prefer a content-based fingerprint derived from the EPUB file, not title/author matching.
- Pasted-text books do not need to be synced in v1 unless there is an easy stable identity; it is acceptable to leave them out of sync for now.

Scope:
- Add a new nullable or required sync key field to the books table with a migration.
- Compute the sync key during EPUB import.
- Backfill the sync key for existing imported EPUB books when possible.
- Expose any small helper needed to query books by sync key.
- Keep the change narrowly scoped to local identity only; do not implement cloud sync yet.

Deliverables:
- Database schema migration.
- Import path updated to populate sync key.
- Minimal code paths for reading books by sync key.
- Tests for migration/import behavior if the touched area already has tests nearby.

Done when:
- Two devices importing the same EPUB would produce the same sync key.
- Existing users can upgrade without losing data.
```

## Task 2: Local Sync Snapshot Export/Import

```text
Implement the local sync snapshot model and service for manual state sync, without any GitHub networking yet.

Context:
- Remote storage will be a single JSON file.
- The snapshot must contain only syncable state, keyed by stable book sync keys rather than local database ids.
- Books, EPUB files, generated images, and AI request logs must be excluded.
- Import should only apply per-book state to books that already exist locally.

Scope:
- Define a versioned sync snapshot JSON shape.
- Export reading progress, highlights, resume markers, reader settings, AI settings, model selections, and optional API keys.
- On import, map remote book state to local books via sync key.
- Skip entries for books missing locally.
- Use simple conflict handling:
  - last-write-wins for settings
  - for per-book records, prefer newer timestamps when available
- Add a clear option in the snapshot service to include or exclude API keys.
- Keep the code local-only for this task; no GitHub API integration yet.

Deliverables:
- Snapshot model(s).
- Snapshot export service.
- Snapshot import service.
- Small unit tests around serialization/import mapping/conflict behavior.

Done when:
- The app can export current syncable state to JSON and re-import it locally.
- Import does not create books.
- Import applies state only to existing matching books.
```

## Task 3: GitHub File Sync Service

```text
Implement a small GitHub-backed sync transport that uploads and downloads one JSON file from a private repository.

Context:
- This is for personal use, not a public multi-user feature.
- Use the GitHub REST API rather than git clone/push.
- The app should store enough config to know which repo/path to use.
- The transport layer should stay separate from UI and from the local snapshot logic.

Scope:
- Add a GitHub sync settings model for owner/repo/file path/token.
- Persist the GitHub sync settings locally.
- Implement download of the sync file contents.
- Implement upload/create/update of the sync file contents.
- Handle the GitHub file SHA as needed for updates.
- Provide clear error messages for bad token, missing repo, missing file, and network failures.
- Keep this task limited to service and persistence code; do not build the full settings UI yet.

Deliverables:
- GitHub sync config persistence.
- GitHub sync service for upload/download.
- Targeted tests for request construction and error handling where practical.

Done when:
- Given valid config and a JSON string, the app can upload it to a configured repo path.
- Given valid config, the app can download the JSON string from that path.
```

## Task 4: Settings UI and Manual Sync Actions

```text
Add the user-facing manual sync UI in Settings for configuring GitHub sync and running Upload/Download.

Context:
- Sync is optional and personal-use only.
- Keep the UX straightforward: configuration plus two manual buttons.
- The app already has a Settings screen; extend it instead of introducing a new navigation flow unless necessary.

Scope:
- Add fields for GitHub token, repo, and remote file path.
- Add a toggle for whether API keys are included in sync uploads.
- Add `Upload Sync State` and `Download Sync State` actions.
- Wire Upload to local snapshot export plus GitHub upload.
- Wire Download to GitHub download plus local snapshot import.
- Show success/failure feedback and basic progress state.
- Add a confirmation before destructive download behavior if local syncable state may be overwritten.
- Keep the implementation manual only; no automatic sync triggers.

Deliverables:
- Settings UI updates.
- Action handlers connected to services from Tasks 2 and 3.
- Small widget or integration-style tests only if the touched UI already has test coverage nearby.

Done when:
- A user can configure GitHub sync and manually upload/download from Settings.
- Download makes local state reflect the remote snapshot for matching books.
```

## Task 5: Final Hardening, Docs, and Cleanup

```text
Polish the manual GitHub sync feature, document it, and close the biggest reliability gaps without expanding scope.

Context:
- This feature is intentionally narrow and manual.
- We want clear docs and safe defaults, not more infrastructure.

Scope:
- Review the final flow for edge cases and tighten any rough spots.
- Document setup for a private GitHub repo and token.
- Document exactly what syncs and what does not sync.
- Document that books must be imported manually on each device.
- Ensure the sync snapshot format includes a schema version.
- Add or improve a few targeted tests if earlier tasks left obvious gaps.
- Do not add background sync, encryption, or broader cloud-provider support in this task.

Deliverables:
- README updates and any small in-app explanatory copy.
- Final cleanup/refactor only where it directly helps readability or reliability.
- Verification notes in the append-only log below.

Done when:
- Another AI coding session could pick up the repo and understand how to use and maintain the sync feature.
```

## Suggested Order

1. Task 1: Stable Book Sync Identity
2. Task 2: Local Sync Snapshot Export/Import
3. Task 3: GitHub File Sync Service
4. Task 4: Settings UI and Manual Sync Actions
5. Task 5: Final Hardening, Docs, and Cleanup

## Append-Only Execution Log

Rules for future AI agents:

- Do not edit or rewrite previous log entries.
- Only append new entries to the end of this section.
- Add one entry after each completed task or substantial follow-up.
- If a task was partially completed, say so explicitly.
- Include concrete file paths, verification steps, and any remaining risks.

Entry template:

```text
Date:
Task:
Thread/Agent:
Status:

What was done:
-

Files changed:
-

Verification:
-

Open issues / follow-ups:
-
```

```text
Date: 2026-04-04
Task: Task 1: Stable Book Sync Identity
Thread/Agent: T-019d588f-2823-71f7-9a94-bac78ac28617 / Amp
Status: Completed

What was done:
- Added a nullable `syncKey` field to `Book` and to the `books` table.
- Added schema migration to database version 8, including a `books.syncKey` index.
- Added `BookSyncIdentityService` to derive stable `epub-sha256:` sync keys from EPUB bytes.
- Updated EPUB import to compute and persist the sync key during local import.
- Added automatic backfill for existing imported EPUB rows whenever the database opens and the file is available locally.
- Added `DatabaseService.getBookBySyncKey` for future sync mapping.

Files changed:
- pubspec.yaml
- lib/models/book.dart
- lib/services/book_sync_identity_service.dart
- lib/services/database_service.dart
- lib/services/library_service.dart
- test/models/book_test.dart
- test/services/database_service_test.dart
- test/services/library_service_test.dart
- sync.md

Verification:
- Added model tests covering `syncKey` map/copy behavior.
- Added a database migration test covering version 7 -> 8, sync key backfill, and sync-key lookup.
- Added a library import test covering stable sync key generation during EPUB import.

Open issues / follow-ups:
- Pasted-text books intentionally remain unsynced in v1 and keep `syncKey = null`.
```
