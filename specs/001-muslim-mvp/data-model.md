# Data Model: Muslim MVP

**Date**: 2026-11-14 | **Plan**: [plan.md](plan.md) | **Research**: [research.md](research.md)

Three stores: a read-only content database built by the import tool, a user database created on
the device, and key-value settings. Two JSON documents are described in
[contracts/](contracts/).

## 1. Content database (`assets/data/quran.db`, read-only)

All text columns are stored exactly as received from the source unless marked *derived*.

### `meta`

| Column | Type | Rule |
| --- | --- | --- |
| `key` | TEXT PK | `dataset_version`, `generated_at`, `source` |
| `value` | TEXT NOT NULL | `dataset_version` is an integer string, starting at `1` |

### `surahs` (114 rows)

| Column | Type | Rule |
| --- | --- | --- |
| `id` | INTEGER PK | 1 to 114 |
| `name_ar` | TEXT NOT NULL | `name_arabic` |
| `name_en` | TEXT NOT NULL | `name_simple` |
| `revelation_place` | TEXT NOT NULL | exactly `makkah` or `madinah` |
| `revelation_order` | INTEGER NOT NULL | 1 to 114, unique |
| `ayah_count` | INTEGER NOT NULL | sums to 6236 |
| `bismillah_pre` | INTEGER NOT NULL | 0 or 1; 0 only for surahs 1 and 9 |
| `page_start` | INTEGER NOT NULL | 1 to 604; the API's `pages[0]`, which is the page of the first word of ayah 1 (the surah name and basmala lines can sit at the bottom of the previous page, as for 20 surahs) |
| `page_end` | INTEGER NOT NULL | `page_start` to 604; the page of the surah's last word |

### `ayahs` (6236 rows)

| Column | Type | Rule |
| --- | --- | --- |
| `id` | INTEGER PK | 1 to 6236, in Mushaf order |
| `surah_id` | INTEGER NOT NULL | FK `surahs.id` |
| `ayah_number` | INTEGER NOT NULL | 1 to the surah's `ayah_count` |
| `verse_key` | TEXT NOT NULL UNIQUE | `"{surah_id}:{ayah_number}"` |
| `text_qpc_hafs` | TEXT NOT NULL | canonical display text |
| `text_uthmani` | TEXT NOT NULL | share text |
| `text_search` | TEXT NOT NULL | `text_imlaei_simple` |
| `text_search_folded` | TEXT NOT NULL | *derived* from `text_search` by the folding rule in research R9; never displayed |
| `page` | INTEGER NOT NULL | page of the ayah's first word (its `v1_page`), 1 to 604 |
| `juz` | INTEGER NOT NULL | 1 to 30 |
| `hizb` | INTEGER NOT NULL | 1 to 60 |
| `rub_el_hizb` | INTEGER NOT NULL | 1 to 240 |
| `sajdah` | INTEGER NULL | sajdah number when the ayah has one |

Indexes: `(surah_id, ayah_number)` unique, `(page)`, `(juz)`.

### `words` (one row per word and per ayah end marker)

| Column | Type | Rule |
| --- | --- | --- |
| `id` | INTEGER PK | source word id; ids do **not** follow reading order |
| `ayah_id` | INTEGER NOT NULL | FK `ayahs.id` |
| `position` | INTEGER NOT NULL | 1-based within the ayah; unique with `ayah_id` |
| `char_type` | TEXT NOT NULL | exactly `word` or `end` |
| `text_qpc_hafs` | TEXT NOT NULL | the word, or the ayah end marker |
| `page` | INTEGER NOT NULL | 1 to 604; the API's `v1_page` (research R2) |
| `line` | INTEGER NOT NULL | 1 to 15; the API's `line_v1`, equal to its `line_number` |

Indexes: `(page, line, ayah_id, position)`, `(ayah_id, position)` unique.

Reading order is `(ayah_id, position)`, not `id`: the source's word ids are not sequential in
the Mushaf (for example, the words of `2:1` have higher ids than those of `112:1`). Queries that
lay out a page order its words by `(line, ayah_id, position)`. Along reading order, `(page,
line)` never decreases.

Invariants asserted by the import for every ayah: it has exactly one `end` row and that row is
last; and the concatenation of its rows' text in position order, with every `U+0020` and
`U+00A0` removed, equals `ayahs.text_qpc_hafs` with every `U+0020` and `U+00A0` removed.
Spaces are left out of the comparison because the source places them inconsistently (an ayah
that opens with the rub el hizb mark `U+06DE` has `U+0020` inside that word but `U+00A0` in the
ayah text; `2:72` has `U+0020` before its end marker; a few ayahs have no space in the ayah text
between two separate words, for example before the sajdah sign `U+06E9`). Both texts are stored
exactly as received; a word's text may contain an internal `U+0020`. This ties the page layout
to the canonical text, so a page can never show different letters from the ayah record.

### `page_lines` (604 pages; 8 lines on pages 1 and 2, 15 elsewhere)

| Column | Type | Rule |
| --- | --- | --- |
| `page` | INTEGER NOT NULL | 1 to 604 |
| `line` | INTEGER NOT NULL | 1 to 15 |
| `line_type` | TEXT NOT NULL | exactly `ayah`, `surah_name` or `basmala` |
| `surah_id` | INTEGER NULL | set for `surah_name` and `basmala`; NULL for `ayah` |

