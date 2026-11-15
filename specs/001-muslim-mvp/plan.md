# Implementation Plan: Muslim MVP (Mushaf, Tafsir, Linked Stories)

**Branch**: `001-muslim-mvp` | **Date**: 2026-11-14 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/001-muslim-mvp/spec.md`

## Summary

Build the first version of Muslim: an offline-first Quran reader with a page-exact Mushaf, a
continuous view, one bundled tafsir, per-ayah audio from several reciters, bookmarks, search and
four themes, plus a stories section whose videos are linked to the Quran text in both
directions.

The technical approach: one Flutter app. The Quran text, the 604-page line layout and the
tafsir are imported once from the Quran.com API by a reproducible tool into a read-only SQLite
database that ships inside the app, pinned by checksums that CI re-verifies. Audio is streamed
per ayah. Story videos are described by a JSON catalog that the content owner can update
without an app release, and the app plays only reviewer-approved items.

## Technical Context

**Language/Version**: Dart 3.14 on Flutter 3.50 (stable channel)

**Primary Dependencies**: `material_ui` (Material widgets; since Flutter 3.47 they live in this
package and `package:flutter/material.dart` is deprecated), `flutter_riverpod` 3 (state), `go_router` 18 (navigation), `sqlite3`
3 (databases), `shared_preferences` (settings), `just_audio` + `audio_session` (recitation),
`video_player` and `youtube_player_iframe` (stories), `wakelock_plus`, `share_plus`,
`url_launcher`, `path_provider`, `path`, `crypto`, `http`, `intl` with `flutter_localizations`.
Dev: `flutter_test`, `flutter_lints`, `mocktail`.

**Storage**: bundled read-only SQLite content database (`assets/data/quran.db`), on-device
SQLite user database (`user.db`), `shared_preferences` for settings. See
[data-model.md](data-model.md).

**Testing**: `flutter test` with unit, widget and golden tests; a dataset integrity test;
GitHub Actions on every PR.

**Target Platform**: Android 7.0 (API 24) and later first; iOS 13 and later from the same code.

**Project Type**: mobile app, single project at the repository root, no backend.

**Performance Goals**: 60 fps page turning and scrolling on a mid-range Android phone; page
turn and tafsir sheet under 300 ms; cold start to last ayah under 3 s; search under 1 s.

**Constraints**: reading, tafsir, search, bookmarks and themes fully offline; no accounts, no
analytics; Quran text never typed or altered (constitution, I); only approved story items
playable (II); body text contrast at least 7:1 in every theme; installed size under 40 MB.

**Scale/Scope**: 114 surahs, 6236 ayahs, 604 pages, about 83 thousand word rows, one tafsir,
five reciters, about 12 screens and 3 sheets, 11 user stories.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Gate | Status |
| --- | --- | --- |
| I. Quran Text Integrity | Text comes only from the import tool (research R2); provenance manifest with checksums (data-model 2); integrity test in CI (R12); canonical text displayed unmodified, search uses a separate folded column (R9); no font fallback (R4); layout words tied to the ayah record by an import invariant (data-model 1); tests use keys and checksums, and parser tests use placeholder tokens | PASS |
| II. Religious Content Safeguards | Catalog items need `approved` + no-depiction attestation + media to be playable (R10, catalog schema); bundled catalog has no media and no invented text; tafsir shown unaltered with attribution (R6); no ads anywhere | PASS |
| III. Licensed, Attributed Sources | Sources registry with schema and verification flag (contracts); Sources page (US11); unverified entries tracked as release gates (R13) | PASS |
| IV. Offline-First and Private | Content bundled; user data on device only; no analytics SDK; network limited to audio, video and catalog refresh, each with an offline state | PASS |
| V. Calm, Accessible Reading | RTL and Arabic-first (R11); four app-wide themes with a contrast test; design tokens from `DESIGN.md`; accessibility pass task | PASS |
| VI. Spec-Driven, Tested, Reviewed | Every task maps to a user story; each task group is one reviewed PR; tests are part of every task; CI runs format, analyze, test | PASS |
| VII. Simplicity | No backend; hand-written SQL instead of an ORM and code generation; no background audio service, downloads or accounts in the MVP | PASS |

**Post-design re-check (after Phase 1)**: PASS. The design adds one derived column
(`text_search_folded`), which Principle I permits for search because it is derived from a
source field by a documented, tested rule and is never displayed. No violations to justify.

## Project Structure

### Documentation (this feature)

```text
specs/001-muslim-mvp/
├── plan.md              # This file
├── research.md          # Phase 0: decisions and verified facts
├── data-model.md        # Phase 1: databases, settings, domain types
├── quickstart.md        # Phase 1: how to build, test and validate
├── contracts/
│   ├── catalog.schema.json            # Story content catalog
│   ├── sources.schema.json            # Sources registry
│   ├── dataset-manifest.schema.json   # Quran dataset provenance
│   └── routes.md                      # In-app routes between features
├── checklists/requirements.md
└── tasks.md             # Phase 2: task list
```

### Source Code (repository root)

```text
pubspec.yaml
analysis_options.yaml
l10n.yaml
PRODUCT.md                         # Impeccable product context
DESIGN.md                          # Design system: tokens, type, components
.github/workflows/ci.yml

