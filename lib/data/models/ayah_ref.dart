import 'package:flutter/foundation.dart';

/// The number of surahs in the Mushaf.
const int surahCount = 114;

/// An ayah identified by surah and ayah number, written `"S:A"` (for example
/// `2:255`).
///
/// The constructor checks only what holds for every surah: [surah] is 1 to
/// 114 and [ayah] is at least 1. The upper bound of [ayah] depends on the
/// surah and comes from the content database, so it is checked with
/// [checkAgainst] or by `QuranRepository`. Refs compare in Mushaf order.
@immutable
class AyahRef implements Comparable<AyahRef> {
  /// Throws [RangeError] when [surah] is outside 1 to 114 or [ayah] is
  /// below 1.
  AyahRef(this.surah, this.ayah) {
    RangeError.checkValueInInterval(surah, 1, surahCount, 'surah');
    if (ayah < 1) throw RangeError.range(ayah, 1, null, 'ayah');
  }

  /// Parses a key such as `2:255`: two decimal numbers without signs,
  /// spaces or leading zeros. When [ayahCounts] is given, the ayah number is
  /// also checked against it (see [checkAgainst]). Throws [FormatException]
  /// on any invalid key.
  factory AyahRef.parse(String key, {List<int>? ayahCounts}) {
    final match = _keyPattern.firstMatch(key);
    if (match == null) {
      throw FormatException('Not an ayah key: "$key"');
    }
    final surah = int.parse(match.group(1)!);
    final ayah = int.parse(match.group(2)!);
    try {
      final ref = AyahRef(surah, ayah);
      if (ayahCounts != null) ref.checkAgainst(ayahCounts);
      return ref;
    } on RangeError catch (e) {
      throw FormatException('Ayah key "$key" is out of range: ${e.message}');
    }
  }

  /// Like [AyahRef.parse], but returns null instead of throwing.
  static AyahRef? tryParse(String key, {List<int>? ayahCounts}) {
    try {
      return AyahRef.parse(key, ayahCounts: ayahCounts);
    } on FormatException {
      return null;
    }
  }

  static final RegExp _keyPattern = RegExp(
    r'^([1-9][0-9]{0,2}):([1-9][0-9]{0,2})$',
  );

  final int surah;
  final int ayah;

  /// Whether [ayah] is within the count of [surah] in [ayahCounts], where
  /// `ayahCounts[s - 1]` is the ayah count of surah `s`.
  bool isValidFor(List<int> ayahCounts) =>
      ayahCounts.length == surahCount && ayah <= ayahCounts[surah - 1];

  /// Throws [RangeError] unless [isValidFor] holds, and [ArgumentError] when
  /// [ayahCounts] does not have one entry per surah.
  void checkAgainst(List<int> ayahCounts) {
    if (ayahCounts.length != surahCount) {
      throw ArgumentError.value(
        ayahCounts.length,
        'ayahCounts.length',
        'must be $surahCount',
      );
    }
    RangeError.checkValueInInterval(ayah, 1, ayahCounts[surah - 1], 'ayah');
  }

  /// The key form, for example `2:255`.
  String get key => '$surah:$ayah';

  @override
  int compareTo(AyahRef other) =>
      surah != other.surah ? surah - other.surah : ayah - other.ayah;

  bool operator <(AyahRef other) => compareTo(other) < 0;
  bool operator <=(AyahRef other) => compareTo(other) <= 0;
  bool operator >(AyahRef other) => compareTo(other) > 0;
  bool operator >=(AyahRef other) => compareTo(other) >= 0;

  @override
  bool operator ==(Object other) =>
      other is AyahRef && other.surah == surah && other.ayah == ayah;

  @override
  int get hashCode => Object.hash(surah, ayah);

  @override
  String toString() => key;
}

/// An inclusive range of ayahs in Mushaf order; [from] is never after [to].
@immutable
class AyahRange {
  /// Throws [ArgumentError] when [from] is after [to].
  AyahRange(this.from, this.to) {
    if (from > to) {
      throw ArgumentError('AyahRange: $from is after $to');
    }
  }

  /// A range of one ayah.
  AyahRange.single(AyahRef ref) : this(ref, ref);

  final AyahRef from;
  final AyahRef to;

  /// Whether [ref] lies between [from] and [to], both included.
  bool contains(AyahRef ref) => from <= ref && ref <= to;

  /// Whether the range holds exactly one ayah.
  bool get isSingle => from == to;

  @override
  bool operator ==(Object other) =>
      other is AyahRange && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);

  @override
  String toString() => '$from-$to';
}
