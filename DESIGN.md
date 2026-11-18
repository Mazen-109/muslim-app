---
name: Muslim (مسلم)
description: A calm, Arabic-first Mushaf reader whose interface stays quiet so the page can lead.
colors:
  light-surface: "#F4F5F6"
  light-surface-container-low: "#EEF0F2"
  light-surface-container: "#E8EBED"
  light-surface-container-highest: "#DDE1E4"
  light-page: "#FFFFFF"
  light-text: "#15171A"
  light-text-secondary: "#40454B"
  light-quran-text: "#111316"
  light-accent: "#22457D"
  light-accent-container: "#D9E2F1"
  light-ayah-highlight: "#E1E8F4"
  light-rule: "#D3D7DB"
  light-outline: "#70767E"
  light-error: "#861B12"
  night-surface: "#121315"
  night-surface-container-low: "#17181B"
  night-surface-container: "#1B1D20"
  night-surface-container-highest: "#26282B"
  night-page: "#17181B"
  night-text: "#E3DFD7"
  night-text-secondary: "#BEBAB2"
  night-quran-text: "#E3DFD7"
  night-accent: "#A8BEE4"
  night-accent-container: "#233452"
  night-ayah-highlight: "#25303F"
  night-rule: "#34373B"
  night-outline: "#8B8E93"
  night-error: "#F0A39A"
  bow-surface: "#FFFFFF"
  bow-surface-container: "#EDEDED"
  bow-page: "#FFFFFF"
  bow-text: "#000000"
  bow-text-secondary: "#3B3B3B"
  bow-accent-container: "#E0E0E0"
  bow-ayah-highlight: "#E6E6E6"
  bow-rule: "#CCCCCC"
  bow-outline: "#6E6E6E"
  wob-surface: "#000000"
  wob-surface-container: "#161616"
  wob-page: "#000000"
  wob-text: "#FFFFFF"
  wob-text-secondary: "#C2C2C2"
  wob-accent-container: "#333333"
  wob-ayah-highlight: "#2A2A2A"
  wob-rule: "#333333"
  wob-outline: "#8C8C8C"
typography:
  display:
    fontFamily: "NotoSansArabic"
    fontSize: "34px"
    fontWeight: 400
    lineHeight: 1.3
    letterSpacing: "0em"
  headline:
    fontFamily: "NotoSansArabic"
    fontSize: "23px"
    fontWeight: 500
    lineHeight: 1.4
    letterSpacing: "0em"
  title:
    fontFamily: "NotoSansArabic"
    fontSize: "21px"
    fontWeight: 600
    lineHeight: 1.45
    letterSpacing: "0em"
  body:
    fontFamily: "NotoSansArabic"
    fontSize: "17px"
    fontWeight: 400
    lineHeight: 1.7
    letterSpacing: "0em"
  label:
    fontFamily: "NotoSansArabic"
    fontSize: "15px"
    fontWeight: 500
    lineHeight: 1.4
    letterSpacing: "0em"
  quran:
    fontFamily: "UthmanicHafs"
    fontSize: "26px"
    fontWeight: 400
    lineHeight: 2.0
    letterSpacing: "0em"
rounded:
  none: "0px"
  sm: "4px"
  md: "8px"
  lg: "16px"
  full: "999px"
spacing:
  xxs: "2px"
  xs: "4px"
  sm: "8px"
  md: "12px"
  lg: "16px"
  xl: "24px"
  xxl: "32px"
  xxxl: "48px"
components:
  button-filled:
    backgroundColor: "{colors.light-accent}"
    textColor: "{colors.light-page}"
    typography: "{typography.label}"
    rounded: "{rounded.md}"
    padding: "0px 24px"
    height: "48px"
  button-outlined:
    textColor: "{colors.light-text}"
    typography: "{typography.label}"
    rounded: "{rounded.md}"
    padding: "0px 24px"
    height: "48px"
  button-text:
    textColor: "{colors.light-accent}"
    typography: "{typography.label}"
    rounded: "{rounded.md}"
    padding: "0px 12px"
    height: "48px"
  list-row:
    backgroundColor: "{colors.light-surface}"
    textColor: "{colors.light-text}"
    typography: "{typography.body}"
    padding: "0px 16px"
    height: "56px"
  navigation-bar:
    backgroundColor: "{colors.light-surface-container-low}"
    textColor: "{colors.light-text-secondary}"
    height: "72px"
  bottom-sheet:
    backgroundColor: "{colors.light-surface-container-low}"
    rounded: "{rounded.lg}"
  chip:
    backgroundColor: "{colors.light-surface}"
    textColor: "{colors.light-text}"
    rounded: "{rounded.sm}"
    height: "48px"
