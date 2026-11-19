# Research: Muslim MVP

**Date**: 2026-11-14 | **Spec**: [spec.md](spec.md) | **Plan**: [plan.md](plan.md)

Each entry records a decision, why it was made, and what was rejected. Facts marked
"verified" were checked against the live service on 2026-11-14.

## R1. App framework

**Decision**: Flutter (stable channel, 3.50 at the time of writing; Dart 3.14), one codebase for
Android and iOS. Android is the first release target.

**Rationale**: one codebase for both stores; its own text engine gives identical Arabic shaping
and line layout on every device, which matters for a page-exact Mushaf; mature audio and video
plugins; widget and golden tests run headless in CI.

**Rejected**: React Native / Expo (Arabic shaping and justification depend on each platform's
text stack, and page-exact layout is harder to guarantee); native Kotlin + Swift (two codebases
for a one-person project); a web app or PWA (weak offline storage guarantees, no reliable
background audio later).

## R2. Quran text, layout and metadata source

**Decision**: import once from the Quran.com API v4 (`https://api.quran.com/api/v4`) into a
bundled database. No API calls for text at runtime.

Verified endpoints:

| Need | Endpoint | Notes |
| --- | --- | --- |
| Surah metadata | `GET /chapters?language=ar` | 114 items: `name_arabic`, `name_simple`, `revelation_place`, `revelation_order`, `verses_count`, `bismillah_pre`, `pages` |
| Text and page layout | `GET /verses/by_page/{1..604}?words=true&per_page=300&word_fields=text_qpc_hafs,line_number,page_number,v1_page,line_v1&fields=text_qpc_hafs,text_uthmani,text_imlaei_simple` | Per verse: ids, `verse_key`, `juz_number`, `hizb_number`, `rub_el_hizb_number`, `sajdah_number`. Per word: `position`, `char_type_name` (`word` or `end`), `text_qpc_hafs`, `v1_page`, `line_v1` (see the note below) |
| Juz boundaries | `GET /juzs` | Returns each juz twice (60 rows); the import de-duplicates by `juz_number` and requires exactly 30 |

**Page number quirk** (verified 2026-11-15): when `word_fields` contains `text_qpc_hafs`,
`page_number` on a verse and on its words switches to the 1421H Madani layout for some ayahs
(56 verses, 361 words), while the `by_page` selection and `line_number` stay on the 1405H
layout; for example `by_page/121` returns `5:77` with `page_number` 120. The 1405H fields
`v1_page` and `line_v1` are consistent with the selection, so the import stores `v1_page` as the
word's page and `line_v1` as its line, fails if `line_number` differs from `line_v1`, fails
unless every verse a page returns has its first word on that page, and does not use
`page_number`. An ayah that spans two pages is returned by its first page with all its words.
Word ids are source ids and do not follow reading order; reading order is (verse id, word
position).

Text fields used:

- `text_qpc_hafs`: the King Fahd Complex Hafs text. This is the canonical display text and the
  subject of the integrity checksums. It is designed for the KFGQPC Uthmanic Hafs font (R4).
- `text_uthmani`: standard-Unicode Uthmani text, used only for sharing an ayah to other apps,
  where the KFGQPC font is not available.
- `text_imlaei_simple`: simplified spelling without diacritics, used only as the search index.

**Rationale**: the concept names the Quran.com API and the King Fahd Complex as trusted
sources; the API serves the Complex's own Hafs text together with the word-level line and page
numbers of the 604-page Madani Mushaf, which is exactly what a page-exact view needs.

**Rejected**: third-party repackagings on npm or GitHub (longer trust chain); runtime API calls
(breaks offline-first, and text could change under the app); the per-page glyph fonts (QCF V1
or V2: 604 font files, about 25 MB, and the text becomes opaque glyph codes).

**Hardening, post-MVP task**: cross-verify the imported `text_qpc_hafs` against the King Fahd
Complex's own published dataset (`qurancomplex.gov.sa`) as an independent second source.

## R3. Deriving the page layout

The API gives a line number for every word but not for surah name banners or basmala lines.
The import derives them and stores them explicitly:

- Pages 1 and 2 have 8 lines; pages 3 to 604 have 15. The import asserts this.
- On each page, a line number with no words is a banner or basmala line belonging to the next
  surah that starts after it (possibly on the next page).
- A surah with `bismillah_pre = true` owns two such lines directly before its first ayah line:
  surah name, then basmala. A surah with `bismillah_pre = false` (surahs 1 and 9) owns one: the
  surah name.
- If the count of empty lines before a surah start does not match that rule, the import fails
  rather than guessing.
