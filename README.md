# BookAI

BookAI is an EPUB and pasted-text reader with AI. It can explain difficult words, translate text, answer questions about a passage, give a short recap, make difficult text easier to understand, and generate images from scenes in the book. To use these features, you need an OpenRouter or Gemini API key. Both offer free usage with limits.

> For my students: if you figure out how to build this app from source code, install it on your phone, set up the API keys, and open an issue or pull request on GitHub, you are going to make it.

## What BookAI Does

- Import EPUB files or paste text into an on-device library
- Read chapter by chapter with saved progress
- Highlight passages and save a manual "resume here" point
- Keep generated images in a separate library tab
- Let you choose your own AI provider and models instead of relying on a BookAI backend

## AI Features

- **Resume Here and Catch Me Up**: Creates a short catch-up from selected text or from the range between your last resume point and the current selection.
- **Simplify Text**: Rewrites a passage in clearer, simpler language without intentionally turning it into a summary.
- **Ask AI**: Answers questions about a selected passage and supports follow-up chat.
- **Define & Translate**: Explains a selected word, phrase, or character name in context and translates it. The default prompt translates into Russian.
- **Generate Image**: Turns a passage into an image prompt, lets you refine that prompt, then sends it to an image-capable model and saves the returned image locally.

Advanced configuration is built in:

- Choose a default text model
- Set a fallback text model
- Choose a separate image model
- Override the prompt template and text model for each AI feature

## Streaming Rollout Notes

- Text features now use incremental streaming for both the initial answer and follow-up messages in the AI conversation sheet.
- Reader UX keeps the compact "thinking" loading state until the first chunk arrives, then switches to the live conversation sheet.
- Cancel semantics are preserved: canceling an active request dismisses the current AI UI state and ignores late chunks.
- Error semantics are preserved: errors before first chunk use the existing error sheet, while follow-up stream errors remain inline with partial assistant text.

Recommended release smoke checklist:

- Trigger **Define & Translate** and confirm loading indicator appears first, then the response streams live in one assistant bubble.
- Send at least one follow-up and confirm response streams in-place without closing/reopening the sheet.
- Cancel one request from loading state and one from streaming state; confirm no late text appears after cancel.
- Run one **Generate Image** request to verify non-stream image flow remains unchanged.

## OpenRouter and Gemini Keys

BookAI does not ship with shared API keys, and it does not ask users to set environment variables. End users add keys directly inside the app:

1. Open **Settings**.
2. Paste an **OpenRouter API Key** (`sk-or-v1-...`) and/or a **Gemini API Key** (`AIza...`).
3. Pick a **Default Model** for text features.
4. Optionally pick a **Fallback Model** for retries.
5. Pick an **Image Model** if you want to use **Generate Image**.
6. Optionally customize prompt templates or per-feature model overrides.

Notes:

- You only need a provider key if you want AI features.
- You can use either provider for text features.
- You can mix providers, for example one provider for text and another for image generation.

## What Stays Local

BookAI is local-first by default.

Stored locally on the device:

- Imported EPUB files copied into app-local storage
- Library metadata and parsed chapters in the local database
- Reading progress
- Highlights
- Resume markers
- Generated image files and their saved prompt metadata
- API keys
- Selected models
- Theme, font, and AI feature settings

By default this state stays local. If you enable **Settings -> Sync**, selected syncable state can be uploaded manually to your private GitHub repository.

What leaves the device when you use AI:

- The selected text or resume range you chose
- Context sentence, book title, author, and chapter title when the feature prompt uses them
- Your Ask AI question and follow-up messages
- The final image prompt sent to the chosen image model
- Model list requests when you browse available models in Settings

BookAI currently has:

- No BookAI account system
- No BookAI-hosted AI proxy between the app and OpenRouter/Gemini

If you use AI, your requests go directly to the selected provider, and that provider's own retention and privacy policies apply.

## Manual GitHub Sync (Optional)

BookAI includes an optional manual sync flow for personal use. It uploads and downloads one JSON snapshot file in your own private GitHub repository.

This is manual only:

- No background sync
- No live merge UI
- No cloud account system

### What Syncs

- Reading progress
- Highlights
- Resume markers
- Reader settings (font, theme)
- AI settings and model selections
- API keys only when **Include API keys in uploads** is enabled in Settings

### What Does Not Sync

- EPUB files
- Books/library entries themselves
- Pasted-text book content
- Generated images
- AI request logs

Important: each device must import the same EPUB files locally. Sync maps state to local books using a stable EPUB fingerprint (`syncKey`). If a matching local book is missing, that remote state is skipped.

### Setup (Private GitHub Repo)

1. Create a private GitHub repository you control (for example `bookai-sync`).
2. Create a personal access token that can read and write contents in that repo.
   - Fine-grained PAT: grant repository access and **Contents: Read and write**.
   - Classic PAT: use `repo` scope for private repositories.
3. In BookAI, open **Settings -> Sync**.
4. Fill:
   - **GitHub Repo**: `owner/repo`
   - **Remote File Path**: e.g. `sync/state.json`
   - **GitHub Token**: your PAT
5. Optional: enable **Include API keys in uploads** only if you trust the private repo and anyone with access to it.

### Manual Upload / Download Flow

- **Upload** exports local syncable state, creates a versioned snapshot JSON, and uploads it to the configured GitHub file path.
- **Download** fetches the snapshot JSON and applies it locally for matching books.
- Download is authoritative for matching books:
  - local progress/resume marker/highlights for matching books are overwritten by remote snapshot state
  - local per-book syncable records absent from the snapshot are removed for those matching books
- Books are never created by download.

### Snapshot Format and Versioning

- Remote file is JSON with top-level `schemaVersion`.
- Current schema version is `1`.
- If `schemaVersion` is unsupported, download/import fails with a validation error instead of partially applying data.

### Reliability Notes

- Use a private repository only.
- Treat GitHub token and optional synced API keys as sensitive secrets.
- Keep one sync file path per personal library profile to avoid accidental cross-library overwrites.

## Supported Platforms

Current app targets:

- Android
- iOS
- macOS
- Windows
- Linux

Not currently supported:

- Web

The repository includes a `web/` directory because this is a Flutter project, but the current app still depends on native local storage/database behavior and `dart:io`, so the web build is not ready yet.

## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) `>=3.4.4`
- Platform toolchain for your target OS
- Your own OpenRouter and/or Gemini key if you want AI features

### Run

```bash
flutter pub get
flutter run
```

### Checks

```bash
flutter analyze
flutter test
```

Use standard Flutter build commands for your target platform, for example:

```bash
flutter build apk --release
```

## Roadmap

Planned directions for the project:

- Richer EPUB rendering with covers, inline images, and better formatting support
- Full-text search inside books
- Better export and sharing for highlights and generated images
- More robust sync and backup across devices
- More language presets and reading-assistance workflows
- Better multi-image generation and image management
- Web support

## Known Limitations

- EPUB chapters are currently rendered as plain text, so rich HTML/CSS formatting and inline media are not preserved in the reader.
- Cover extraction is not implemented yet.
- There is no full-text search.
- Sync is manual-only and GitHub-only; there is no background sync or encrypted backup flow.
- Download applies to matching local books only, so each device still needs manual EPUB import.
- The image workflow currently saves a single returned image into the local library flow.
- The default Define & Translate setup is tuned for English explanation plus Russian translation.
- Web is not supported yet.
