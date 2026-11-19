import 'dart:collection';

import 'package:material_ui/material_ui.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/mushaf_page.dart';
import '../../../data/models/surah.dart';
import '../../bookmarks/ayah_indicators.dart';
import 'page_line_widgets.dart';

/// The fixed geometry of a Mushaf text block, in reference units (research
/// R5). The block is laid out once at [referenceFontSize] and then scaled
/// as a unit to the space on screen, so the font size on screen is
/// `referenceFontSize` times the page's scale: one size per page.
abstract final class MushafGeometry {
  /// The font size the block is laid out at before scaling.
  static const double referenceFontSize = 20;

  /// The height of a line slot, in ems of the Quran font.
  static const double slotEm = 1.8;

  /// The height of a line slot in reference units.
  static const double slotHeight = referenceFontSize * slotEm;

  /// Line slots of a full page. Pages 1 and 2 have 8 lines, set as a
  /// centred group in the same 15-slot block so their text matches the size
  /// of the other pages.
  static const int slots = 15;

  /// A line whose natural width is below this share of the block width is
  /// centred rather than justified (the short last line of a surah).
  static const double centreBelow = 0.75;

  /// Room added to the widest line so that no line, as measured word by
  /// word, overruns the block.
  static const double widthSlack = 1.01;

  /// The surah name in the banner, in ems of the Quran font.
  static const double bannerEm = 0.85;
}

/// The surah and juz shown in a page's running head.
@immutable
class MushafPageHeading {
  const MushafPageHeading({required this.surah, required this.juz});

  /// The surah of the first word on the page.
  final Surah surah;

  /// The juz of the first word on the page.
  final int juz;

  @override
  bool operator ==(Object other) =>
      other is MushafPageHeading && other.surah == surah && other.juz == juz;

  @override
  int get hashCode => Object.hash(surah, juz);
}

/// The measured width of a page's text block in reference units.
///
/// The width is the widest ayah or basmala line at its natural spacing; the
/// other lines are justified to it or centred within it. Measuring takes one
/// text layout per line and is cached for recently shown pages.
@immutable
class MushafPageLayout {
  const MushafPageLayout._({
    required this.blockWidth,
    required this.spaceWidth,
  });

  /// The text block's width in reference units.
  final double blockWidth;

  /// The natural space between two words in reference units.
  final double spaceWidth;

  /// The text block's height in reference units.
  double get blockHeight => MushafGeometry.slots * MushafGeometry.slotHeight;

  static const int _cacheSize = 16;
  static final LinkedHashMap<int, MushafPageLayout> _cache =
      LinkedHashMap<int, MushafPageLayout>();

  /// The layout of [page] with [quranStyle] at the reference size. Only the
  /// font matters to the measurement, so the cache is keyed by page number.
  static MushafPageLayout of(MushafPage page, TextStyle quranStyle) {
    final cached = _cache.remove(page.number);
    if (cached != null) {
      _cache[page.number] = cached;
      return cached;
    }
    final layout = measure(page, quranStyle);
    _cache[page.number] = layout;
    if (_cache.length > _cacheSize) _cache.remove(_cache.keys.first);
    return layout;
  }

  /// Measures [page] without the cache.
  static MushafPageLayout measure(MushafPage page, TextStyle quranStyle) {
    final painter = TextPainter(
      textDirection: TextDirection.rtl,
      textScaler: TextScaler.noScaling,
      maxLines: 1,
    );
    double widthOf(String text) {
      painter
        ..text = TextSpan(text: text, style: quranStyle)
        ..layout();
      return painter.maxIntrinsicWidth;
    }

    final space = widthOf(' ');
    var widest = 0.0;
    for (final line in page.lines) {
      final words = switch (line) {
        AyahLine(:final words) => words,
        BasmalaLine(:final words) => words,
        SurahNameLine() => null,
      };
      if (words == null) continue;
      final width = widthOf(words.map((w) => w.textQpcHafs).join(' '));
      if (width > widest) widest = width;
    }
    painter.dispose();
    return MushafPageLayout._(
      blockWidth: widest * MushafGeometry.widthSlack,
      spaceWidth: space,
    );
  }

  /// The Quran style of the page view at the reference size: the Uthmanic
  /// Hafs family with no fallback, one slot high, glyphs centred in it.
  static TextStyle quranStyle(ThemeData theme) =>
      AppTheme.quranTextStyle(theme).copyWith(
        fontSize: MushafGeometry.referenceFontSize,
        height: MushafGeometry.slotEm,
        leadingDistribution: TextLeadingDistribution.even,
      );
}

