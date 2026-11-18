import 'package:flutter/foundation.dart';

/// Where a surah was revealed (`surahs.revelation_place`).
enum RevelationPlace {
  makkah,
  madinah;

  /// Returns the place stored as [value], or throws [FormatException].
  static RevelationPlace parse(String value) => switch (value) {
    'makkah' => makkah,
    'madinah' => madinah,
    _ => throw FormatException('Unknown revelation place "$value"'),
  };
}

/// One row of `surahs` (data-model.md section 1).
@immutable
class Surah {
  const Surah({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.revelationPlace,
    required this.revelationOrder,
    required this.ayahCount,
    required this.bismillahPre,
    required this.pageStart,
    required this.pageEnd,
  });

  final int id;
  final String nameAr;
  final String nameEn;
  final RevelationPlace revelationPlace;
  final int revelationOrder;
  final int ayahCount;

  /// Whether a basmala line precedes the first ayah (false for 1 and 9).
  final bool bismillahPre;

  /// The page of the first word of ayah 1. The surah's name and basmala
  /// lines may sit at the bottom of the previous page.
  final int pageStart;

  /// The page of the surah's last word.
  final int pageEnd;

  @override
  bool operator ==(Object other) =>
      other is Surah &&
      other.id == id &&
      other.nameAr == nameAr &&
      other.nameEn == nameEn &&
      other.revelationPlace == revelationPlace &&
      other.revelationOrder == revelationOrder &&
      other.ayahCount == ayahCount &&
      other.bismillahPre == bismillahPre &&
      other.pageStart == pageStart &&
      other.pageEnd == pageEnd;

  @override
  int get hashCode => Object.hash(
    id,
    nameAr,
    nameEn,
    revelationPlace,
    revelationOrder,
    ayahCount,
    bismillahPre,
    pageStart,
    pageEnd,
  );

  @override
  String toString() => 'Surah($id)';
}
