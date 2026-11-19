import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/ayah.dart';
import '../../../data/models/surah.dart';
import '../../../data/models/word.dart';
import '../../../data/quran_repository.dart';

/// One surah as the continuous view sets it: its header data, its basmala
/// and its ayahs in paragraphs.
///
/// A paragraph holds the ayahs whose first word is on the same Mushaf page,
/// so a long surah becomes a list of short paragraphs that the view builds
/// lazily, and paragraph breaks fall where the printed pages turn.
@immutable
class ContinuousSurah {
  ContinuousSurah({
    required this.surah,
    required this.basmala,
    required List<List<Ayah>> paragraphs,
  }) : paragraphs = List<List<Ayah>>.unmodifiable(
         paragraphs.map(List<Ayah>.unmodifiable),
       );

  final Surah surah;

  /// The basmala words to set above the first ayah, or null when the surah
  /// has no separate basmala (surah 1, where it is ayah 1, and surah 9).
  final List<Word>? basmala;

  final List<List<Ayah>> paragraphs;

  /// The id of the surah's first ayah.
  int get firstAyahId => paragraphs.first.first.id;

  /// The id of the surah's last ayah.
  int get lastAyahId => paragraphs.last.last.id;

  /// The index of the paragraph holding ayah [ayahId]; throws
  /// [RangeError] when the ayah is not in this surah.
  int paragraphOf(int ayahId) {
    RangeError.checkValueInInterval(ayahId, firstAyahId, lastAyahId, 'ayahId');
    for (var i = paragraphs.length - 1; i >= 0; i--) {
      if (paragraphs[i].first.id <= ayahId) return i;
    }
    throw StateError('unreachable');
  }

  /// Splits [ayahs] (one surah, in order) into paragraphs by the page of
  /// each ayah's first word.
  static List<List<Ayah>> paragraphsByPage(List<Ayah> ayahs) {
    final paragraphs = <List<Ayah>>[];
    for (final ayah in ayahs) {
      if (paragraphs.isEmpty || paragraphs.last.last.page != ayah.page) {
        paragraphs.add(<Ayah>[ayah]);
      } else {
        paragraphs.last.add(ayah);
      }
    }
    return paragraphs;
  }
}

/// Surah [surahId] (1 to 114) for the continuous view. Needs
/// [quranRepositoryProvider] to have a value.
final continuousSurahProvider = Provider.autoDispose
    .family<ContinuousSurah, int>((ref, surahId) {
      final repository = ref.watch(quranRepositoryProvider).requireValue;
      final surah = repository.surah(surahId);
      return ContinuousSurah(
        surah: surah,
        basmala: surah.bismillahPre ? repository.basmalaWords() : null,
        paragraphs: ContinuousSurah.paragraphsByPage(
          repository.ayahsOfSurah(surahId),
        ),
      );
    });
