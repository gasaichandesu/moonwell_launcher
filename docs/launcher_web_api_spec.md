# Moonwell Launcher Web API Spec

## Scope

This document specifies the current launcher behavior for:

- authentication against the Moonwell Web API
- installation directory selection
- local file scan and hash calculation
- manifest-based synchronization
- client launch from `Wow.exe`

The launcher no longer uses S3/MinIO directly. All server interaction goes
through the Web API.

## Configuration

The launcher API base URL is provided via:

- `MOONWELL_API_BASE_URL`

Current integration mode is compile-time:

- `flutter run -d windows --dart-define=MOONWELL_API_BASE_URL=https://host`
- `flutter build windows --dart-define=MOONWELL_API_BASE_URL=https://host`

## API Flow

The launcher uses these endpoints from `openapi.json`:

1. `POST /api/launcher/login`
2. `GET /api/launcher/manifest`
3. `GET /api/launcher/download/{path}`
4. `GET /api/launcher/news`

Authentication sequence:

1. User enters launcher credentials.
2. Launcher requests a bearer token from `POST /api/launcher/login`.
3. Launcher requests the manifest from `GET /api/launcher/manifest`.
4. Successful login persists `LauncherSession` locally.
5. On next launcher start, saved session is reused to fetch manifest again.
6. `LauncherSession` and `ClientManifest` are passed into the home screen.

Logout sequence:

1. User presses `Logout`.
2. Launcher cancels any active sync.
3. Launcher clears the locally persisted `LauncherSession`.
4. Launcher returns to the login screen.

File download sequence:

1. Launcher resolves files that are missing, stale, or changed.
2. For each required file, launcher calls `GET /api/launcher/download/{path}` with bearer auth.
3. API returns JSON with a temporary presigned `url` and `expires_in`.
4. Launcher downloads the file directly from storage using the presigned URL.
5. Download is written into `*.moonwell.part`.
6. Downloaded file is verified against manifest `sha256`.
7. Temporary file replaces the destination file only after successful verify.

News sequence:

1. After the launcher reaches the authenticated home screen, it requests `GET /api/launcher/news`.
2. The response payload is read from the top-level `data` array.
3. Each news item provides `id`, `title`, `body`, optional `image_url`, and `created_at`.
4. News failures do not block patching or play flow; the launcher shows a local error state only inside the news panel.

## Installation Directory Rules

The user selects a single installation root directory.

All paths in the manifest are treated as relative to that root.

Path safety rules:

- backslashes are normalized to `/`
- leading `./` is removed
- absolute paths are rejected
- path traversal via `..` is rejected

## Ignored Directories

The launcher excludes these top-level directories from verification:

- `Cache`
- `Errors`
- `Logs`
- `Screenshots`
- `WTF`

Files under these directories:

- are not included in local scan
- do not participate in local `buildHash`
- are not compared against server manifest

## Local Scan

For every non-ignored file in the installation directory, the launcher computes:

- normalized relative path
- file size in bytes
- file `sha256`

The result is stored as a `ClientInstallationSnapshot`.

## Hash Cache

To accelerate repeated scans, the launcher stores a local hash cache in:

- `<install-root>/.moonwell_launcher/hash_cache.json`

This metadata directory is excluded from verification.

Each cache entry is keyed by normalized relative path and stores:

- `size`
- `modifiedMs`
- `sha256`

Cache reuse rule:

- if `path`, `size`, and `modifiedMs` still match, the cached `sha256` is reused
- otherwise `sha256` is recomputed and the cache entry is replaced

The cache is an optimization only. The server remains the source of truth via
the manifest comparison.

## Diagnostics

During sync, the launcher writes a log file to:

- `<install-root>/.moonwell_launcher/launcher.log`

If an installation directory is not available yet, the launcher falls back to a
temporary system log directory.

For failed downloads:

- HTTP and storage download failures are logged with file path and status code
- checksum mismatches log expected and actual `size` and `sha256`
- invalid payloads are preserved as `*.moonwell.part.failed` for inspection

## buildHash Algorithm

`buildHash` is deterministic and calculated identically for local snapshot and
remote manifest.

For each file entry, the launcher builds a canonical string:

`<normalized-path>:<size>:<sha256-lowercase>`

Then:

1. sort all canonical strings lexicographically
2. join them with `\n`
3. compute `sha256` of the resulting UTF-8 payload

This means file ordering in the manifest does not affect `buildHash`.

## Sync Algorithm

The current sync flow is:

1. Load manifest.
2. Scan local installation.
3. Compute local `buildHash`.
4. Compare local files to manifest files by `path`, `size`, and `sha256`.
5. Identify stale local files that are not present in the manifest.
6. If local `buildHash` matches server `buildHash` and there are no stale files
   and no mismatches, finish successfully.
7. Delete stale local files outside ignored directories.
8. Download changed and missing files.
9. Verify every downloaded file by `sha256`.
10. Re-scan the installation.
11. Recompute local `buildHash`.
12. Fail if final snapshot still differs from manifest.

## Pause and Resume Semantics

Pause is implemented as cooperative cancellation:

- the current sync stream is cancelled
- the next sync starts a fresh comparison from current disk state
- already replaced files remain valid
- partial `*.moonwell.part` files are removed before the next download attempt

## Launch Behavior

When the user presses `Play`:

1. launcher resolves `<install-root>/Wow.exe`
2. launcher clears `<install-root>/Cache`
3. launcher starts `Wow.exe` with working directory set to installation root

If `Wow.exe` is missing, launch fails with an error.

## Error Behavior

The launcher surfaces errors for:

- invalid API configuration
- authentication failure
- manifest load failure
- path traversal attempts
- checksum mismatch after download
- missing downloaded temp files before verification
- final verification mismatch after update
- missing `Wow.exe`

## Tested Invariants

The automated tests cover:

- deterministic `buildHash`
- path normalization used by `buildHash`
- exclusion of ignored directories during local scan
- cache cleanup behavior
- safe path resolution
- sync flow with fully up-to-date client
- sync flow with stale files and changed files
