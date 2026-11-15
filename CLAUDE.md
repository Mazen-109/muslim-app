# Muslim (مسلم)

A Flutter app: Mushaf with audio, tafsir, and story videos linked to the Quran text.

## Read first

- `.specify/memory/constitution.md` is binding. Principles I and II are non-negotiable.
- The active feature is `specs/001-muslim-mvp/`: `spec.md`, `plan.md`, `research.md`,
  `data-model.md`, `contracts/`, `quickstart.md`, `tasks.md`.
- Design follows `DESIGN.md` and `PRODUCT.md` once they exist; use the `impeccable` skill for
  UI work.

## Rules that are easy to break

- Never type, paste, edit or generate Quran text anywhere: code, tests, fixtures, docs, commit
  messages. Refer to ayahs by key (`2:255`). Text reaches the app only through
  `tool/quran_import` and `assets/data/quran.db`.
- Never write tafsir, hadith, story or other religious content. Never add placeholder
  religious content for a demo or a test.
- Never depict a prophet in any asset.
- Quran text is rendered only with the KFGQPC Uthmanic Hafs font, with no fallback.
- User-facing strings go in `lib/core/l10n/*.arb`, Arabic first.
- Colours, type and spacing come from the theme tokens, not literals in widgets.

## Workflow

- One task group from `tasks.md` per branch and pull request. Tick the task boxes in the same
  PR.
- Before pushing: `dart format --set-exit-if-changed .`, `flutter analyze` (no issues),
  `flutter test` (all green).
- Do not skip or weaken tests to get a green build.

## Commands

See `specs/001-muslim-mvp/quickstart.md`.
