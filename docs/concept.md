# Muslim (مسلم): Quran, Tafsir, and Visual Stories

> App name: **Muslim** (مسلم)

## 1. Overview

A single app that combines:

- The full Mushaf (Quran text) with audio recitation
- Tafsir (explanation) for every ayah
- Short videos telling the story of each surah
- Video series about the prophets and their stories

**Core idea:** everything is linked. While reading a surah, the user can jump to its story video, and from a video back to the related ayahs.

---

## 2. Core Sections

### 2.1 Mushaf

- Quran text in Uthmani script
- Search across the Quran
- Bookmarks and memorization markers
- Night mode
- Audio recitations from multiple reciters

### 2.2 Tafsir

- Tap an ayah to see its tafsir
- Multiple tafsir sources (e.g. Al-Muyassar, As-Sa'di, Ibn Kathir)
- Word meanings

### 2.3 Surah Stories (Videos)

- One short video (3–5 minutes) per surah, covering:
  - Reason for revelation (Asbab al-Nuzul)
  - Makki or Madani
  - Main theme
  - Key lessons

### 2.4 Stories of the Prophets (Videos)

- Episode series in chronological order, from Adam to Muhammad ﷺ
- Each episode is linked to the ayahs that mention the story

---

## 3. Reading Experience Features

### 3.1 Auto-Scroll (Optional)

The Mushaf scrolls by itself at a comfortable speed so the reader does not have to keep turning pages.

- On/off button in the reading screen; normal page turning stays the default
- Speed slider; the app remembers the user's preferred speed
- Tap the screen to pause, tap again to resume
- Screen stays awake while auto-scroll is running
- Two reading modes:
  - **Mushaf pages:** the printed-page layout, best for memorization
  - **Continuous scroll:** ayahs as flowing text, required for vertical auto-scroll
- When audio is playing, scrolling follows the recitation and the current ayah is highlighted

### 3.2 Black and White Version

- A full app theme chosen from settings, not only for the Mushaf
- Two variants:
  - Black on white
  - White on black
- Benefits: easier on the eyes, less distraction, saves battery on OLED screens (dark variant)
- Videos keep their colors unless the user chooses otherwise

### 3.3 Ayah Selection Menu

A long press on any ayah opens one menu with all actions:

- **Listen:** pick a reciter and hear only that ayah, to learn its correct pronunciation
- **Repeat:** replay the ayah a chosen number of times (useful for memorization and pronunciation)
- **Tafsir:** opens in a bottom sheet without leaving the page
- **Surah story:** jump to the surah's video
- **Bookmark** and **share**

Notes:

- Include at least one "Mushaf Mu'allim" (teaching) recitation, such as Al-Husary or Al-Minshawi, because it is slower and clearer
- Word-by-word highlighting synced with audio is possible but needs timing files per reciter; planned for after the first version

---

## 4. What Makes It Different

- **Linking:** a "Watch the story" button appears while reading (e.g. Surah Yusuf), and videos link back to the ayahs
- **Interactive timeline** of the prophets, with a map of places
- **Short quiz** after each video
- **Daily plan:** a reading portion (wird) plus one video
- **Kids mode** with simpler language

---

## 5. Key Decisions to Settle Early

- **Depiction of prophets:** Al-Azhar and most scholars prohibit depicting them. Videos should use voice narration with maps and illustrations of places and events, without showing the prophets.
- **Quran text source:** take the text from a trusted source (e.g. King Fahd Complex or the Quran.com API). Never type it manually; any error in the Quran text is unacceptable.
- **Video content:** this is the most expensive part. Options:
  - Start with licensed videos from trusted channels
  - Or produce a small set first (Juz Amma + 5 prophets)
- **Religious review:** every script is reviewed by a qualified specialist before publishing. Stories rely on the Quran and authentic Sunnah, without Isra'iliyyat.
- **Audio source:** per-ayah audio is available from sources such as EveryAyah and the Quran.com API, so recitations do not need to be cut manually. Check the terms of use before publishing.

---

## 6. Suggested First Version (MVP)

- Mushaf
- One tafsir
- Surah story videos for Juz Amma
- 5 prophet stories

---

## 7. Additional Suggested Features

These were not part of the original discussion; they are suggestions to consider.

### Reading and Memorization

- **Resume reading:** the app opens at the last ayah read
- **Khatma tracker:** set a goal (e.g. finish in 30 days) and the app calculates the daily portion
- **Memorization mode:** hide the ayah text and reveal it gradually to test recall
- **Recitation check:** the user records their own recitation and compares it with the reciter's audio
- **Tajweed colors:** optional color-coded tajweed rules (disabled in the black and white theme)
- **Adjustable font size** in continuous scroll mode

### Audio

- **Background playback** with lock-screen controls
- **Sleep timer** for recitation
- **Playback range:** play from ayah X to ayah Y, with repeat
- **Playback speed control** for recitation

### Offline and Performance

- **Offline mode:** Quran text and tafsir available without internet
- **Downloadable content:** download recitations and videos per surah to control storage
- **Video quality options** for slow connections

### Daily Use

- **Prayer times and Qibla direction**
- **Morning and evening Adhkar**
- **Ayah of the day** notification with a short tafsir
- **Home screen widget** (ayah of the day or reading progress)

### Learning and Engagement

- **Personal notes** on any ayah
- **Thematic index:** browse ayahs by topic (patience, gratitude, family, etc.)
- **Reading streaks and progress statistics**
- **Subtitles for videos** (Arabic first, then other languages)

### Accessibility and Reach

- **Translations** of the Quran meanings (English and others)
- **Screen reader support** and high-contrast text
- **Multi-language interface**

### Trust and Quality

- **"Report an error" button** on any ayah, tafsir, or video
- **Sources page** listing where the text, tafsir, audio, and video content come from
- **No ads inside the Mushaf screen**
