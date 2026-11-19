import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../data/models/surah.dart';
import '../../../data/models/word.dart';
import '../../bookmarks/ayah_indicators.dart';

/// Called with the id of the ayah a word belongs to.
typedef AyahCallback = void Function(int ayahId);

/// The key of the widget that draws word [value] (its `words.id`). Tests
/// find words by it.
class MushafWordKey extends ValueKey<int> {
  const MushafWordKey(super.value);
}

/// The key of line slot [line] of page [page].
class MushafLineKey extends ValueKey<(int, int)> {
  const MushafLineKey(int page, int line) : super((page, line));
}

/// How a line of words is set inside its slot.
enum LineSetting {
  /// Spread to the full width of the text block, with the extra space shared
  /// equally between the words.
  justified,

  /// At its natural width, centred: the short last line of a surah, the
  /// basmala, and every line of pages 1 and 2 (research R5).
  centred,
}

/// One line of ayah text. Each word is its own hit target and reports its
/// ayah id on tap and long press. The words of [highlightedAyahId] sit on
/// one continuous wash that also covers the space between them. An ayah
/// whose end marker is on this line and that the reader bookmarked or
/// memorised ([marks]) gets its [AyahIndicators] above the marker.
///
/// The line is laid out in the page's reference units: [style] carries the
/// reference font size, [slotHeight] the height of a line slot. The page
/// scales the whole text block as a unit.
class AyahLineWidget extends StatelessWidget {
  const AyahLineWidget({
    super.key,
    required this.words,
    required this.style,
    required this.slotHeight,
    required this.spaceWidth,
    required this.centreBelow,
    this.forceCentred = false,
    this.highlightedAyahId,
    this.marks = AyahMarkSets.none,
    this.onAyahTap,
    this.onAyahLongPress,
  });

  final List<Word> words;
  final TextStyle style;
  final double slotHeight;

  /// The natural space between two words, in reference units.
  final double spaceWidth;

  /// A line whose natural width is below this fraction of the block width
  /// is centred instead of justified.
  final double centreBelow;

  /// Centre the line whatever its width (pages 1 and 2).
  final bool forceCentred;

  final int? highlightedAyahId;

  /// The ayahs that carry a bookmark or a memorised mark.
  final AyahMarkSets marks;

  final AyahCallback? onAyahTap;
  final AyahCallback? onAyahLongPress;

  @override
  Widget build(BuildContext context) {
    final highlight = highlightedAyahId;
    final marked = <int>[
      for (var i = 0; i < words.length; i++)
        if (words[i].charType == WordCharType.end &&
            marks.marks(words[i].ayahId))
          i,
    ];
    final highlighted = <int>[
      for (var i = 0; i < words.length; i++)
        if (highlight != null && words[i].ayahId == highlight) i,
    ];
    return CustomMultiChildLayout(
      delegate: _LineDelegate(
        wordCount: words.length,
        highlighted: highlighted.isEmpty
            ? null
            : (highlighted.first, highlighted.last),
        marked: marked,
        slotHeight: slotHeight,
        spaceWidth: spaceWidth,
        centreBelow: centreBelow,
        forceCentred: forceCentred,
      ),
      children: <Widget>[
        if (highlighted.isNotEmpty)
          LayoutId(
            id: _highlightId,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.of(context).ayahHighlight,
                borderRadius: AppRadii.smAll,
              ),
            ),
          ),
        // Before the words, so that a mark never paints over the text.
        for (final i in marked)
          LayoutId(
            id: _MarkId(i),
            child: AyahIndicators(
              key: AyahIndicatorKey(words[i].ayahId),
              ayahId: words[i].ayahId,
              bookmarked: marks.bookmarked.contains(words[i].ayahId),
              memorised: marks.memorised.contains(words[i].ayahId),
              size: style.fontSize! * AyahIndicators.sizeEm,
            ),
          ),
        for (var i = 0; i < words.length; i++)
          LayoutId(
            id: i,
            child: _WordTarget(
              key: MushafWordKey(words[i].id),
              word: words[i],
              style: style,
              onTap: onAyahTap,
              onLongPress: onAyahLongPress,
            ),
          ),
      ],
    );
  }
}

/// The basmala line: the words the repository gives for it, centred. It
/// belongs to no ayah of the surah it opens, so it reports no taps.
class BasmalaLineWidget extends StatelessWidget {
  const BasmalaLineWidget({
    super.key,
    required this.words,
    required this.style,
    required this.slotHeight,
    required this.spaceWidth,
  });

  final List<Word> words;
  final TextStyle style;
  final double slotHeight;
  final double spaceWidth;

  @override
  Widget build(BuildContext context) {
    return CustomMultiChildLayout(
      delegate: _LineDelegate(
        wordCount: words.length,
        slotHeight: slotHeight,
        spaceWidth: spaceWidth,
        centreBelow: 1,
        forceCentred: true,
      ),
      children: <Widget>[
        for (var i = 0; i < words.length; i++)
          LayoutId(
            id: i,
            child: _WordText(word: words[i], style: style),
          ),
      ],
    );
  }
}

