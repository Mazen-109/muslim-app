# Feature Specification: Muslim MVP (Mushaf, Tafsir, Linked Stories)

**Feature Branch**: `001-muslim-mvp`
**Created**: 2026-11-14
**Status**: Approved for planning
**Input**: User description: the product concept in [docs/concept.md](../../docs/concept.md),
scoped to its section 6 "Suggested First Version (MVP)": the Mushaf, one tafsir, surah story
videos for Juz Amma, and five prophet stories, with everything linked.

## Scope

**In the MVP**

- The Mushaf: Uthmani text, printed-page view and continuous view, surah and juz index, search,
  bookmarks and memorisation marks, themes including black and white, audio recitation by
  several reciters (concept sections 2.1 and 3).
- One tafsir for every ayah, opened without leaving the page (2.2, 3.3).
- Surah story videos for Juz Amma and a prophet stories series with five stories, each linked
  to the Quran text in both directions (2.3, 2.4, 4 "Linking").
- The low-cost trust items from section 7: resume reading, adjustable font size in continuous
  mode, a Sources page, a "Report an error" action, and no ads in the Mushaf.

**Not in the MVP** (stays in the concept until specified): word meanings, more than one tafsir,
word-by-word audio highlighting, the prophets timeline and map, quizzes, the daily plan, kids
mode, khatma tracker, memorisation mode, recitation check, tajweed colours, background playback
and lock-screen controls, sleep timer, playback range and speed, downloads for offline audio and
video, video quality options, prayer times, qibla, adhkar, ayah of the day, widgets, personal
notes, thematic index, streaks, video subtitles, translations, accounts and sync.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Read the Mushaf (Priority: P1)

A reader opens the app and reads the Quran. They pick a surah or a juz from the index, or
continue from where they stopped. They read in the printed-page layout, which matches the
Madani Mushaf page for page and line for line, or switch to a continuous view where ayahs flow
as text and the font size is adjustable.

**Why this priority**: reading is the reason the app exists; every other story hangs off it.

**Independent Test**: install the app with no network, open any surah from the index, read in
both views, close the app, reopen it and land on the same ayah.

**Acceptance Scenarios**:

1. **Given** a first launch with no network, **When** the reader opens the index, **Then** all
   114 surahs are listed in order with their Arabic name, ayah count, Makki or Madani label and
   starting page, and all 30 juz are listed.
2. **Given** the index, **When** the reader taps a surah, **Then** the Mushaf opens in page view
   on the page where that surah starts.
3. **Given** page view, **When** the reader swipes, **Then** the next page appears in
   right-to-left order, and the page shows the same lines as the printed Madani Mushaf, with
   the surah name, juz and page number visible.
4. **Given** page view on any ayah, **When** the reader switches to continuous view, **Then**
   the same ayah is on screen, and switching back returns to the page that contains it.
5. **Given** continuous view, **When** the reader changes the font size, **Then** the text
   resizes immediately and the size is remembered next time.
6. **Given** the reader was on an ayah and closed the app, **When** they reopen it, **Then**
   the Mushaf opens on that ayah in the view they last used, with the index one tap away.
7. **Given** any reading screen, **When** the reader asks to go to a page number or to a surah
   and ayah number, **Then** the Mushaf opens there, and an out-of-range number is refused with
   a clear message.

---

### User Story 2 - Understand an ayah with tafsir (Priority: P1)

While reading, the reader taps an ayah and its tafsir slides up from the bottom. They read it,
move to the next or previous ayah's tafsir, and dismiss it to find the page exactly as it was.

**Why this priority**: with reading, this is the minimum that makes the app more than a text
viewer, and the concept names one tafsir as part of the MVP.

**Independent Test**: with no network, tap any ayah in either view and read its tafsir; the
source of the tafsir is named.

**Acceptance Scenarios**:

