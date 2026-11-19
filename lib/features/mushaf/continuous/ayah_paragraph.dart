import 'dart:ui' show BoxHeightStyle;

import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../data/models/ayah.dart';
import '../page_view/page_line_widgets.dart';

/// The key of the paragraph whose first ayah is [value]. Tests find
/// paragraphs by it.
class AyahParagraphKey extends ValueKey<int> {
  const AyahParagraphKey(super.value);
}

/// Ayahs set as one justified, right-to-left paragraph of flowing text.
///
/// Each ayah is its stored display text, unchanged, end marker included;
/// one space separates two ayahs. A tap or long press anywhere on the text
/// reports the id of the ayah under it, as the page view's words do, and
/// [highlightedAyahId] is drawn on the ayah wash behind its lines.
///
/// [AyahParagraphState.ayahTops] tells the continuous view where each ayah
/// starts, which is how it keeps the current ayah on screen.
class AyahParagraph extends StatefulWidget {
  const AyahParagraph({
    super.key,
    required this.ayahs,
    required this.style,
    this.highlightedAyahId,
    this.onAyahTap,
    this.onAyahLongPress,
  });

  final List<Ayah> ayahs;

  /// The Quran style at the view's font size.
  final TextStyle style;

  final int? highlightedAyahId;
  final AyahCallback? onAyahTap;
  final AyahCallback? onAyahLongPress;

  @override
  State<AyahParagraph> createState() => AyahParagraphState();
}

class AyahParagraphState extends State<AyahParagraph> {
  final GlobalKey _textKey = GlobalKey();

  /// The offset in the paragraph's text where each ayah starts.
  late List<int> _starts;

  /// The tops of each ayah's first line, for the layout they were read from.
  List<double>? _tops;
  Size? _topsSize;

  @override
  void initState() {
    super.initState();
    _starts = _startsOf(widget.ayahs);
  }

  @override
  void didUpdateWidget(AyahParagraph oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.ayahs, widget.ayahs)) {
      _starts = _startsOf(widget.ayahs);
    }
    _tops = null;
  }

  static List<int> _startsOf(List<Ayah> ayahs) {
    final starts = <int>[];
    var offset = 0;
    for (final ayah in ayahs) {
      starts.add(offset);
      offset += ayah.textQpcHafs.length + _separator.length;
    }
    return starts;
  }

  static const String _separator = ' ';

  RenderParagraph? get _paragraph {
    final object = _textKey.currentContext?.findRenderObject();
    return object is RenderParagraph && object.hasSize ? object : null;
  }

  TextSelection _rangeOf(int index) => TextSelection(
    baseOffset: _starts[index],
    extentOffset: _starts[index] + widget.ayahs[index].textQpcHafs.length,
  );

  int _ayahAtOffset(int offset) {
    for (var i = _starts.length - 1; i > 0; i--) {
      if (_starts[i] <= offset) return widget.ayahs[i].id;
    }
    return widget.ayahs.first.id;
  }

  int? _ayahAt(Offset globalPosition) {
    final paragraph = _paragraph;
    if (paragraph == null) return null;
    final local = paragraph.globalToLocal(globalPosition);
    return _ayahAtOffset(paragraph.getPositionForOffset(local).offset);
  }

  /// Each ayah's id with the top of its first line in [ancestor]'s
  /// coordinates, in reading order; empty before the first layout.
  List<(int, double)> ayahTops(RenderObject ancestor) {
    final paragraph = _paragraph;
    if (paragraph == null || !paragraph.attached) return const [];
    if (_tops == null || _topsSize != paragraph.size) {
      _tops = <double>[
        for (var i = 0; i < widget.ayahs.length; i++)
          _boxes(paragraph, i).fold<double>(
            double.infinity,
            (top, box) => box.top < top ? box.top : top,
          ),
      ];
      _topsSize = paragraph.size;
    }
    final origin = paragraph.localToGlobal(Offset.zero, ancestor: ancestor);
    return <(int, double)>[
      for (var i = 0; i < widget.ayahs.length; i++)
        (widget.ayahs[i].id, origin.dy + _tops![i]),
    ];
  }

  List<TextBox> _boxes(RenderParagraph paragraph, int index) =>
      paragraph.getBoxesForSelection(
        _rangeOf(index),
        boxHeightStyle: BoxHeightStyle.max,
      );

  @override
  Widget build(BuildContext context) {
    final highlight = widget.highlightedAyahId;
    final highlightIndex = highlight == null
        ? -1
        : widget.ayahs.indexWhere((a) => a.id == highlight);
    final tap = widget.onAyahTap;
    final longPress = widget.onAyahLongPress;

    final text = RichText(
      key: _textKey,
      textAlign: TextAlign.justify,
      textDirection: TextDirection.rtl,
      textScaler: MediaQuery.textScalerOf(context),
      text: TextSpan(
        style: widget.style,
        children: <InlineSpan>[
          for (var i = 0; i < widget.ayahs.length; i++) ...<InlineSpan>[
            TextSpan(text: widget.ayahs[i].textQpcHafs),
            const TextSpan(text: _separator),
          ],
        ],
      ),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: tap == null
          ? null
          : (details) {
              final id = _ayahAt(details.globalPosition);
              if (id != null) tap(id);
            },
      onLongPressStart: longPress == null
          ? null
          : (details) {
              final id = _ayahAt(details.globalPosition);
              if (id != null) longPress(id);
            },
      child: highlightIndex < 0
          ? text
          : Stack(
              children: <Widget>[
                Positioned.fill(
                  child: CustomPaint(
                    painter: _HighlightPainter(
                      boxes: () {
                        final paragraph = _paragraph;
                        return paragraph == null
                            ? const <TextBox>[]
                            : _boxes(paragraph, highlightIndex);
                      },
                      ayahId: highlight!,
                      style: widget.style,
                      color: AppColors.of(context).ayahHighlight,
                    ),
                  ),
                ),
                text,
              ],
            ),
    );
  }
}

/// Draws the ayah wash behind the lines of one ayah. The boxes are read at
/// paint time, after the text has been laid out.
class _HighlightPainter extends CustomPainter {
  _HighlightPainter({
    required this.boxes,
    required this.ayahId,
    required this.style,
    required this.color,
  });

  final List<TextBox> Function() boxes;
  final int ayahId;
  final TextStyle style;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (final box in boxes()) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          box.toRect(),
          const Radius.circular(AppRadii.sm),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_HighlightPainter old) =>
      old.ayahId != ayahId || old.style != style || old.color != color;
}