/// The surah name banner: the name from the database, centred in a
/// hairline frame the width of the text block. The name is interface text
/// from the `surahs` table, not Quran text, so it is set in the interface
/// face (DESIGN.md, The One Hand Rule).
class SurahBannerLine extends StatelessWidget {
  const SurahBannerLine({
    super.key,
    required this.surah,
    required this.style,
    required this.slotHeight,
  });

  final Surah surah;
  final TextStyle style;
  final double slotHeight;

  /// The frame's height as a share of the slot.
  static const double frameShare = 0.78;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Center(
      child: SizedBox(
        height: slotHeight * frameShare,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: colors.rule, width: AppSizes.hairline),
          ),
          child: Center(
            child: Text(
              surah.nameAr,
              style: style,
              textDirection: TextDirection.rtl,
              textScaler: TextScaler.noScaling,
              maxLines: 1,
              softWrap: false,
            ),
          ),
        ),
      ),
    );
  }
}

class _WordText extends StatelessWidget {
  const _WordText({required this.word, required this.style});

  final Word word;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Text(
      word.textQpcHafs,
      style: style,
      textDirection: TextDirection.rtl,
      textScaler: TextScaler.noScaling,
      maxLines: 1,
      softWrap: false,
    );
  }
}

class _WordTarget extends StatelessWidget {
  const _WordTarget({
    super.key,
    required this.word,
    required this.style,
    this.onTap,
    this.onLongPress,
  });

  final Word word;
  final TextStyle style;
  final AyahCallback? onTap;
  final AyahCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final tap = onTap;
    final longPress = onLongPress;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: tap == null ? null : () => tap(word.ayahId),
      onLongPress: longPress == null ? null : () => longPress(word.ayahId),
      child: _WordText(word: word, style: style),
    );
  }
}

const Object _highlightId = #highlight;

/// The layout id of the indicators above the end marker at word index
/// [index].
@immutable
class _MarkId {
  const _MarkId(this.index);

  final int index;

  @override
  bool operator ==(Object other) => other is _MarkId && other.index == index;

  @override
  int get hashCode => index.hashCode;
}

/// Places the words of one line right to left inside the line's slot.
///
/// Every word is laid out at the slot height. A justified line shares the
/// remaining width equally between its gaps; a centred line uses the
/// natural space. Each word's hit area is its box, the full slot high. The
/// highlight wash spans the highlighted words and the gaps between them.
/// The indicators of a marked end marker are centred over it, at the top of
/// the slot.
class _LineDelegate extends MultiChildLayoutDelegate {
  _LineDelegate({
    required this.wordCount,
    this.marked = const <int>[],
    required this.slotHeight,
    required this.spaceWidth,
    required this.centreBelow,
    required this.forceCentred,
    this.highlighted,
  });

  final int wordCount;
  final double slotHeight;
  final double spaceWidth;
  final double centreBelow;
  final bool forceCentred;

  /// The first and last index of the highlighted words, or null.
  final (int, int)? highlighted;

  /// The indexes of the end markers that carry indicators.
  final List<int> marked;

  @override
  void performLayout(Size size) {
    final widths = <double>[];
    var inked = 0.0;
    for (var i = 0; i < wordCount; i++) {
      final s = layoutChild(i, BoxConstraints.tightFor(height: slotHeight));
      widths.add(s.width);
      inked += s.width;
    }
    final gaps = wordCount - 1;
    final natural = inked + gaps * spaceWidth;
    final justify =
        !forceCentred && gaps > 0 && natural >= size.width * centreBelow;

    final double gap;
    final double start;
    if (justify) {
      gap = ((size.width - inked) / gaps).clamp(0, double.infinity);
      start = 0;
    } else {
      gap = spaceWidth;
      start = ((size.width - natural) / 2).clamp(0, double.infinity);
    }

    final top = (size.height - slotHeight) / 2;
    final lefts = List<double>.filled(wordCount, 0);
    var right = size.width - start;
    for (var i = 0; i < wordCount; i++) {
      lefts[i] = right - widths[i];
      positionChild(i, Offset(lefts[i], top));
      right = lefts[i] - gap;
    }

    if (highlighted case (final first, final last)) {
      final hlRight = lefts[first] + widths[first];
      final hlLeft = lefts[last];
      layoutChild(
        _highlightId,
        BoxConstraints.tight(Size(hlRight - hlLeft, slotHeight)),
      );
      positionChild(_highlightId, Offset(hlLeft, top));
    }

    for (final i in marked) {
      final mark = layoutChild(_MarkId(i), BoxConstraints.loose(size));
      positionChild(
        _MarkId(i),
        Offset(lefts[i] + (widths[i] - mark.width) / 2, top),
      );
    }
  }

  @override
  bool shouldRelayout(_LineDelegate old) =>
      old.wordCount != wordCount ||
      old.slotHeight != slotHeight ||
      old.spaceWidth != spaceWidth ||
      old.centreBelow != centreBelow ||
      old.forceCentred != forceCentred ||
      old.highlighted != highlighted ||
      !listEquals(old.marked, marked);
}