- Lines are walked in reading order (verse id, then word position), with each word on its
  `v1_page` and `line_v1` (R2); word ids are not in reading order and are not used for
  ordering.
- The basmala line is rendered from the words of ayah 1:1 without its end marker, read from the
  database. It is never a string literal in code.

Verified on page 604: lines 1 to 2, 5 to 6 and 10 to 11 are empty and precede surahs 112, 113
and 114.

## R4. Quran font

**Decision**: bundle `UthmanicHafs1Ver18.ttf` (KFGQPC Uthmanic Script Hafs), taken from
`quran/quran.com-frontend-next` at `public/fonts/quran/hafs/uthmanic_hafs/`, pinned by SHA-256
in the sources registry. It is the font Quran.com pairs with `text_qpc_hafs`.

**Rendering rule**: Quran text uses this family with no fallback list. A startup check confirms
the font asset is present and matches its checksum; on failure the Mushaf shows an error state.

**Licence**: the King Fahd Complex distributes its fonts free of charge for use and
redistribution, without modification and not for sale. Marked "to verify" in the registry.

## R5. Page view rendering

**Decision**: draw each page as 15 (or 8) line slots. An ayah line is one line of text built
from that line's words, each word a tappable span carrying its ayah id. Lines are justified to
the page width by distributing space between words; a line whose natural width is well below
the page width (the short last line of a surah, and all of pages 1 and 2) is centred instead.
One font size is computed per page so the widest line fits the width and all lines fit the
height. The whole page scales as a unit.

**Rationale**: one small font instead of 604; real text that screen readers, selection
highlight and hit testing can work with; identical line content to print (SC-003) because line
membership is data.

**Risk**: inter-word justification will not be glyph-identical to the printed kashida
justification. Line breaks, which are what readers rely on for memorisation, are identical.
Glyph-exact pages (per-page fonts) can be added later behind the same page-line data.

## R6. Tafsir source

