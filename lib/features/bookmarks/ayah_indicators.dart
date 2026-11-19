import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../data/bookmark_repository.dart';

/// The marks the reader set on the ayahs, as the reader views draw them:
/// the ids of the bookmarked ayahs and of the memorised ones.
@immutable
class AyahMarkSets {
  const AyahMarkSets({
    this.bookmarked = const <int>{},
    this.memorised = const <int>{},
  });

  final Set<int> bookmarked;
  final Set<int> memorised;

  /// No marks at all.
  static const AyahMarkSets none = AyahMarkSets();

  bool get isEmpty => bookmarked.isEmpty && memorised.isEmpty;

  /// Whether ayah [ayahId] carries any mark.
  bool marks(int ayahId) =>
      bookmarked.contains(ayahId) || memorised.contains(ayahId);

  @override
  bool operator ==(Object other) =>
      other is AyahMarkSets &&
      setEquals(other.bookmarked, bookmarked) &&
      setEquals(other.memorised, memorised);

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(bookmarked),
    Object.hashAllUnordered(memorised),
  );
}

/// Both kinds of marks, following every change made through the
/// repositories. Empty while the user database opens.
final ayahMarkSetsProvider = Provider<AyahMarkSets>(
  (ref) => AyahMarkSets(
    bookmarked: ref.watch(markedAyahIdsProvider(AyahMarkKind.bookmark)),
    memorised: ref.watch(markedAyahIdsProvider(AyahMarkKind.memorisation)),
  ),
);

/// The key of the indicator of ayah [ayahId] in a reader view.
class AyahIndicatorKey extends ValueKey<int> {
  const AyahIndicatorKey(super.value);
}

/// The key of one mark inside an [AyahIndicators].
class AyahIndicatorMarkKey extends ValueKey<(int, AyahMarkKind)> {
  const AyahIndicatorMarkKey(int ayahId, AyahMarkKind kind)
    : super((ayahId, kind));
}

/// The marks of one ayah, drawn small above its end marker in both reader
/// views (spec US5): a bookmark ribbon in Lapis Ink, the reader's position
/// colour, and a check in Faded Ink for an ayah the reader has memorised.
/// Both stand side by side when the ayah has both.
///
/// The marks sit in the space the line leaves above the marker and never
/// cover the text. They take no taps, so a tap or long press there still
/// reaches the ayah.
///
/// [size] is the size of one mark, in the coordinates of the text it sits
/// on; the reader views derive it from their Quran font size.
class AyahIndicators extends StatelessWidget {
  const AyahIndicators({
    super.key,
    required this.ayahId,
    required this.bookmarked,
    required this.memorised,
    required this.size,
  });

  final int ayahId;
  final bool bookmarked;
  final bool memorised;
  final double size;

  /// The size of one mark as a share of the Quran font size.
  static const double sizeEm = 0.45;

  /// The space between two marks as a share of the mark size.
  static const double gapShare = 0.15;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    Widget mark(AyahMarkKind kind, IconData icon, Color color, String label) =>
        Semantics(
          label: label,
          child: Icon(
            icon,
            key: AyahIndicatorMarkKey(ayahId, kind),
            size: size,
            color: color,
          ),
        );
    return IgnorePointer(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (bookmarked)
            mark(
              AyahMarkKind.bookmark,
              Icons.bookmark,
              scheme.primary,
              l10n.mushafIndicatorBookmarked,
            ),
          if (bookmarked && memorised) SizedBox(width: size * gapShare),
          if (memorised)
            mark(
              AyahMarkKind.memorisation,
              Icons.check_circle,
              scheme.onSurfaceVariant,
              l10n.mushafIndicatorMemorised,
            ),
        ],
      ),
    );
  }
}
