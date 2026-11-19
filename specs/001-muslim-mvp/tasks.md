---
description: "Task list for the Muslim MVP"
---

# Tasks: Muslim MVP (Mushaf, Tafsir, Linked Stories)

**Input**: Design documents from `/specs/001-muslim-mvp/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Tests**: required. The constitution (Principle VI) makes tests part of every task: unit tests
for data and logic, widget tests for each acceptance scenario, golden tests for reading
surfaces. Each task lists the tests it must add.

**Organization**: tasks are grouped by user story. Each task is sized to be one pull request,
or part of one where the "Pull request groups" table at the end says so.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel with its neighbours (different files, no dependency)
- **[Story]**: the user story the task belongs to (US1 to US11)
- Every description names the files it creates or changes

## Rules for every task

- Follow `.specify/memory/constitution.md`. Never type Quran text or author religious content.
- Done means: acceptance bullets met, tests added and passing, `dart format` clean,
  `flutter analyze` reports no issues, `flutter test` green, task box ticked in this file.
- User-facing strings go in `lib/core/l10n/app_ar.arb` and `app_en.arb`.
- UI tasks use the design tokens from `lib/core/theme/` and follow `DESIGN.md`.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: a buildable, linted, tested, continuously checked Flutter project.

- [x] T001 Create the Flutter project at the repository root: `pubspec.yaml`,
  `analysis_options.yaml`, `l10n.yaml`, `lib/main.dart`, `lib/app.dart`, `android/`, `ios/`,
  `test/widget_test.dart`, and extend `.gitignore`
  - `flutter create --org com.mazen109 --project-name muslim --platforms android,ios .`, then
    keep the existing `README.md`, `docs/`, `specs/`, `.specify/`, `.claude/`, `CLAUDE.md`.
  - App display name `مسلم`; Android `minSdk` 24; application id `com.mazen109.muslim`.
  - Add the dependencies listed in plan.md "Technical Context" at their current stable
    versions. Do not add packages the plan does not list.
  - `analysis_options.yaml`: `flutter_lints` plus `strict-casts`, `strict-inference`,
    `strict-raw-types`, and the lints `prefer_const_constructors`,
    `require_trailing_commas`, `unawaited_futures`, `avoid_print`.
  - `lib/app.dart` shows a minimal placeholder home in Arabic, RTL, from an ARB string.
  - Tests: one widget test that the app builds and is RTL.
- [x] T002 [P] Add continuous integration in `.github/workflows/ci.yml`
  - On pull requests and on pushes to `main`: checkout, install Flutter stable (pinned minor
    version, with caching), `flutter pub get`, `dart format --set-exit-if-changed .`,
    `flutter analyze`, `flutter test`; then the import tool's `dart test` when
    `tool/quran_import/` exists.
  - A second job builds `flutter build apk --debug` and uploads the APK as an artifact.
  - Least privilege: `permissions: contents: read`. Cancel superseded runs.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: the Quran dataset, the data layer, the design system and the app shell. Nothing
in the user stories can start before this phase is complete.

- [x] T003 Build the Quran import tool in `tool/quran_import/` (`pubspec.yaml`,
  `bin/quran_import.dart`, `lib/*.dart`, `test/*.dart`)
  - A Dart CLI: `dart run bin/quran_import.dart --out <dir> [--cache <dir>]`.
  - Fetches exactly the endpoints in research R2, R6 and R7 with retry and backoff, caches raw
    responses on disk (cache directory is git-ignored), and records each request's URL, byte
    count and SHA-256.
  - Builds `quran.db` with exactly the schema in data-model.md section 1, including every
    index and the `meta` rows; `dataset_version` is `1`.
  - Derives `page_lines` by the rules in research R3 and fails on any mismatch.
  - De-duplicates `/juzs` by `juz_number` and requires 30.
  - Reciters: the five in research R7, in that order, with `url_template` resolved as R7
    describes; verifies the file name pattern for every ayah of every reciter and that the
    first and last ayah of the Quran return HTTP 200.
  - `text_search_folded` by the folding rule in research R9, implemented as one pure,
    documented function.
  - Asserts every invariant in data-model.md section 1 and every count in
    `contracts/dataset-manifest.schema.json` before writing; exits non-zero with a precise
    message otherwise.
  - Writes `manifest.json` per the schema, with table hashes computed as the schema defines.
  - Tests (`dart test`): response parsers, layout derivation (surah starting mid-page, banner
    at the bottom of a page with basmala on the next, surahs 1 and 9, pages 1 and 2), juz
    de-duplication, folding, URL template resolution and table hashing. Fixtures are synthetic
    JSON in the API's shape with placeholder tokens such as `w1`; they contain no Quran text.
- [x] T004 Run the import and commit the dataset: `assets/data/quran.db`,
  `assets/data/manifest.json`, `pubspec.yaml` (assets), `test/data/dataset_integrity_test.dart`
  - Run the tool against the live API; commit its two outputs unmodified.
  - The integrity test opens `assets/data/quran.db` with `sqlite3`, recomputes every table
    hash and count and compares with `manifest.json`, and checks the structural invariants:
    114 surahs, 6236 ayahs, 604 pages, 9046 page lines, 30 juz, 60 hizb, 6236 tafsir entries,
    and words joined per ayah in position order, with every `U+0020` and `U+00A0` removed,
    equal `text_qpc_hafs` with every `U+0020` and `U+00A0` removed (data-model.md section 1).
  - The PR description lists row counts, file sizes and the table hashes.
- [x] T005 [P] Add fonts and the sources registry: `assets/fonts/`, `assets/sources.json`,
  `pubspec.yaml` (fonts, assets), `test/data/sources_registry_test.dart`
  - `UthmanicHafs1Ver18.ttf` from `quran/quran.com-frontend-next`
    (`public/fonts/quran/hafs/uthmanic_hafs/`), unmodified, family name `UthmanicHafs`.
  - `assets/sources.json` per `contracts/sources.schema.json` with entries for: the Quran text
    and layout (Quran.com API, King Fahd Complex Hafs text), Al-Tafsir Al-Muyassar, the
    Quran.com recitation files, EveryAyah, the KFGQPC font (with `sha256` and `asset_path`),
    and each UI font added later. All `verified: false` until the owner confirms.
  - Tests: registry validates against the schema's required fields and enums; every entry
    with `asset_path` exists and matches its `sha256`.
- [x] T006 Implement the content data layer: `lib/data/models/*.dart`,
  `lib/data/quran_database.dart`, `lib/data/quran_repository.dart`,
  `lib/data/tafsir_repository.dart`, `lib/data/reciter_repository.dart`, `test/data/*_test.dart`
  - `QuranDatabase`: copies the asset to app storage on first run and when
    `meta.dataset_version` differs from the installed copy, then opens it read-only. Tests
    open the asset file directly.
  - Models and domain types exactly as data-model.md sections 1 and 5 (`AyahRef`,
    `AyahRange`, sealed `PageLine`). Immutable, with value equality.
  - `QuranRepository`: all surahs; all juz; surah by id; ayah by id and by `AyahRef`; ayahs of
    a surah; `MushafPage` for a page number (lines with their words, banner and basmala lines
    with their surah; basmala words read from ayah `1:1` without its end marker); page of an
    ayah; first ayah of a page.
  - `TafsirRepository`: tafsir metadata; text for an ayah.
  - `ReciterRepository`: all reciters in `sort_order`; audio URL for (reciter, `AyahRef`).
  - Riverpod providers for the database and each repository.
  - Tests against the real bundled database: counts, boundary pages (1, 2, 3, 604), a surah
    that starts mid-page, an ayah spanning two pages, `AyahRef` validation and parsing, URL
    formatting; every `reciters.source_id` exists in the sources registry. Assertions use
    ids, keys, counts and hashes, never literal Quran text.
- [x] T007 [P] Implement user data and settings: `lib/data/user_database.dart`,
  `lib/data/bookmark_repository.dart`, `lib/core/settings/settings_repository.dart`,
  `lib/core/settings/settings_providers.dart`, tests under `test/data/` and `test/core/`
  - `user.db` with the schema in data-model.md section 3, versioned by `PRAGMA user_version`
    with a migration runner (version 1 creates both tables).
  - `BookmarkRepository`: add, remove, toggle, list newest first, and a stream of changes, for
    bookmarks and for memorisation marks.
  - `SettingsRepository` over `shared_preferences` with every key, type, range and default in
    data-model.md section 4; out-of-range stored values fall back to the default.
  - Tests with an in-memory database and mock preferences, including the migration from an
    empty database and range clamping.
- [x] T008 Establish the design system: `PRODUCT.md`, `DESIGN.md`, `lib/core/theme/*.dart`,
  `assets/fonts/` (UI fonts), `test/core/theme_test.dart`
  - Use the `impeccable` skill (`init`, then new-work for a native app) to write `PRODUCT.md`
    and `DESIGN.md` for an Arabic-first, calm, reading-centred Quran app. The Mushaf page is
    the hero surface; chrome is quiet. Avoid generic Islamic-app clichés and template looks.
  - Tokens in code: colour roles, type scale, spacing, radii, elevation, motion durations.
    Four `ThemeData`: `light`, `night`, `black_on_white`, `white_on_black`. The two black and
    white themes use only black, white and greys; `white_on_black` uses `#000000` as its
    background.
  - A Quran text style that uses only the `UthmanicHafs` family with an empty fallback list.
  - UI font(s) bundled under an open licence and added to `assets/sources.json`.
  - Tests: every theme's body text, secondary text and Quran text meet a contrast ratio of at
    least 7:1 against their backgrounds (computed in the test); the black and white themes
    contain no chromatic colour in any role.
- [x] T009 Build the app shell: `lib/core/routing/app_router.dart`, `lib/app.dart`,
  `lib/core/widgets/app_scaffold.dart`, `lib/core/widgets/state_views.dart`,
  `lib/core/l10n/app_ar.arb`, `lib/core/l10n/app_en.arb`, `test/core/app_shell_test.dart`,
  `test/helpers/*.dart`
  - `go_router` with every route in `contracts/routes.md`; unbuilt screens are plain
    placeholders that later tasks replace.
  - Bottom navigation with four destinations: Mushaf, Stories, Bookmarks, Settings.
  - Theme and locale come from settings providers and apply app-wide; default locale `ar`.
  - Shared empty, loading, error and offline state widgets with a retry action.
  - Test helpers: a `pumpApp` wrapper with provider overrides, real font loading for goldens,
    and a helper that opens the bundled database.
  - Tests: navigation between the four destinations, the launch redirect rule, invalid
    `/mushaf` parameters redirecting to `/index`, RTL, and one golden of the shell per theme.

**Checkpoint**: foundation ready. User stories can start.

---

## Phase 3: User Story 1 - Read the Mushaf (Priority: P1) 🎯 MVP

**Goal**: browse the index, read in page view and continuous view, resume, and jump.

**Independent Test**: offline, open any surah from the index, read in both views, close and
reopen the app, and land on the same ayah (quickstart scenarios 1 to 4).

- [x] T010 [US1] Build the surah and juz index in `lib/features/index/` with
  `test/features/index/index_screen_test.dart`
  - Two tabs. Surahs: number, Arabic name, ayah count, Makki or Madani, start page. Juz:
    number, the surah and ayah where it starts, start page.
  - Tapping a row navigates to `/mushaf` at that surah's or juz's first ayah.
  - Tests: 114 and 30 rows from the real database; row content for the first and last surah
    by id; navigation target; a golden.
- [x] T011 [US1] Build the Mushaf page view in `lib/features/mushaf/` (`reader_screen.dart`,
  `reader_controller.dart`, `page_view/mushaf_page_view.dart`,
  `page_view/mushaf_page_widget.dart`, `page_view/page_line_widgets.dart`) with tests under
  `test/features/mushaf/` and goldens under `test/goldens/mushaf/`
  - `ReaderController` (Riverpod) owns the current ayah, reading mode and highlighted ayah,
    as described in plan.md "Architecture Notes".
  - A right-to-left `PageView` over 604 pages, building only nearby pages.
  - `MushafPageWidget` renders the page as research R5 describes: 15 or 8 line slots, ayah
    lines justified with centred short lines, surah name banners, basmala lines, one font
    size per page computed to fit; the page scales as a unit on any screen size.
  - A quiet header or footer with surah name, juz and page number.
  - Each word is hit-testable and reports its ayah id on tap and on long press (callbacks
    only; the sheets arrive in later tasks). The highlighted ayah is drawn with a background.
  - Font check at startup: if the Quran font asset is missing or its checksum differs, the
    reader shows the blocking error state.
  - Tests: line count and line types for pages 1, 2, 3, 604 and one mid-surah-start page;
    swiping changes the page in RTL order; tap reports the correct ayah id for a word on a
    line shared by two ayahs; the font-missing state; goldens for pages 1, 2, 3 and 604 in
    the light theme at phone size.
- [x] T012 [US1] Build the continuous view and the mode switch in
  `lib/features/mushaf/continuous/` and `lib/features/mushaf/reader_screen.dart` with
  `test/features/mushaf/continuous_view_test.dart`
  - A surah as flowing, justified ayah text with end markers, a surah header and basmala
    (from the repository), lazily built, with the same tap, long press and highlight
    behaviour as the page view.
  - Font size from `font_scale` with a control in the reader; the setting persists.
  - A mode toggle in the reader. Switching keeps the current ayah on screen in both
    directions. The mode persists.
  - Scrolling updates the controller's current ayah.
  - Tests: mode switch keeps the ayah (both directions); font scale changes the text size and
    persists; current ayah updates on scroll; a golden.
- [x] T013 [US1] Add resume and go-to in `lib/features/mushaf/resume.dart`,
  `lib/features/mushaf/go_to_sheet.dart`, `lib/core/routing/app_router.dart` with
  `test/features/mushaf/resume_go_to_test.dart`
  - Save `last_ayah_id` as the reader's current ayah changes (debounced) and when the app is
    paused. Launch opens `/mushaf` at that ayah in the saved mode; first launch opens the
    index.
  - Go-to sheet: by page (1 to 604) or by surah and ayah, with validation messages for
    out-of-range input.
  - The reader app bar gives one-tap access to the index and to search.
  - Tests: position saved and restored across a simulated restart; first-launch redirect;
    go-to validation and navigation.

**Checkpoint**: the Mushaf is readable end to end, offline.

---

## Phase 4: User Story 2 - Understand an ayah with tafsir (Priority: P1)

**Goal**: tap an ayah and read its tafsir without leaving the page.

**Independent Test**: offline, tap any ayah in either view, read its tafsir and see its source
(quickstart scenario 5).

- [x] T014 [US2] Build the tafsir sheet in `lib/features/tafsir/tafsir_sheet.dart` and wire it
  to ayah taps in `lib/features/mushaf/` with `test/features/tafsir/tafsir_sheet_test.dart`
  - A draggable bottom sheet showing the ayah (canonical text, Quran font), the tafsir text
    unaltered, and the tafsir's name and author.
  - Previous and next ayah controls, crossing surah boundaries, disabled at the first and
    last ayah of the Quran. The sheet's ayah is highlighted in the reader behind it.
  - The reader's scroll position or page does not change when the sheet opens or closes.
  - Tafsir text respects the font size setting and is selectable.
  - Tests: opening from a tap shows the right ayah id and the tafsir name; next and previous
    move by one ayah and update the highlight; boundaries are disabled; the reader position
    is unchanged after dismissal; works with the network unavailable (no network calls made).

**Checkpoint**: stories 1 and 2 together are the offline core of the MVP.

---

## Phase 5: User Story 3 - Listen to a recitation (Priority: P2)

**Goal**: play a recitation from any ayah with a chosen reciter and follow it on the page.

**Independent Test**: online, start playback mid-surah, watch the highlight cross a page
boundary, change reciter, pause and resume (quickstart scenarios 6 and 7).

- [x] T015 [US3] Implement the recitation engine in `lib/features/audio/` (`audio_player_port.dart`,
  `just_audio_player.dart`, `recitation_controller.dart`, `playback_state.dart`) with
  `test/features/audio/recitation_controller_test.dart`
  - `AudioPlayerPort`: a small interface over the player (set playlist, play, pause, seek to
    index, stop, streams for index, state and errors) with a `just_audio` implementation and
    an `audio_session` configured for speech.
  - `RecitationController`: play from an ayah to the end of its surah with the selected
    reciter; pause, resume, stop, next and previous ayah; single-ayah mode and repeat mode
    (count 2 to 20) for US4; changing reciter mid-playback continues from the current ayah.
  - State follows data-model.md sections 5 and 6 exactly, including `error` with retry.
  - The wake lock is held while state is `playing` and released otherwise.
  - Tests with a fake `AudioPlayerPort`: every state transition, end of surah, reciter
    change, repeat counting, error then retry, wake lock acquire and release.
- [x] T016 [US3] Build the player UI in `lib/features/audio/player_bar.dart`,
  `lib/features/audio/reciter_picker.dart` and the reader with
  `test/features/audio/player_ui_test.dart`
  - A play control in the reader that starts from the current ayah, and a compact player bar
    while a recitation is active: play or pause, previous, next, stop, reciter name, and the
    current surah and ayah number.
  - Reciter picker sheet listing reciters with name and style; the choice persists.
  - The reader follows playback: the playing ayah is highlighted, and the page view turns or
    the continuous view scrolls to keep it visible.
  - Offline or load failure shows the offline state in the bar with retry; reading continues.
  - Tests: play starts from the current ayah; highlight and page follow a simulated ayah
    change across a page boundary; picker persists the choice; the error state and retry.

---

## Phase 6: User Story 4 - Act on an ayah from one menu (Priority: P2)

**Goal**: one long-press menu with Listen, Repeat, Tafsir, Surah story, Bookmark and Share.

**Independent Test**: long press an ayah and complete each action (quickstart scenario 8).

- [ ] T017 [US4] Build the ayah menu in `lib/features/ayah_menu/` (`ayah_menu_sheet.dart`,
  `ayah_actions.dart`, `repeat_picker.dart`) and wire it to long press in
  `lib/features/mushaf/` with `test/features/ayah_menu/ayah_menu_test.dart`
  - The sheet shows the ayah reference and the actions in the order of FR-017, including
    Report an error (which calls a hook that T025 implements; until then it is hidden).
  - Listen plays only that ayah, with a reciter shortcut in the same sheet.
  - Repeat asks for a count (2 to 20, default from `repeat_count`), then repeats and shows the
    remaining count in the player bar.
  - Tafsir opens the tafsir sheet for that ayah.
  - Surah story is enabled only when a playable story exists for the surah (through a provider
    that returns "none" until T022 supplies the catalog).
  - Bookmark toggles through `BookmarkRepository` (the list screen arrives in T018).
  - Share opens the system share sheet with `text_uthmani`, the surah name and the ayah number,
    formatted by one tested function.
  - Long press during auto-scroll pauses it (hook used by T021).
  - Tests: every action dispatches correctly; repeat count bounds; share text formatting by
    structure (reference line and non-empty text from the repository, not literal text);
    disabled state of Surah story.

---

## Phase 7: User Story 5 - Keep bookmarks and memorisation marks (Priority: P2)

**Goal**: save ayahs and memorised marks, list them, see them on the page.

**Independent Test**: bookmark two ayahs and mark one memorised, restart, find and open all
three (quickstart scenario 9).

- [ ] T018 [US5] Build bookmarks and memorisation marks in `lib/features/bookmarks/`
  (`bookmarks_screen.dart`, `ayah_indicators.dart`), the ayah menu and both reader views with
  `test/features/bookmarks/bookmarks_test.dart`
  - Add "Mark as memorised" to the ayah menu next to Bookmark; both are toggles that show
    their current state.
  - Bookmarks screen with two sections, Bookmarks and Memorised, each newest first, showing
    surah name, ayah number and page; tap opens the reader there; swipe or a button removes
    with an undo.
  - A bookmark indicator and a memorised indicator on the ayah's end marker area in both
    views, driven by the repository stream.
  - Empty states for both sections.
  - Tests: toggling from the menu updates the list and the indicators; removal and undo;
    persistence across a re-opened database; navigation target.

---

## Phase 8: User Story 6 - Search the Quran (Priority: P2)

**Goal**: find ayahs by Arabic words, with or without diacritics, offline.

**Independent Test**: offline, search a common word without diacritics and open a result
(quickstart scenario 10).

- [x] T019 [US6] Build search in `lib/features/search/` (`search_screen.dart`,
  `search_controller.dart`, `query_folding.dart`) and `lib/data/quran_repository.dart` with
  `test/features/search/search_test.dart`
  - `foldQuery` applies the same folding rule as the import tool (research R9); the rule
    lives in one shared, documented function with identical test vectors on both sides.
    Test vectors are ordinary Arabic words chosen for their letters, not ayah text.
  - Repository search: `LIKE` on `text_search_folded`, results in Mushaf order, with a total
    count; queries shorter than two letters return nothing; `%` and `_` are escaped.
  - Screen: a search field (debounced), result count, a lazily built list with canonical
    ayah text, surah name and ayah number; an empty state and a no-results state.
  - Tapping a result opens `/mushaf?ayah=S:A&highlight=1`.
  - Tests: folding vectors; diacritics and letter variants give the same result ids as the
    plain form; escaping; ordering; navigation; result count shown.

---

## Phase 9: User Story 7 - Choose a theme, including black and white (Priority: P2)

**Goal**: pick one of four app-wide themes and keep it.

**Independent Test**: switch through all four themes and check each main screen (quickstart
scenario 11).

- [x] T020 [US7] Build the settings screen and theme picker in `lib/features/settings/`
  (`settings_screen.dart`, `theme_picker.dart`) with `test/features/settings/settings_test.dart`
  and goldens under `test/goldens/themes/`
  - Settings: theme (four options with a live preview swatch), interface language (Arabic or
    English), continuous-view font size, default reciter, and "Black and white videos"
    (stored as `video_grayscale`; used by T023).
  - A theme change applies immediately to every screen and persists.
  - Tests: selection persists and rebuilds the app theme; goldens of the Mushaf page, the
    index and the settings screen in all four themes.

---

## Phase 10: User Story 8 - Read hands-free with auto-scroll (Priority: P3)

**Goal**: optional auto-scroll in continuous view with a remembered speed.

**Independent Test**: turn it on, change the speed, tap to pause and resume, confirm the screen
stays awake (quickstart scenario 12).

- [ ] T021 [US8] Build auto-scroll in `lib/features/autoscroll/` (`autoscroll_controller.dart`,
  `autoscroll_controls.dart`) and the continuous view with
  `test/features/autoscroll/autoscroll_test.dart`
  - A toggle in the reader; in page view it offers to switch to continuous view.
  - Frame-driven scrolling at `autoscroll_speed` logical pixels per second; a speed slider
    (10 to 120) that applies at once and persists.
  - Tap on the text pauses and resumes; opening any sheet or the ayah menu pauses.
  - State machine exactly as data-model.md section 6, including `following_audio` while a
    recitation is playing and stopping at the end of the surah.
  - Holds the wake lock while running or following audio, sharing one reference-counted
    wake lock service with the audio feature.
  - Tests with a controllable ticker: distance scrolled matches speed and time; pause and
    resume; speed change; hand-over to and from audio; stop at the end; wake lock counts.

---

## Phase 11: User Story 9 - Watch the story of a surah (Priority: P3)

**Goal**: a stories section driven by an updatable catalog, with links to and from the Mushaf.

**Independent Test**: with a test catalog holding one approved video, open it from the stories
section and from the Mushaf, play it, and return to the surah (quickstart scenarios 13, 14).

- [x] T022 [US9] Implement the content catalog in `lib/features/stories/catalog/`
  (`catalog_models.dart`, `catalog_parser.dart`, `catalog_repository.dart`),
  `assets/content/catalog.json`, with `test/features/stories/catalog_test.dart`
  - Models and a strict parser for `contracts/catalog.schema.json`: unknown
    `schema_version`, a missing required field, a bad ayah key, a range whose `from` is after
    its `to`, or a non-HTTPS URL each reject the whole catalog with a typed error.
  - `StoryItem.isPlayable` exactly as data-model.md section 5, in one place.
  - Repository: load the bundled catalog; when `CATALOG_URL` is defined, fetch it at launch
    with a timeout, validate it, cache it on disk and prefer the newest valid catalog by
    `updated_at`; any failure keeps the previous valid catalog silently.
  - Queries: surah stories for Juz Amma in surah order; the playable story for a surah; the
    prophet series in `order`; playable episodes whose related ayahs contain a given ayah.
  - Bundled `catalog.json`: one `planned` entry per surah 78 to 114 with
    `no_prophet_depiction: false` and no media; five prophet stories (ids and names per the
    spec's assumptions) each with an empty `episodes` list. No media, no story text.
  - Tests: the bundled catalog parses; a truth table over `isPlayable` for every combination
    of status, attestation and media presence; every rejection case; refresh success,
    failure and stale-cache behaviour with a fake HTTP client; related-ayah lookup.
- [ ] T023 [US9] Build surah stories and the video player in `lib/features/stories/`
  (`stories_screen.dart`, `surah_stories_tab.dart`, `story_player_screen.dart`,
  `video/stream_video_view.dart`, `video/youtube_video_view.dart`) and the reader with
  `test/features/stories/surah_stories_test.dart`
  - Stories screen with two tabs; the Surah stories tab lists surahs 78 to 114 with name and
    Makki or Madani label, each marked playable or coming soon.
  - Player screen: `stream` media with `video_player` and standard controls (play, pause,
    seek, fullscreen); `youtube` media with `youtube_player_iframe` and channel attribution;
    a "Read the surah" action to `/mushaf` at the surah's first ayah; an offline state with
    retry. When `video_grayscale` is on, the video is rendered in greyscale.
  - The reader shows a "Watch the story" button for a surah with a playable story, placed so
    it never covers the text, and the ayah menu's Surah story action becomes live.
  - A non-playable item never reaches a video view: enforced in the route and the screen.
  - Runtime hosts (constitution, Technology and Platform Constraints): a media URL whose host
    is not in a sources-registry entry's `runtime_hosts` is treated as not playable, and the
    catalog refresh from T022 is skipped when the `CATALOG_URL` host is not listed. Whoever
    supplies approved media or a catalog URL adds its host to `assets/sources.json`.
  - Tests with a fake catalog and a fake video view: list states; route guard for
    non-playable items; unlisted media and catalog hosts; reader button visibility;
    back-link navigation; offline state.

---

## Phase 12: User Story 10 - Follow the stories of the prophets (Priority: P3)

**Goal**: a chronological prophet series with episodes linked to ayahs in both directions.

**Independent Test**: with one approved episode with related ayahs, open it, jump to one of its
ayahs, and return from that ayah's menu (quickstart scenario 15).

- [ ] T024 [US10] Build prophet stories in `lib/features/stories/` (`prophets_tab.dart`,
  `prophet_story_screen.dart`, `episode_player_screen.dart`, `related_ayahs_list.dart`) and
  the ayah menu with `test/features/stories/prophet_stories_test.dart`
  - The prophets tab lists the series in chronological order with each prophet's name
    followed by the honorific from an ARB string; a story with no playable episode shows
    coming soon.
  - Story screen: episodes in order, each playable or coming soon.
  - Episode player: the same video views as T023, plus the related ayahs as a list of ranges
    (surah name and ayah numbers); tapping one opens the reader at the first ayah of the
    range with a highlight.
  - The ayah menu offers "Related story" when the ayah is inside the related ayahs of a
    playable episode.
  - Artwork and thumbnails come only from catalog media; the app adds none of its own.
  - Tests with a fake catalog whose ids and ranges are synthetic: ordering; states; range
    navigation; the ayah menu entry appearing only for ayahs inside a playable episode's
    ranges.

---

## Phase 13: User Story 11 - See the sources and report an error (Priority: P3)

**Goal**: a Sources page and a pre-filled error report from any ayah, tafsir or video.

**Independent Test**: read every source entry; start a report from an ayah and see its
reference pre-filled (quickstart scenario 16).

- [ ] T025 [US11] Build the Sources page and error reporting in `lib/features/settings/`
  (`sources_screen.dart`, `sources_repository.dart`, `report_error.dart`), the ayah menu, the
  tafsir sheet and the player screens with `test/features/settings/sources_report_test.dart`
  - Sources page from `assets/sources.json`, grouped by kind, showing name, provider, licence,
    attribution and a link; entries not yet verified are labelled as such in debug builds
    only.
  - `buildErrorReport` creates the report text: what is being reported (ayah key, tafsir id
    and ayah key, or video id), app version, dataset version, locale. No Quran text is
    included, only references.
  - Report an error opens the mail app to `REPORT_EMAIL` when that build-time define is set,
    otherwise the system share sheet.
  - Entry points: the ayah menu, the tafsir sheet and both player screens.
  - Tests: every source in the registry renders; report content for each of the three
    kinds; the mail and share branches.

---

## Phase 14: Polish & Cross-Cutting Concerns

- [ ] T026 Accessibility and RTL pass across `lib/features/**` with
  `test/a11y/accessibility_test.dart`
  - Semantics labels for every control; ayahs announce surah name and ayah number; the page
    view is navigable ayah by ayah with a screen reader.
  - Touch targets at least 48 by 48 dp; no overflow at 200% system text scale outside the
    fixed page layout; correct mirroring in RTL and in the English locale.
  - Run the `impeccable` audit for the native app and fix its blocking findings.
  - Tests: Flutter's accessibility guideline matchers (tap target size, labelled tap targets,
    text contrast) on every main screen.
- [ ] T027 Performance pass on `lib/features/mushaf/**` and `lib/data/**` with
  `test/perf/reader_perf_test.dart`
  - Measure page build time and database query time for a page; cache built pages near the
    current one; make sure no synchronous database work runs during a page-turn frame.
  - Record startup-to-reader timing and installed size in the PR description.
  - Tests: page model load for any page under a fixed budget on the test host; the page
    cache bounds its size.
- [ ] T028 [P] Release readiness: `android/app/build.gradle*`, app icons under `android/` and
  `ios/`, `README.md`, `docs/release-checklist.md`
  - App icon and name; release build configuration without committing any signing material.
  - `README.md`: what the app is, how to build and test, how to rebuild the dataset, how to
    supply videos.
  - `docs/release-checklist.md`: the release gates from the constitution and research R13 as
    a checklist for the project owner.
  - Walk through every quickstart validation scenario that can run without a device and
    record the result in the PR.
- [ ] T029 [P] Cross-verify the Quran text against the King Fahd Complex dataset in
  `tool/quran_import/lib/cross_verify.dart` with `tool/quran_import/test/cross_verify_test.dart`
  - Download the Complex's published Hafs dataset, compare it ayah by ayah with the imported
    `text_qpc_hafs`, and record the result in `manifest.json`. Any difference fails the tool.
  - Needs network access to `qurancomplex.gov.sa`; if it cannot be reached, report that and
    leave this task open rather than skipping the comparison.

---

## Dependencies & Execution Order

### Phase dependencies

- **Setup (Phase 1)**: no dependencies.
- **Foundational (Phase 2)**: needs Setup. Order inside: T003 → T004 → T006; T005 and T007 can
  run beside them; T008 → T009 (T009 also needs T006 and T007).
- **User stories (Phases 3 to 13)**: all need Phase 2.
- **Polish (Phase 14)**: needs the stories it touches.

### User story dependencies

- **US1** (T010 to T013): only the foundation. T011 before T012 and T013.
- **US2** (T014): needs T011 and T012 (ayah taps in both views).
- **US3** (T015, T016): T015 needs only the foundation; T016 needs T011 and T012.
- **US4** (T017): needs T014 and T016.
- **US5** (T018): needs T017.
- **US6** (T019): needs T013 for the reader's search entry point and highlight parameter.
- **US7** (T020): needs T009; its goldens need T010 and T011.
- **US8** (T021): needs T012, T015 and T017.
- **US9** (T022, T023): T022 needs only the foundation; T023 needs T022, T017 and T020.
- **US10** (T024): needs T023.
- **US11** (T025): needs T014, T017 and T023.

### Parallel opportunities

T002 beside T001's review; T005 and T007 beside T003 and T004; T015 and T022 beside the US1
tasks; T028 and T029 beside any polish task. Tasks that touch `lib/features/mushaf/` run one
at a time.

## Pull request groups

One pull request per row, in this order. Each is reviewed and merged before the next starts.

| PR | Tasks | Title |
| --- | --- | --- |
| A | T001, T002 | Create the Flutter project and CI |
| B | T003 | Quran import tool |
| C | T004 | Import and pin the Quran dataset |
| D | T005 | Fonts and sources registry |
| E | T006 | Content data layer |
| F | T007 | User data and settings |
| G | T008 | Design system and themes |
| H | T009 | App shell and navigation |
| I | T010 | Surah and juz index |
| J | T011 | Mushaf page view |
| K | T012 | Continuous view |
| L | T013 | Resume and go-to |
| M | T014 | Tafsir sheet |
| N | T015 | Recitation engine |
| O | T016 | Player bar and reciter picker |
| P | T017 | Ayah menu |
| Q | T018 | Bookmarks and memorisation marks |
| R | T019 | Search |
| S | T020 | Settings and themes |
| T | T021 | Auto-scroll |
| U | T022 | Story catalog |
| V | T023 | Surah stories and video player |
| W | T024 | Prophet stories |
| X | T025 | Sources page and error reports |
| Y | T026 | Accessibility pass |
| Z | T027 | Performance pass |
| AA | T028 | Release readiness |
| AB | T029 | Cross-verification against the King Fahd Complex data |

## Implementation Strategy

1. **Foundation first** (PRs A to H): nothing visible yet except the shell, but the dataset is
   pinned and verified, which is the riskiest part of the product.
2. **Offline core** (PRs I to M): US1 and US2. At this point the app is a usable Mushaf with
   tafsir; stop and validate quickstart scenarios 1 to 5 on a device.
3. **Listening and daily use** (PRs N to S): US3 to US7.
4. **Hands-free and stories** (PRs T to X): US8 to US11. Stories become playable when the
   project owner supplies approved videos.
5. **Polish** (PRs Y to AB), then the release gates in `docs/release-checklist.md`.

## Notes

- A task that discovers a gap in the spec or plan updates those documents in the same PR.
- Golden images are regenerated only when a visual change is intended, and the PR says so.
- Never mark a task done with a failing or skipped test.