**Decision**: Al-Tafsir Al-Muyassar, Quran.com resource id 16 (`ar-tafsir-muyassar`), imported
with `GET /tafsirs/16/by_chapter/{1..114}?per_page=300` (plain Arabic text). Verified
2026-11-15: some entries explain a group of consecutive ayahs (for example `4:66` to `4:68`), and
`by_chapter` lists such an entry once, under the group's first ayah (5278 entries for 6236
ayahs, 494 gaps). For each unlisted ayah the import requests `GET /tafsirs/16/by_ayah/{key}`
and requires its entry to be the one listed under the nearest listed ayah before it: the same
resource, exactly the same text, and a `verses` map that is a contiguous run starting at that
listed ayah and contains the requested ayah. The API cuts the `verses` map at 10 keys (the entry
for `70:19` to `70:30` lists only `70:19` to `70:28`), so a map of exactly 10 keys is accepted
without containing the ayah. The listed text is then stored, unchanged, for that ayah. Anything
else fails the import. The schema allows more tafsir works later (ids 91 As-Sa'di, 14 Ibn Kathir).

**Rationale**: the concept lists it first; it is concise, mostly one entry per ayah, and
published by the King Fahd Complex.

## R7. Audio source

**Decision**: stream per-ayah MP3 files. The reciter list comes from the Quran.com API
(`GET /resources/recitations`, `GET /recitations/{id}/by_chapter/{n}`), and the import stores
one URL template per reciter.

Verified URL shapes:

| Reciter | API id | Files |
| --- | --- | --- |
| Al-Husary (Mu'allim) | 12 | `everyayah/Husary_Muallim_128kbps/{SSS}{AAA}.mp3` |
| Al-Husary (Murattal) | 6 | `everyayah/Husary_64kbps/{SSS}{AAA}.mp3` |
| Al-Minshawi (Murattal) | 9 | `Minshawi/Murattal/mp3/{SSS}{AAA}.mp3` |
| Mishary Alafasy | 7 | `Alafasy/mp3/{SSS}{AAA}.mp3` |
| AbdulBaset (Murattal) | 2 | `AbdulBaset/Murattal/mp3/{SSS}{AAA}.mp3` |

Relative paths resolve against `https://verses.quran.com/`. The two Husary recitations are
served by the API from a mirror of EveryAyah; the app uses the origin,
`https://everyayah.com/data/{folder}/{SSS}{AAA}.mp3` (verified reachable). The import checks
that every file name of a reciter follows the `{SSS}{AAA}.mp3` pattern and that the first and
last ayah of the Quran resolve, and fails otherwise.

**Terms**: the concept requires checking the terms of use before publishing. Both audio sources
are marked "to verify" in the registry, which blocks a public release (constitution, III) but
not development.

**Player**: `just_audio` with a per-ayah playlist. Background playback and lock-screen controls
are out of MVP scope.

## R8. Storage

**Decision**:

- **Content database** `assets/data/quran.db`: SQLite, read-only, produced by the import tool
  and committed. Copied to app storage on first run and whenever its dataset version changes.
- **User database** `user.db`: SQLite, created on the device; bookmarks and memorisation marks.
- **Settings**: `shared_preferences`.
- Access through the `sqlite3` Dart package (bundles SQLite for every platform, including the
  test host) and small hand-written repository classes.

**Rationale**: SQLite gives indexed lookups by page, ayah and surah and LIKE search over 6236
rows with no parsing at startup. Hand-written SQL avoids a code-generation step.

**Rejected**: JSON assets parsed at startup (slow, memory heavy for 83 thousand word rows);
drift (adds build_runner for a schema of nine small tables); Hive or Isar (no ad hoc queries).

**Determinism**: SQLite file bytes are not guaranteed stable across versions, so integrity is
pinned on content, not on the file: SHA-256 over an ordered dump of each table's canonical
columns, recorded in `assets/data/manifest.json` and re-computed in tests.

## R9. Search

**Decision**: `LIKE` over `ayahs.text_search` (from `text_imlaei_simple`), after normalising
the *query*: strip diacritics and tatweel, fold alef forms to bare alef, alef maqsura to yaa,
taa marbuta to haa, and apply the same folding to `text_search` at import time into a
`text_search_folded` column so both sides match. Results display the canonical text.
The rule is one function, `foldArabic` in the local package `packages/search_folding/`, which
both `tool/quran_import` and the app's `foldQuery` depend on by path, so the two sides cannot
drift; both sides' tests run the same vectors.

**Rationale**: 6236 short rows scan in a few milliseconds; FTS tokenisation handles Arabic
prefixes poorly and would miss matches inside words. The folded column is derived from a
source field and is never displayed, which Principle I allows for search.

## R10. Story content catalog

**Decision**: a JSON catalog (`assets/content/catalog.json`, schema in
[contracts/catalog.schema.json](contracts/catalog.schema.json)) bundled with the app and
optionally refreshed at launch from `CATALOG_URL` (a build-time define; unset means bundled
only). A refreshed catalog is validated against the schema version and cached; an invalid one
is ignored.

- Items carry `review.status` (`planned`, `in_review`, `approved`) and `no_prophet_depiction`.
  Only `approved` items with the attestation set to true and a media entry are playable.
- Media is either `stream` (HTTPS MP4 or HLS, played with `video_player`) or `youtube` (played
  with `youtube_player_iframe`), covering both content options in the concept.
- The bundled catalog lists Juz Amma (surahs 78 to 114) and five prophet stories, all
  `planned`, with no media. No sample video and no invented story text ships.

**Rationale**: content is produced and reviewed outside the app and must be publishable without
an app release; a static file needs no backend.

## R11. State management, navigation, localisation

- **State**: `flutter_riverpod` 3 without code generation.
- **Navigation**: `go_router`, with deep-linkable routes for ayah, page and video so that
  cross-links between Mushaf and stories are plain routes.
- **Localisation**: Flutter `gen-l10n` with ARB files; `ar` is the default and fallback
  locale, `en` the second.
- **Screen wake**: `wakelock_plus`. **Share**: `share_plus`. **External links**:
  `url_launcher`.

## R12. Testing and CI

- Unit tests for the import parsers and layout derivation (using synthetic JSON in the API's
  shape with placeholder tokens, never Quran text), repositories (against the real bundled
  database), settings, search folding, catalog validation and the audio controller (with a
  fake player).
- Widget tests per acceptance scenario; golden tests for the Mushaf page, continuous view and
  each theme. Goldens load the real fonts.
- A dataset integrity test re-computes the manifest checksums and structural invariants.
- GitHub Actions on every PR: `dart format --set-exit-if-changed`, `flutter analyze`,
  `flutter test`, then a debug APK build uploaded as an artifact.

## R13. Open items carried to release

| Item | Owner | Blocks |
| --- | --- | --- |
| Verify audio terms of use (Quran.com recitations, EveryAyah) | Project owner | Public release |
| Verify KFGQPC font and Al-Muyassar redistribution terms | Project owner | Public release |
| Supply approved videos, related ayahs and reviewer name | Project owner | Stories becoming playable |
| Error report address | Project owner | Nothing; share sheet is the fallback |
| Final Android application id (working value `com.mazen109.muslim`) | Project owner | Store listing |
