import 'package:flutter/foundation.dart';

import 'ayah_ref.dart';

/// One row of `ayahs` (data-model.md section 1). Text fields hold the stored
/// values unchanged; only [textQpcHafs] is ever displayed as the ayah.
@immutable
class Ayah {
  const Ayah({
    required this.id,
    required this.surahId,
    required this.ayahNumber,
    required this.verseKey,
    required this.textQpcHafs,
    required this.textUthmani,
    required this.textSearch,
    required this.textSearchFolded,
    required this.page,
    required this.juz,
    required this.hizb,
    required this.rubElHizb,
    this.sajdah,
  });

  /// 1 to 6236, in Mushaf order.
  final int id;
  final int surahId;
  final int ayahNumber;

  /// `"{surah}:{ayah}"`, as stored.
  final String verseKey;

  /// The canonical display text.
  final String textQpcHafs;

  /// The text used when sharing.
  final String textUthmani;

  /// Search text; never displayed as the ayah.
  final String textSearch;

  /// Folded search text; never displayed.
  final String textSearchFolded;

  /// The page of the ayah's first word.
  final int page;
  final int juz;
  final int hizb;
  final int rubElHizb;

  /// The sajdah number when the ayah has one.
  final int? sajdah;

  /// The ayah as a ref.
  AyahRef get ref => AyahRef(surahId, ayahNumber);

  @override
  bool operator ==(Object other) =>
      other is Ayah &&
      other.id == id &&
      other.surahId == surahId &&
      other.ayahNumber == ayahNumber &&
      other.verseKey == verseKey &&
      other.textQpcHafs == textQpcHafs &&
      other.textUthmani == textUthmani &&
      other.textSearch == textSearch &&
      other.textSearchFolded == textSearchFolded &&
      other.page == page &&
      other.juz == juz &&
      other.hizb == hizb &&
      other.rubElHizb == rubElHizb &&
      other.sajdah == sajdah;

  @override
  int get hashCode => Object.hash(
    id,
    surahId,
    ayahNumber,
    verseKey,
    textQpcHafs,
    textUthmani,
    textSearch,
    textSearchFolded,
    page,
    juz,
    hizb,
    rubElHizb,
    sajdah,
  );

  @override
  String toString() => 'Ayah($id, $verseKey)';
}