---

# Design System: Muslim (مسلم)

The tokens above are mirrored one to one in `lib/core/theme/` (`app_colors.dart`,
`app_typography.dart`, `app_spacing.dart`, `app_motion.dart`, `app_theme.dart`); the code is
the source of truth and this file describes it. Specimens of all four themes live in
`test/goldens/theme_specimen_*.png`.

## Overview

**Creative North Star: "The Scholar's Edition"**

The world comes from the critical editions of classical Arabic scholarship: a clean text
block on a quiet page, set with wide margins, running heads, hairline rules and marginal
numerals, and a single coloured ink kept for wayfinding. The Mushaf page is the text block.
Everything else (bars, sheets, lists, settings) is apparatus: it is set smaller, quieter and
in one sans-serif voice, so that the only calligraphic hand on screen is the Quran's own.

The system is restrained. Neutral grounds carry a faint cool tint in light and a faint warm
tint at night; one lapis ink marks where the reader is (the selected tab, the current ayah,
a link, the slider's progress). Depth comes from tone and hairlines rather than shadows.
Motion confirms a change and stops. Density is moderate: lists breathe, the page breathes
more.

It deliberately avoids the category's habits: no green-and-gold gradients, no mosque or dome
silhouettes, no arabesque borders or ornamental frames around the chrome, no gilded headers,
and no template card grids. Ornament belongs to the printed Mushaf page itself when the page
view reproduces it, never to the interface around it.

**Key Characteristics:**

- One reading hand (Uthmanic Hafs) for the Quran, one interface voice (Noto Sans Arabic) for
  everything else.
- Restrained colour: tinted neutrals plus one lapis ink; the black and white themes have no
  hue at all.
- Flat and tonal: hairline rules and surface tones instead of shadows.
- Contrast of at least 7:1 for body, secondary and Quran text in every theme.
- Right to left first; 48 dp touch targets everywhere.

## Colors

A cool paper-and-ink palette with a single lapis accent, re-cut for the night and stripped to
pure greys for the two black and white themes.

### Primary

- **Lapis Ink** (light `#22457D`, night `#A8BEE4`): the one accent. Selected states, the
  current position, links, slider and progress fills, the filled button. It never fills a
  region larger than a control.
- **Lapis Wash** (light `#D9E2F1`, night `#233452`): the accent container. The navigation
  indicator, selected chips and segments, text selection.

### Secondary

- **Slate** (light `#3E4752`, night `#BCC3CC`): Material's secondary and tertiary roles,
  deliberately not a second hue, so that any component that reaches for "secondary" stays in
  the ink family.

### Neutral

- **Paper Ground** (light `#F4F5F6`, night `#121315`): the surface behind all chrome.
- **Surface containers** (light `#EEF0F2` to `#DDE1E4`, night `#17181B` to `#26282B`): sheets,
  the navigation bar, menus and pressed areas, lightest to heaviest.
- **The Page** (light `#FFFFFF`, night `#17181B`): the Mushaf page. In light it is the brightest
  sheet on the screen; at night it sits one step above the ground so its edge reads without
  a border.
- **Ink** (light `#15171A`, night `#E3DFD7`): body text and icons. Night ink is a warm grey,
  not white, to keep glare down in a dark room.
- **Faded Ink** (light `#40454B`, night `#BEBAB2`): secondary text: metadata, captions, list
  subtitles, inactive navigation labels.
- **Quran Ink** (light `#111316`, night `#E3DFD7`): Quran text on the page.
- **Ayah Wash** (light `#E1E8F4`, night `#25303F`): behind the ayah being recited or selected.
- **Rule** (light `#D3D7DB`, night `#34373B`): hairline rules.
- **Outline** (light `#70767E`, night `#8B8E93`): input borders, outlined buttons, the drag
  handle.
- **Error** (light `#861B12`, night `#F0A39A`): error text and borders only.

### Black on white and white on black

Every role maps to black, white or a grey: ink `#000000` on `#FFFFFF`, or `#FFFFFF` on true
black `#000000` for OLED screens. The accent becomes the ink itself, its container a light or
dark grey, and error is shown by wording and icon rather than colour. Secondary text is
`#3B3B3B` and `#C2C2C2`. The test suite walks every colour in these two themes and fails on
any channel difference.

### Named Rules

**The One Ink Rule.** Lapis is the only hue in the interface. A new colour needs a new role in
`AppPalette` and a reason; it is never a literal in a widget.

**The Seven to One Rule.** Body text, secondary text and Quran text stay at or above 7:1
against every surface they can sit on, in every theme. The check is a test, not a review step.

**The Grey Means Grey Rule.** In the black and white themes, no role carries a hue: not the
accent, not error, not a splash or a focus ring. Videos are the only exception, and that is
the reader's setting, not the theme's.

## Typography

**Interface Font:** Noto Sans Arabic (variable, `wght` 100 to 900), with its Latin for English
labels and numerals.
**Quran Font:** KFGQPC Uthmanic Script Hafs (`UthmanicHafs`), with no fallback.

**Character:** a plain, open Arabic sans that reads well small and never imitates calligraphy,
set against the Mushaf's own naskh. The contrast between the two is the hierarchy: the
interface never competes with the text.

### Hierarchy

Sizes are logical pixels and scale with the reader's text size setting (0.8 to 2.0).
Line heights are looser than Material's because Arabic needs room above and below for dots
and marks.

- **Display** (400, 48 / 40 / 34, line height 1.25 to 1.3): rare; large numerals such as a
  page number in the go-to dialog.
- **Headline** (500, 30 / 26 / 23, 1.35 to 1.4): screen titles in large app bars, a surah
  name on its index card.
- **Title** (600, 21 / 17 / 15, 1.45 to 1.5): app bar titles, sheet titles, list section
  heads.
- **Body** (400, 17 / 15 / 13, 1.6 to 1.7): running interface text, tafsir body, list rows.
  Body small is set in Faded Ink. Running text never exceeds a 600 dp measure.
- **Label** (500, 15 / 13 / 12, 1.4): buttons, navigation labels, chips, metadata. Label
  small is set in Faded Ink.
- **Quran** (400, 26 by default, line height 2.0): continuous view only; the page view
  computes one size per page so the printed lines fit.

### Named Rules

**The One Hand Rule.** The Uthmanic font is used for Quran text and nothing else, and Quran
text is set in nothing else. Its fallback list is empty: a missing glyph is an error state,
never a substitute font.

**The No-Tracking Rule.** Letter spacing is zero in every style. Tracking pulls joined Arabic
letters apart.

**The Variable Weight Rule.** Every interface style sets both `fontWeight` and the matching
`wght` font variation, so weights render from the variable font instead of being synthesised.

## Layout

A single reading column, right to left. Screens have a 16 dp side gutter. Spacing follows a
4 dp grid: 2, 4, 8, 12, 16, 24, 32 and 48. Related items sit 8 dp apart, groups 24 dp apart,
and a heading has more space above it than below it.

Running text (tafsir, sources, settings help) is capped at a 600 dp measure and centred on
wide screens. Bottom sheets share that cap. The Mushaf page fills the width on phones and keeps
the printed page's proportions on tablets, with the ground showing as margin.

On compact widths the four destinations sit in a 72 dp navigation bar; on expanded widths
they move to a navigation rail. On the Mushaf screen, chrome hides until the reader taps.

## Elevation & Depth

Flat by default. Depth is shown by surface tone (ground, then container steps) and 1 dp
rules, never by decorative shadow. Only surfaces that float over the page are raised: menus
at 3 dp, bottom sheets and dialogs at 6 dp, with a 32 % black scrim behind modal surfaces.
App bars and the navigation bar stay at 0, including when content scrolls under them, and
Material's surface tint is switched off so tone never shifts with elevation.

Levels: `level0` 0, `level1` 1, `level2` 3, `level3` 6 (dp).

### Named Rules

**The Hairline Rule.** Where two regions meet, a 1 dp rule or a tone step separates them,
not a shadow and not a thick border. No coloured side borders on rows or cards.

## Shapes

Mostly square with softened corners, like trimmed paper. Chips, inputs, snackbars and tooltips
use 4 dp; buttons and menus 8 dp; bottom sheets (top corners) and dialogs 16 dp. Full
rounding is kept for genuinely circular controls (the play button) and the navigation
indicator's pill. The Mushaf page itself has square corners.

## Components

### Buttons

- **Shape:** gently rounded (8 dp), at least 48 dp tall; tap targets padded to 48 by 48 dp.
- **Filled:** Lapis Ink background, white (or ground) text, label style, 24 dp side padding.
  One per screen at most: the action that moves the reader forward.
- **Outlined:** 1 dp Outline border, Ink text. The neutral choice beside a filled button.
- **Text:** Lapis Ink text, 12 dp padding, minimum 48 by 48 dp. Secondary actions and links.
- **Icon buttons:** 48 by 48 dp minimum, 24 dp icons in Ink; every one has a screen reader
  label.
- **States:** press, hover and focus are ink overlays at 8 to 12 % opacity with a plain ripple
  (no sparkle); disabled is ink at 38 % on a 12 % fill.

### Chips

- **Style:** 4 dp corners, 1 dp light outline, Ground fill, label style in Ink.
- **Selected:** Lapis Wash fill with its dark ink; no shadow.

### Lists

- **Rows:** at least 56 dp tall, 16 dp gutter, title in body large, subtitle in Faded Ink,
  trailing metadata in label medium. Rows are separated by hairline rules, not cards.
- **Selected:** Lapis Wash background.

### Inputs / Fields

- **Style:** unfilled, 4 dp corners, 1 dp Outline border.
- **Focus:** the border becomes 2 dp Lapis Ink.
- **Error:** the border and helper text take the error role.

### Navigation

- **Bar:** 72 dp, container-low background, no elevation, labels always shown. The selected
  destination gets a Lapis Wash pill behind its icon and an Ink label; others are Faded Ink.
- **App bar:** ground background, title style, start-aligned (right in Arabic), no shadow
  and no tint when content scrolls under it.

### Sheets and dialogs

- **Bottom sheet:** container-low, 16 dp top corners, visible drag handle in Outline, capped
  at the 600 dp measure. The tafsir sheet and the ayah menu use it.
- **Dialog:** container-low, 16 dp corners, title style heading. Only for decisions that must
  interrupt.
- **Snackbar:** inverse surface, floating, 4 dp corners, action in the inverse accent.

### Mushaf page (signature component)

The page sits on its own Page colour, edge to edge on a phone. A running head (surah name at
the start, juz at the end) is set in label small, Faded Ink, above a hairline Rule; the page
number sits centred below the text block in the same style. The ayah being recited or
selected gets the Ayah Wash behind its words; nothing else on the page is coloured. Chrome
(app bar, audio bar) appears over the ground only when the reader taps, and fades in and out.

### Motion

Durations: 150 ms for control state changes, 250 ms for small layout changes, 350 ms for
surfaces entering, 300 ms for an animated page turn. Curves: ease-out cubic for entering and
state changes, ease-in cubic for leaving. When the platform asks for reduced motion,
`AppMotion.resolve` returns zero and changes cut instead of animating. No looping or
decorative animation anywhere, and none on the Mushaf page beyond the page turn and the
highlight moving with the recitation.

## Do's and Don'ts

### Do:

- **Do** read every colour from `Theme.of(context).colorScheme` or `AppColors.of(context)`,
  every size from `AppSpacing`, `AppSizes`, `AppRadii` and `AppElevation`, and every duration
  through `AppMotion.resolve`.
- **Do** set Quran text with `AppTheme.quranTextStyle(theme)` (UthmanicHafs, empty fallback
  list) and nothing else.
- **Do** keep body, secondary and Quran text at 7:1 or more; add a surface only after adding
  it to the contrast test.
- **Do** separate regions with a 1 dp Rule or a tone step.
- **Do** check every new screen in all four themes and in right-to-left before review, with
  a golden image.
- **Do** use neutral interface labels in specimens, goldens and mock-ups.

### Don't:

- **Don't** use green-and-gold gradients, mosque or dome silhouettes, arabesque frames,
  gilded headers or ornamental borders anywhere in the interface.
- **Don't** add a second accent hue, or any hue at all in the black and white themes.
- **Don't** use the Uthmanic font for interface text, or any other font for Quran text.
- **Don't** set letter spacing on Arabic text.
- **Don't** use drop shadows on rows, cards or bars, or coloured side borders thicker than
  1 dp.
- **Don't** put Quran text, tafsir, hadith or story content into specimens, placeholders or
  sample copy, and never depict a prophet in any image.
- **Don't** put anything on the Mushaf page that is not the page: no banners, promotions or
  badges.
