# Product

<!-- impeccable:product-schema 1 -->

> Written without a live interview: the project owner was away, so every fact below is taken
> from `docs/concept.md`, `specs/001-muslim-mvp/spec.md` and
> `.specify/memory/constitution.md`. Lines marked *(inferred)* are reasonable readings of those
> documents that the owner has not confirmed.

## Platform

android

One Flutter codebase with Material widgets (`package:material_ui`). Android is the first
release target; the same build also ships to iOS, where it still owes iPhone its OS guarantees
(safe areas, Reduce Motion, edge-swipe back).

## Users

Arabic-speaking Muslims who read the Quran on their phone, often daily, often for a set
portion (a wird), and often while memorising. They read in many scenes: in the morning before
work, in the mosque between prayers, on a commute, and at night in a dark room beside someone
asleep *(inferred from the night and white-on-black themes)*. Some are learning correct
pronunciation and want to hear one ayah again and again. English speakers are a second
audience through the English interface.

## Product Purpose

Muslim (مسلم) puts the Mushaf, its recitation, one tafsir and short story videos in one app,
and links them: from a page the reader can hear an ayah, read its tafsir, or open the story of
the surah, and from a video the reader can go back to the ayahs it covers. Success is a reader
who opens the app, lands on the ayah they left, and reads without anything getting in the way.

## Positioning

The linking: every piece of content is tied to the Quran text by ayah key, so reading,
listening, understanding and watching are one path instead of four apps. Underneath it is
trust: the text is imported, never typed, every source is listed with its licence, no prophet
is depicted, and nothing is published without specialist review.

## Operating Context

- The reading session is the core ritual: open, resume at the last ayah, read a page or a
  portion, sometimes listen along, sometimes stop on an ayah to read its tafsir.
- Memorisation: repeating one ayah's audio, marking ayahs, reading the printed-page layout the
  reader memorised from (604 Madani pages, turned right to left).
- Reading happens in bright daylight and in the dark; the reader chooses one of four themes:
  light, night, black on white, white on black.
- Fully offline for text, tafsir, search, bookmarks and themes. Audio and video stream.

## Capabilities and Constraints

- MVP scope: Mushaf page view and continuous view, surah and juz index, search, one tafsir
  (Al-Muyassar), per-ayah recitation with repeat, bookmarks and memorisation marks, auto-scroll,
  story videos from a reviewed catalog, a Sources page, an error report, Arabic and English.
- Quran text is data from `assets/data/quran.db` and is rendered only in the KFGQPC Uthmanic
  Hafs font, with no fallback; a missing font is an error state.
- No accounts, no backend, no analytics, no ads; nothing interrupts the Mushaf screen.
- Terminology: Mushaf, surah, ayah, juz, hizb, tafsir, reciter, wird. Ayahs are referred to by
  key (`2:255`), never by quoted text.

## Brand Commitments

- Name: Muslim, written مسلم in Arabic.
- Arabic first and right to left; English second.
- Calm and reading-centred: the Mushaf page is the hero and the chrome around it stays quiet.
- No depiction of any prophet in any asset, in any form.
- The owner's brief rules out generic Islamic-app clichés: green-and-gold gradients, mosque
  silhouettes, ornamental overload and template looks.

## Evidence on Hand

- The Quran font (`assets/fonts/UthmanicHafs1Ver18.ttf`) and the sources registry
  (`assets/sources.json`).
- No logo, photography, illustration, testimonials or press exist yet. Never fabricate them,
  and never write Quran text, tafsir, hadith or story content as sample copy: specimens and
  mock-ups use neutral interface labels only.

## Product Principles

1. The text comes first. Nothing on screen competes with the Mushaf page while the reader is
   reading.
2. Trust is visible. Sources, attributions and review status are part of the product, not
   fine print.
3. Everything links back to the ayah. Any surface that is about the Quran offers the way back
   to the text.
4. Calm over clever. Familiar platform patterns, few states, no gamified pressure.
5. Works for every reader, in every light: contrast, size and touch targets are requirements,
   not polish.

## Accessibility & Inclusion

- Every theme keeps body text, secondary text and Quran text at a contrast ratio of at least
  7:1 (WCAG AAA).
- Touch targets of at least 48 by 48 dp, and a screen reader label on every control.
- Text outside the fixed Mushaf page respects the reader's font size setting (0.8 to 2.0).
- Every screen works right to left.
- The two black and white themes are fully achromatic; white on black uses a true black
  background for OLED screens.