android/                           # Flutter Android host project
ios/                               # Flutter iOS host project

assets/
├── data/
│   ├── quran.db                   # Built by tool/quran_import, read-only
│   └── manifest.json              # Provenance and checksums
├── content/catalog.json           # Bundled story catalog
├── sources.json                   # Sources registry
└── fonts/                         # KFGQPC Uthmanic Hafs + UI fonts

tool/
└── quran_import/                  # Dart CLI: fetch, validate, build quran.db
    ├── bin/quran_import.dart
    ├── lib/                       # api client, parsers, layout derivation, db writer, hashing
    └── test/

lib/
├── main.dart
├── app.dart                       # MaterialApp.router, theme, locale
├── core/
│   ├── routing/                   # go_router configuration (contracts/routes.md)
│   ├── theme/                     # tokens, four themes, text styles
│   ├── l10n/                      # ARB files: app_ar.arb, app_en.arb
│   ├── settings/                  # SettingsRepository + providers
│   └── widgets/                   # shared widgets (sheets, states, buttons)
├── data/
│   ├── models/                    # Surah, Ayah, Word, PageLine, AyahRef, AyahRange, ...
│   ├── quran_database.dart        # opens the bundled database
│   ├── quran_repository.dart      # surahs, ayahs, pages, juz, search
│   ├── tafsir_repository.dart
│   ├── reciter_repository.dart
│   ├── user_database.dart         # user.db schema and migrations
│   └── bookmark_repository.dart
└── features/
    ├── index/                     # surah and juz index
    ├── mushaf/                    # reader shell, page view, continuous view, go-to, resume
    ├── tafsir/                    # tafsir sheet
    ├── audio/                     # recitation controller, player bar, reciter picker
    ├── ayah_menu/                 # long-press menu and its actions
    ├── bookmarks/                 # list screen, indicators
    ├── search/
    ├── autoscroll/
    ├── stories/                   # catalog, surah stories, prophet stories, player
    └── settings/                  # settings screen, theme picker, sources page, report

test/
├── data/                          # repositories, dataset integrity, settings
├── features/                      # widget tests per feature
├── goldens/                       # golden images
└── helpers/                       # test app wrapper, fakes, font loading
```

**Structure Decision**: a single Flutter project at the repository root, organised
feature-first under `lib/features/`, with shared data access in `lib/data/` and cross-cutting
code in `lib/core/`. The import tool is a separate Dart package under `tool/quran_import/` so
that its HTTP and parsing dependencies never ship in the app. There is no backend.

## Architecture Notes

- **Data flow**: widgets read Riverpod providers; providers call repositories; repositories
  run SQL on the content or user database. Widgets never run SQL and never hold Quran text
  that did not come from a repository.
- **Reader state**: one `ReaderController` owns the current ayah, the reading mode and the
  highlighted ayah. The page view, the continuous view, the audio follower, the tafsir sheet
  and deep links all read and write that one position, which is what keeps them in sync.
- **Ayah interaction**: every rendered word carries its ayah id. Tap opens tafsir; long press
  opens the ayah menu. Both views share the same gesture and highlight code.
- **Audio**: a `RecitationController` wraps the player behind an interface so tests use a fake.
  It exposes a state stream (data-model 6) that the reader follows.
- **Stories**: a `CatalogRepository` loads the bundled catalog, optionally refreshes it, and
  exposes only validated data. `isPlayable` is computed in one place and tested exhaustively.
- **Errors**: network-dependent features (audio, video, catalog refresh) each have an explicit
  offline state with retry. Database or font failures show a blocking error state on the
  Mushaf rather than degraded text.

## Delivery

Tasks are grouped into pull requests in [tasks.md](tasks.md). Each PR is implemented on its own
branch, verified with `dart format`, `flutter analyze` and `flutter test`, reviewed
independently against the spec and the constitution, fixed until the review is clean, and
merged by squash before the next one starts.

## Complexity Tracking

No constitution violations. Nothing to justify.