1. **Given** the Mushaf in either view, **When** the reader taps an ayah, **Then** a bottom
   sheet shows that ayah and its tafsir, names the tafsir and its author, and the page behind
   it has not moved.
2. **Given** the tafsir sheet, **When** the reader moves to the next or previous ayah, **Then**
   the sheet shows that ayah's tafsir, and the ayah is highlighted on the page.
3. **Given** the device is offline, **When** the reader opens tafsir for any of the 6236 ayahs,
   **Then** the tafsir is shown.

---

### User Story 3 - Listen to a recitation (Priority: P2)

The reader starts a recitation from the current ayah, chooses a reciter, and follows along: the
ayah being recited is highlighted and the Mushaf turns the page or scrolls by itself.

**Why this priority**: audio is the most used feature after reading, and the ayah menu and
auto-scroll stories build on it.

**Independent Test**: with a network, start playback from the middle of a surah, watch the
highlight move ayah by ayah across a page boundary, change the reciter, pause and resume.

**Acceptance Scenarios**:

1. **Given** the Mushaf on an ayah, **When** the reader presses play, **Then** recitation
   starts from that ayah with the selected reciter and continues ayah by ayah to the end of
   the surah.
2. **Given** playback is running, **When** the recitation moves to the next ayah, **Then** that
   ayah is highlighted, and the view turns the page or scrolls so it stays visible.
