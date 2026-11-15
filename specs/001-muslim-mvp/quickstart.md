# Quickstart: Muslim MVP

How to build, test and validate the app. Paths are relative to the repository root.

## Prerequisites

- Flutter on the stable channel (3.50 or later), which includes Dart.
- For a device build: Android Studio with an Android SDK, or Xcode on macOS for iOS.
- No API keys or accounts are needed.

## Everyday commands

```bash
flutter pub get                       # install dependencies
dart format --set-exit-if-changed .   # formatting gate
flutter analyze                       # static analysis gate, must report no issues
flutter test                          # all unit, widget and golden tests
flutter run                           # run on a connected device or emulator
flutter build apk --debug             # debug APK at build/app/outputs/flutter-apk/
```

Golden images are updated on purpose only:

```bash
flutter test --update-goldens test/goldens
```

## Rebuilding the Quran dataset

The dataset is committed, so this is needed only when the import tool or the source changes.
It needs network access to `api.quran.com`, `verses.quran.com` and `everyayah.com`.

```bash
cd tool/quran_import
dart pub get
dart test
dart run bin/quran_import.dart --out ../../assets/data
cd ../..
flutter test test/data/dataset_integrity_test.dart
```

The tool writes `assets/data/quran.db` and `assets/data/manifest.json` and fails if any
structural invariant does not hold. A change to these two files goes in its own pull request
(constitution, Principle I).

## Supplying story videos

Edit `assets/content/catalog.json` (or host the same file and build with
`--dart-define=CATALOG_URL=https://...`). An item becomes playable only when all three hold:

1. `review.status` is `approved`, with `reviewer` and `approved_at` filled in;
2. `no_prophet_depiction` is `true`;
3. `media` is present.

The format is defined in `specs/001-muslim-mvp/contracts/catalog.schema.json`.

## Validation scenarios

Run these on a device after the related user story is merged. Each maps to the spec.

| # | Story | Steps | Expected |
| --- | --- | --- | --- |
| 1 | US1 | Turn on airplane mode, install, launch, open surah 36 from the index | Page view opens on the surah's first page within 10 seconds of launch |
| 2 | US1 | Compare pages 1, 2, 3, 50, 300 and 604 with a printed Madani Mushaf | Same line breaks on every line |
| 3 | US1 | Switch to continuous view, enlarge the font, switch back | Same ayah stays on screen; the size is kept |
| 4 | US1 | Close the app on an ayah, reopen | Opens on that ayah |
| 5 | US2 | Tap an ayah, go to the next ayah in the sheet, dismiss | Tafsir shown with its source; the page did not move |
| 6 | US3 | Online, press play mid-surah and let it cross a page boundary | Highlight follows; the page turns by itself; the screen stays awake |
| 7 | US3 | Airplane mode, press play | Clear message with retry; reading still works |
| 8 | US4 | Long press an ayah, choose Repeat, 3 times | The ayah plays three times and stops |
| 9 | US5 | Bookmark two ayahs, mark one memorised, restart the app | All three are in the list and marked on the page |
| 10 | US6 | Search a common word typed without diacritics, offline | Results within a second; tapping one opens the ayah |
| 11 | US7 | Cycle through the four themes | Every screen changes; white on black is true black |
| 12 | US8 | Continuous view, auto-scroll on, change speed, tap twice | Scrolls, pauses, resumes; speed is remembered |
| 13 | US9 | With a test catalog holding one approved surah video, open surah 112 | "Watch the story" appears and plays; "Read the surah" returns |
| 14 | US9 | Set that item's status to `in_review` | The video can no longer be played anywhere |
| 15 | US10 | With one approved episode with related ayahs, open the episode and tap an ayah range | The Mushaf opens there, and that ayah's menu offers the episode |
| 16 | US11 | Open Settings, Sources | Every source is listed with its terms |

## Release gates

A public store release additionally requires, per the constitution:

- every entry in `assets/sources.json` has `verified: true`;
- every catalog item that ships as playable is approved;
- the project owner's sign-off.