/// One Mushaf page (research R5, DESIGN.md "Mushaf page"): a running head
/// with the surah name and the juz above a hairline rule, the text block of
/// 15 (or 8) line slots scaled as a unit to fit, and the page number below.
class MushafPageWidget extends StatelessWidget {
  const MushafPageWidget({
    super.key,
    required this.page,
    required this.heading,
    this.highlightedAyahId,
    this.marks = AyahMarkSets.none,
    this.onAyahTap,
    this.onAyahLongPress,
  });

  final MushafPage page;
  final MushafPageHeading heading;
  final int? highlightedAyahId;

  /// The ayahs whose end markers carry indicators.
  final AyahMarkSets marks;

  final AyahCallback? onAyahTap;
  final AyahCallback? onAyahLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final quranStyle = MushafPageLayout.quranStyle(theme);
    final layout = MushafPageLayout.of(page, quranStyle);

    return ColoredBox(
      color: colors.page,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          AppSpacing.sm,
          AppSpacing.gutter,
          AppSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _RunningHead(heading: heading),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: FittedBox(
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: _TextBlock(
                    page: page,
                    layout: layout,
                    quranStyle: quranStyle,
                    bannerStyle: theme.textTheme.titleMedium!.copyWith(
                      color: colors.quranText,
                      fontSize:
                          MushafGeometry.referenceFontSize *
                          MushafGeometry.bannerEm,
                      height: 1,
                    ),
                    highlightedAyahId: highlightedAyahId,
                    marks: marks,
                    onAyahTap: onAyahTap,
                    onAyahLongPress: onAyahLongPress,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _PageNumber(number: page.number),
          ],
        ),
      ),
    );
  }
}

class _TextBlock extends StatelessWidget {
  const _TextBlock({
    required this.page,
    required this.layout,
    required this.quranStyle,
    required this.bannerStyle,
    this.highlightedAyahId,
    this.marks = AyahMarkSets.none,
    this.onAyahTap,
    this.onAyahLongPress,
  });

  final MushafPage page;
  final MushafPageLayout layout;
  final TextStyle quranStyle;
  final TextStyle bannerStyle;
  final int? highlightedAyahId;

  /// The ayahs whose end markers carry indicators.
  final AyahMarkSets marks;

  final AyahCallback? onAyahTap;
  final AyahCallback? onAyahLongPress;

  @override
  Widget build(BuildContext context) {
    const slot = MushafGeometry.slotHeight;
    final centredPage = page.lines.length < MushafGeometry.slots;
    return SizedBox(
      width: layout.blockWidth,
      height: layout.blockHeight,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          for (final line in page.lines)
            SizedBox(
              key: MushafLineKey(page.number, line.number),
              width: layout.blockWidth,
              height: slot,
              child: switch (line) {
                AyahLine(:final words) => AyahLineWidget(
                  words: words,
                  style: quranStyle,
                  slotHeight: slot,
                  spaceWidth: layout.spaceWidth,
                  centreBelow: MushafGeometry.centreBelow,
                  forceCentred: centredPage,
                  highlightedAyahId: highlightedAyahId,
                  marks: marks,
                  onAyahTap: onAyahTap,
                  onAyahLongPress: onAyahLongPress,
                ),
                BasmalaLine(:final words) => BasmalaLineWidget(
                  words: words,
                  style: quranStyle,
                  slotHeight: slot,
                  spaceWidth: layout.spaceWidth,
                ),
                SurahNameLine(:final surah) => SurahBannerLine(
                  surah: surah,
                  style: bannerStyle,
                  slotHeight: slot,
                ),
              },
            ),
        ],
      ),
    );
  }
}

/// Surah name at the start, juz at the end, in label small and Faded Ink,
/// over a hairline rule.
class _RunningHead extends StatelessWidget {
  const _RunningHead({required this.heading});

  final MushafPageHeading heading;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final style = Theme.of(context).textTheme.labelSmall;
    final surah = heading.surah;
    final name = Localizations.localeOf(context).languageCode == 'ar'
        ? surah.nameAr
        : surah.nameEn;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                name,
                style: style,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                semanticsLabel: l10n.mushafHeadSurah(name),
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Text(l10n.mushafHeadJuz(heading.juz), style: style, maxLines: 1),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Container(height: AppSizes.hairline, color: AppColors.of(context).rule),
      ],
    );
  }
}

class _PageNumber extends StatelessWidget {
  const _PageNumber({required this.number});

  final int number;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$number',
      style: Theme.of(context).textTheme.labelSmall,
      textAlign: TextAlign.center,
      maxLines: 1,
      semanticsLabel: AppLocalizations.of(context).mushafPageNumber(number),
    );
  }
}