3. **Given** the reciter list, **When** the reader opens it, **Then** it offers at least five
   reciters, at least one of them a teaching (Mu'allim) recitation, and the choice is
   remembered.
4. **Given** playback is running, **When** the reader pauses, resumes, or skips to the next or
   previous ayah, **Then** playback and highlight follow.
5. **Given** no network, **When** the reader presses play, **Then** the app says recitation
   needs a connection, offers to retry, and reading is unaffected.
6. **Given** playback is running, **Then** the screen stays awake until playback stops.

---

### User Story 4 - Act on an ayah from one menu (Priority: P2)

A long press on any ayah opens one menu with every action for that ayah: listen to only that
ayah with a chosen reciter, repeat it a chosen number of times, open its tafsir, jump to the
surah's story, bookmark it, or share it.

**Why this priority**: it is the concept's main interaction for learning pronunciation and
memorising, and it ties the other stories together.

**Independent Test**: long press an ayah and complete each action in turn.

**Acceptance Scenarios**:

1. **Given** the Mushaf in either view, **When** the reader long presses an ayah, **Then** a
   menu opens for that ayah with: Listen, Repeat, Tafsir, Surah story, Bookmark, Share.
2. **Given** the menu, **When** the reader chooses Listen, **Then** only that ayah is recited,
   and they can change the reciter from the same place.
3. **Given** the menu, **When** the reader chooses Repeat and a count from 2 to 20, **Then**
   the ayah is recited that many times and then stops, with the remaining count visible.
4. **Given** the menu, **When** the reader chooses Tafsir, **Then** the tafsir sheet of story 2
   opens for that ayah.
5. **Given** the surah has an approved story video, **When** the reader chooses Surah story,
   **Then** the video opens; when it has none, the action shows as not yet available.
6. **Given** the menu, **When** the reader chooses Share, **Then** the system share sheet opens
   with the ayah text, the surah name and the ayah number.

---

### User Story 5 - Keep bookmarks and memorisation marks (Priority: P2)

The reader bookmarks ayahs to return to and marks ayahs they have memorised. Both are listed in
one place and visible on the page.

**Why this priority**: readers return daily; without this they must remember positions.

**Independent Test**: bookmark two ayahs and mark one as memorised, restart the app, find all
three in the list and open each.

**Acceptance Scenarios**:

1. **Given** the ayah menu, **When** the reader bookmarks an ayah, **Then** it appears in the
   bookmarks list with its surah, ayah number and page, newest first, and the ayah shows a
   bookmark indicator on the page.
2. **Given** the ayah menu, **When** the reader marks an ayah as memorised, **Then** the ayah
   shows a memorised indicator, and the list has a separate memorised section.
3. **Given** the bookmarks list, **When** the reader taps an entry, **Then** the Mushaf opens
   on that ayah.
4. **Given** a bookmark or mark, **When** the reader removes it, **Then** it disappears from
   the list and the page, and both survive an app restart otherwise.

---

### User Story 6 - Search the Quran (Priority: P2)

The reader types a word or phrase in Arabic, with or without diacritics, and gets every ayah
that contains it.

**Why this priority**: it is in the concept's core Mushaf list and is how readers find an ayah
they half remember.

**Independent Test**: with no network, search a common word typed without diacritics and open
one of the results.

**Acceptance Scenarios**:

1. **Given** the search screen, **When** the reader types at least two Arabic letters, **Then**
   matching ayahs are listed with the full ayah text, surah name and ayah number, and the
   number of matches is shown.
2. **Given** a query typed with diacritics or with different forms of alef, yaa or taa
   marbuta, **Then** the results are the same as for the plain spelling.
3. **Given** results, **When** the reader taps one, **Then** the Mushaf opens on that ayah and
   highlights it briefly.
4. **Given** a query with no match, **Then** the screen says nothing was found and keeps the
   query editable.

---

### User Story 7 - Choose a theme, including black and white (Priority: P2)

The reader picks a theme for the whole app: light, night, black on white, or white on black.

**Why this priority**: night reading and low-distraction reading are explicit in the concept.

**Independent Test**: switch through all four themes from settings and check the Mushaf, the
index and the stories screens in each.

**Acceptance Scenarios**:

1. **Given** settings, **When** the reader picks a theme, **Then** every screen changes
   immediately and the choice is remembered.
2. **Given** either black and white theme, **Then** all interface surfaces, text and icons use
   only black, white and greys, and the white-on-black theme uses a true black background.
3. **Given** either black and white theme, **When** a video plays, **Then** it keeps its
   colours unless the reader turned on the "black and white videos" option.

---

### User Story 8 - Read hands-free with auto-scroll (Priority: P3)

In continuous view the reader turns on auto-scroll. The text moves at a comfortable speed they
set once; a tap pauses and another resumes.

**Why this priority**: valuable for long reading sessions but not needed for a first usable
release.

**Independent Test**: turn on auto-scroll in continuous view, change the speed, tap to pause
and resume, and confirm the screen does not sleep.

**Acceptance Scenarios**:

1. **Given** continuous view, **When** the reader turns on auto-scroll, **Then** the text
   scrolls smoothly at the saved speed and the screen stays awake.
2. **Given** auto-scroll is running, **When** the reader taps the text, **Then** it pauses, and
   a second tap resumes it.
3. **Given** the speed slider, **When** the reader moves it, **Then** the speed changes at once
   and is remembered.
4. **Given** page view, **When** the reader asks for auto-scroll, **Then** the app offers to
   switch to continuous view; normal page turning remains the default.
5. **Given** auto-scroll is on and a recitation starts, **Then** scrolling follows the
   recitation instead of the timer, and returns to the timer when the recitation stops.
6. **Given** auto-scroll reaches the end of the surah, **Then** it stops and releases the
   screen.

---

### User Story 9 - Watch the story of a surah (Priority: P3)

The reader opens the stories section and finds a short video for each surah of Juz Amma that
has been produced and approved. While reading one of those surahs, a "Watch the story" button
is there; from the video, one tap returns to the surah.

**Why this priority**: linking is the concept's core idea, but it depends on video content that
is produced and reviewed outside the app.

**Independent Test**: with a catalog that contains one approved video, open it from the stories
section and from the Mushaf, play it, and return to the surah from the video.

**Acceptance Scenarios**:

1. **Given** the stories section, **When** the reader opens Surah stories, **Then** the 37
   surahs of Juz Amma (78 to 114) are listed; those with an approved video can be played and
   the rest show as coming soon.
2. **Given** an approved video, **When** the reader opens it, **Then** it plays with standard
   controls, shows the surah's Makki or Madani label, and offers "Read the surah".
3. **Given** the Mushaf is open on a surah with an approved video, **Then** a "Watch the story"
   button is visible without covering the text, and it opens that video.
4. **Given** a catalog entry that is not approved, or whose no-depiction attestation is
   missing, **Then** the app never plays it, whatever else the entry contains.
5. **Given** no network, **When** the reader opens a video, **Then** the app says video needs a
   connection and offers to retry.

---

### User Story 10 - Follow the stories of the prophets (Priority: P3)

The reader browses a series of prophet stories in chronological order. Each episode lists the
ayahs that tell the story, and each of those ayahs leads back to the Mushaf. From the Mushaf,
an ayah that belongs to a story offers that story.

**Why this priority**: same dependency on reviewed content as story 9.

**Independent Test**: with a catalog that contains one approved episode with related ayahs,
open the episode, jump to one of its ayahs, and from that ayah's menu return to the episode.

**Acceptance Scenarios**:

1. **Given** the stories section, **When** the reader opens Stories of the prophets, **Then**
   the series is listed in chronological order, with approved episodes playable and the rest
   shown as coming soon.
2. **Given** an episode, **Then** its related ayahs are listed as surah and ayah ranges, and
   tapping one opens the Mushaf there.
3. **Given** an ayah inside the related ayahs of an approved episode, **When** the reader opens
   the ayah menu, **Then** it offers that episode.
4. **Given** any episode artwork or thumbnail, **Then** it shows places, maps or events and
   never a prophet.

---

### User Story 11 - See the sources and report an error (Priority: P3)

The reader can see where the Quran text, tafsir, audio, fonts and videos come from, and can
report an error on any ayah, tafsir or video.

**Why this priority**: required for trust and for licence attribution before any public
release, but it does not block daily use.

**Independent Test**: open the Sources page and read every entry; start an error report from an
ayah and see the ayah reference pre-filled.

**Acceptance Scenarios**:

1. **Given** settings, **When** the reader opens Sources, **Then** every content source is
   listed with its name, provider and licence or terms.
2. **Given** an ayah menu, a tafsir sheet or a video screen, **When** the reader chooses
   "Report an error", **Then** a report is prepared with the exact reference (surah and ayah,
   tafsir name, or video id) and the app version, ready to send.

### Edge Cases

- The first two pages of the Mushaf have a different, centred layout with fewer lines; they
  must render as in print.
- A surah can start in the middle of a page, and its name banner can sit at the bottom of the
  previous page while its basmala is at the top of the next.
- Surah 9 has no basmala; surah 1's basmala is its first ayah.
- An ayah can span two pages; highlight, tafsir and the menu must treat it as one ayah.
- Playback crosses the end of a surah: it stops there in the MVP.
- The reciter is changed while playback is running: playback continues from the current ayah
  with the new reciter.
- The network drops during recitation or video: playback pauses with a retry, and reading
  continues.
- The Quran font fails to load: the Mushaf shows an error state and never substitutes a font.
- The content catalog is missing, malformed, or newer than the app understands: the stories
  section shows its last valid state or an empty state, and the Mushaf is unaffected.
- Very small and very large screens, and large system text sizes: no clipped or overlapping
  text; the page layout scales as a whole.
- The reader long presses during auto-scroll: auto-scroll pauses while the menu is open.

## Requirements *(mandatory)*

### Functional Requirements

**Quran text and Mushaf**

- **FR-001**: The app MUST contain the complete Quran text in Uthmani script, imported from a
  trusted source, and MUST display it exactly as imported.
- **FR-002**: The app MUST verify the integrity of the bundled Quran data against recorded
  checksums as part of its automated checks, and builds MUST fail when they do not match.
- **FR-003**: The app MUST offer an index of the 114 surahs and the 30 juz.
- **FR-004**: The app MUST offer a page view that reproduces the 604-page Madani Mushaf layout
  page for page and line for line, turned right to left.
- **FR-005**: The app MUST offer a continuous view of ayahs as flowing text with an adjustable
  font size.
- **FR-006**: Readers MUST be able to switch between the two views without losing their ayah.
- **FR-007**: The app MUST remember the last ayah read and open there on the next launch.
- **FR-008**: Readers MUST be able to jump to a page number or to a surah and ayah number.
- **FR-009**: The Mushaf screen MUST NOT show advertising or promotional content.

**Tafsir**

- **FR-010**: The app MUST include one complete Arabic tafsir (Al-Tafsir Al-Muyassar) for all
  6236 ayahs, available offline, shown unaltered and attributed.
- **FR-011**: Tapping an ayah MUST open its tafsir in a bottom sheet without leaving or moving
  the page, with next and previous ayah navigation.

**Audio**

- **FR-012**: The app MUST play per-ayah recitations streamed from a listed source, starting at
  any ayah and continuing to the end of the surah.
- **FR-013**: The app MUST offer at least five reciters including at least one teaching
  (Mu'allim) recitation, and MUST remember the selected reciter.
- **FR-014**: The ayah being recited MUST be highlighted, and the view MUST follow it.
- **FR-015**: Readers MUST be able to play a single ayah and to repeat an ayah from 2 to 20
  times.
- **FR-016**: The screen MUST stay awake while recitation or auto-scroll is running, and MUST
  be released when both stop.

**Ayah actions**

- **FR-017**: A long press on an ayah MUST open one menu with Listen, Repeat, Tafsir, Surah
  story, Bookmark, Share, and Report an error.
- **FR-018**: Readers MUST be able to bookmark ayahs and mark ayahs as memorised, see both in a
  list and on the page, open them, and remove them.
- **FR-019**: Readers MUST be able to share an ayah's text with its surah name and number.

**Search**

- **FR-020**: Readers MUST be able to search the whole Quran in Arabic, offline, with
  diacritics and common letter variants ignored in the query.
- **FR-021**: Search results MUST show the canonical ayah text and open the Mushaf at the
  chosen ayah.

**Themes and reading comfort**

- **FR-022**: The app MUST offer four app-wide themes: light, night, black on white, and white
  on black, and MUST remember the choice.
- **FR-023**: Videos MUST keep their colours in the black and white themes unless the reader
  enables black and white video.
- **FR-024**: The app MUST offer optional auto-scroll in continuous view with a remembered
  speed, tap to pause and resume, and it MUST follow the recitation when audio is playing.

**Stories**

- **FR-025**: The app MUST read its videos from a content catalog that can be updated without
  releasing a new app version.
- **FR-026**: The app MUST play only catalog items that are marked approved by a reviewer and
  carry a no-depiction attestation; all others are shown as coming soon or hidden.
- **FR-027**: The app MUST list a story entry for each surah of Juz Amma and a prophet stories
  series in chronological order.
- **FR-028**: A surah with an approved story MUST show a "Watch the story" entry point in the
  Mushaf, and every video MUST link back to its surah or related ayahs.
- **FR-029**: An ayah inside the related ayahs of an approved prophet episode MUST offer that
  episode from its menu.

**Trust**

- **FR-030**: The app MUST include a Sources page listing the origin and terms of the Quran
  text, tafsir, audio, fonts and video content.
- **FR-031**: Readers MUST be able to start an error report from any ayah, tafsir or video with
  the reference pre-filled.
- **FR-032**: Reading, tafsir, search, bookmarks and themes MUST work with no network and no
  account. All reader data MUST stay on the device.
- **FR-033**: The app MUST be Arabic-first and right-to-left, with English available as a
  second interface language.
- **FR-034**: Every interactive element MUST be usable with a screen reader and MUST meet the
  minimum touch target size.

### Key Entities *(include if feature involves data)*

- **Surah**: one of 114 chapters; number, Arabic and transliterated names, ayah count, Makki or
  Madani, revelation order, first and last page.
- **Ayah**: one of 6236 verses; belongs to a surah; has its canonical text, a search form from
  the source, and its page, juz and hizb.
- **Word**: a word of an ayah with its position, and the page and line where it is printed.
- **Page line**: one line of a Mushaf page; either ayah text, a surah name banner or a basmala.
- **Tafsir entry**: the text of one tafsir work for one ayah, with the work's name and author.
- **Reciter**: a named recitation with its style and where its per-ayah audio is found.
- **Bookmark / memorisation mark**: an ayah the reader saved or marked, with when.
- **Reading position and settings**: last ayah, view, font size, theme, reciter, auto-scroll
  speed.
- **Story video**: a catalog item for a surah or a prophet episode; media location, review
  status, no-depiction attestation, and for episodes the related ayah ranges.
- **Source**: an origin of content with its licence or terms and verification status.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A new reader reaches the first ayah of any surah within 10 seconds of first
  launch, with no network and no sign-up.
- **SC-002**: The bundled Quran text matches the trusted source for 100% of the 6236 ayahs,
  verified automatically on every change to the project.
- **SC-003**: Every one of the 604 pages shows the same line breaks as the printed Madani
  Mushaf.
- **SC-004**: Turning a page or opening tafsir responds in under 300 ms on a mid-range phone,
  and scrolling shows no visible stutter.
- **SC-005**: A returning reader is back at their last ayah within 3 seconds of opening the
  app.
- **SC-006**: A reader can hear any single ayah within two taps after the long press, and
  recitation starts within 3 seconds on a typical mobile connection.
- **SC-007**: Search returns results for a query within 1 second, offline.
- **SC-008**: In every theme, body text has a contrast ratio of at least 7:1 against its
  background.
- **SC-009**: No unapproved story item can be played: 100% of catalog items without approval
  and attestation are blocked in automated tests.
- **SC-010**: Every content source used by the app appears on the Sources page.

## Assumptions

- The first release targets Android phones; iOS is built from the same code but released later.
  Tablets work but are not specifically designed for.
- The Quran text, page layout and tafsir come from the Quran.com API, which serves the King
  Fahd Complex Hafs text; audio comes from the Quran.com recitation files, with EveryAyah as
  the alternative listed in the concept.
- The default reciters are Al-Husary (Mu'allim), Al-Husary (Murattal), Al-Minshawi (Murattal),
  Mishary Alafasy and AbdulBaset (Murattal). The list is data and can change without a spec
  change.
- Video content is produced, licensed and reviewed outside this project. The app ships with
  catalog entries for Juz Amma and five prophet stories in the "planned" state, and they become
  playable when the project owner supplies approved videos. No placeholder religious content is
  written to fill them.
- The five prophet stories default to Adam, Nuh, Ibrahim, Yusuf and Musa (peace be upon them).
  The project owner can change the selection by editing the catalog.
- The related ayahs of each prophet episode are supplied with the reviewed episode; the app
  does not derive them.
- Videos are delivered as stream URLs or as YouTube videos from licensed channels; the catalog
  supports both.
- Error reports are sent through the device's share sheet or mail app; there is no report
  server in the MVP.
- Recitation and video need a network connection in the MVP; downloads come later.
- There are no user accounts, no sync and no analytics.

## Open Questions for the Project Owner

These do not block development; each has a working default above.

1. Which five prophet stories ship first, and who is the qualified reviewer?
2. Where will the videos be hosted: your own storage, or YouTube videos from licensed channels?
3. What address should error reports go to?
4. Have the audio terms of use been confirmed for publishing? This is a release gate, not a
   development gate.