Primary key `(page, line)`. Every `ayah` line has at least one row in `words`; `surah_name` and
`basmala` lines have none. There are exactly 114 `surah_name` lines and 112 `basmala` lines.

### `juzs` (30 rows)

| Column | Type | Rule |
| --- | --- | --- |
| `id` | INTEGER PK | 1 to 30 |
| `first_ayah_id` | INTEGER NOT NULL | FK `ayahs.id` |
| `last_ayah_id` | INTEGER NOT NULL | FK `ayahs.id`; ranges are contiguous and cover 1 to 6236 |
| `page_start` | INTEGER NOT NULL | page of `first_ayah_id` |

### `tafsirs` and `tafsir_texts`

`tafsirs`: `id` INTEGER PK (source resource id; 16 in the MVP), `name_ar` TEXT NOT NULL,
`author` TEXT NOT NULL, `language` TEXT NOT NULL, `slug` TEXT NOT NULL UNIQUE.

`tafsir_texts`: `tafsir_id` INTEGER NOT NULL, `ayah_id` INTEGER NOT NULL, `text` TEXT NOT NULL,
primary key `(tafsir_id, ayah_id)`. The MVP has 6236 rows for tafsir 16, none empty. When the
source explains a group of consecutive ayahs in one entry, every ayah of the group has a row
with that same text (research R6).

### `reciters` (5 rows in the MVP)

| Column | Type | Rule |
| --- | --- | --- |
| `id` | INTEGER PK | source recitation id |
| `name_ar` | TEXT NOT NULL | |
| `name_en` | TEXT NOT NULL | |
| `style` | TEXT NULL | exactly `murattal`, `mujawwad`, `muallim` or NULL |
| `url_template` | TEXT NOT NULL | HTTPS URL containing `{surah3}` and `{ayah3}` (zero-padded to 3 digits) |
| `source_id` | TEXT NOT NULL | id of an entry in the sources registry |
| `sort_order` | INTEGER NOT NULL | display order |

## 2. Provenance manifest (`assets/data/manifest.json`)

Described by [contracts/dataset-manifest.schema.json](contracts/dataset-manifest.schema.json).
It records the dataset version, generation time, every source request (URL and SHA-256 of the
response body), row counts, and one SHA-256 per table computed over its rows in primary-key
order with columns joined by `U+001F` and rows by `U+001E`. The integrity test re-computes the
table hashes from `quran.db` and compares.

## 3. User database (`user.db`, on device)

Schema version stored in `PRAGMA user_version`, starting at 1.

### `bookmarks`

| Column | Type | Rule |
| --- | --- | --- |
| `ayah_id` | INTEGER PK | 1 to 6236; one bookmark per ayah |
| `created_at` | INTEGER NOT NULL | Unix milliseconds |

### `memorisation_marks`

| Column | Type | Rule |
| --- | --- | --- |
| `ayah_id` | INTEGER PK | 1 to 6236 |
| `created_at` | INTEGER NOT NULL | Unix milliseconds |

## 4. Settings (key-value)

| Key | Type | Values and default |
| --- | --- | --- |
| `theme` | string | `light` (default), `night`, `black_on_white`, `white_on_black` |
| `reading_mode` | string | `pages` (default), `continuous` |
| `font_scale` | double | 0.8 to 2.0 in steps of 0.1, default 1.0; continuous view only |
| `last_ayah_id` | int | 1 to 6236; absent before first read |
| `reciter_id` | int | a `reciters.id`; default 12 (Al-Husary, Mu'allim) |
| `repeat_count` | int | 2 to 20, default 3 |
| `autoscroll_speed` | double | 10 to 120 logical pixels per second, default 30 |
| `video_grayscale` | bool | default false |
| `locale` | string | `ar` (default), `en` |

## 5. Domain types (in code)

- `AyahRef(surah, ayah)` with parsing and formatting of `"S:A"` keys and range validation
  against surah ayah counts.
- `AyahRange(from, to)` inclusive, `from <= to` in Mushaf order, with `contains(AyahRef)`.
- `MushafPage(number, lines)`, `PageLine` as a sealed type: `AyahLine(words)`,
  `SurahNameLine(surah)`, `BasmalaLine(surah)`.
- `PlaybackState`: `idle`, `loading`, `playing`, `paused`, `error`; with current `AyahRef`,
  reciter id, and remaining repeats.
- `StoryItem` with `isPlayable` computed as: `review.status == approved` and
  `no_prophet_depiction == true` and `media != null`.

## 6. State transitions

**Playback**: `idle` → `loading` (play pressed) → `playing` ⇄ `paused`; `playing` → `playing`
on ayah change; any → `error` on load failure (keeps the ayah, offers retry); `playing` →
`idle` at the end of the surah, when the repeat count is exhausted, or on stop.

**Auto-scroll**: `off` → `running` ⇄ `paused` (tap, or a sheet or menu opening); `running` →
`following_audio` while playback is `playing`, back to `running` when it stops; any → `off` at
the end of the surah, on leaving continuous view, or when turned off.

**Story item**: `planned` → `in_review` → `approved`, changed only in the catalog by the
content owner. The app never changes a review status.
