# App Routes Contract

Routes are the app's internal interface between features. Cross-links between the Mushaf and
the stories are plain route navigations, so each feature depends only on this table.

| Route | Parameters | Screen | Notes |
| --- | --- | --- | --- |
| `/` | none | Launch redirect | To `/mushaf` at `last_ayah_id` when set, otherwise to `/index` |
| `/index` | `tab` = `surahs` (default) or `juz` | Surah and juz index | |
| `/mushaf` | `ayah` = `S:A`, or `page` = 1 to 604; optional `highlight` = `1` | Mushaf reader | Opens in the saved reading mode. Invalid values redirect to `/index` with a message. `highlight=1` flashes the ayah once |
| `/search` | optional `q` | Search | |
| `/bookmarks` | none | Bookmarks and memorised list | |
| `/stories` | `tab` = `surahs` (default) or `prophets` | Stories home | |
| `/stories/surah/:surah` | surah 1 to 114 | Surah story player | Only reachable for a playable item; otherwise shows the coming-soon state |
| `/stories/prophet/:storyId` | catalog id | Prophet story: episodes list | |
| `/stories/prophet/:storyId/:episodeId` | catalog ids | Episode player with related ayahs | |
| `/settings` | none | Settings | Theme, language, font size, reciter, black and white video |
| `/settings/sources` | none | Sources page | |

Bottom navigation destinations: Mushaf (`/` behaviour), Stories (`/stories`), Bookmarks
(`/bookmarks`), Settings (`/settings`). Index and search are reached from the Mushaf app bar.

## Sheets (not routes)

- **Tafsir sheet**: opened by tapping an ayah. Input: ayah id. Has previous and next.
- **Ayah menu**: opened by long pressing an ayah. Input: ayah id.
- **Reciter picker**: opened from the player bar and from the ayah menu.
