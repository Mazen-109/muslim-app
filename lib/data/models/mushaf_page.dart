import 'package:flutter/foundation.dart';

import 'surah.dart';
import 'word.dart';

/// The number of pages in the Mushaf.
const int pageCount = 604;

/// One line slot of a Mushaf page (`page_lines`), numbered from 1.
@immutable
sealed class PageLine {
  const PageLine(this.number);

  /// The line number on the page: 1 to 8 on pages 1 and 2, 1 to 15 elsewhere.
  final int number;
}

/// A line of ayah text: its words in reading order, (ayah id, position).
final class AyahLine extends PageLine {
  AyahLine(super.number, List<Word> words)
    : words = List<Word>.unmodifiable(words);

  final List<Word> words;

  @override
  bool operator ==(Object other) =>
      other is AyahLine &&
      other.number == number &&
      listEquals(other.words, words);

  @override
  int get hashCode => Object.hash(number, Object.hashAll(words));

  @override
  String toString() => 'AyahLine($number, ${words.length} words)';
}

/// The banner line with the name of [surah].
final class SurahNameLine extends PageLine {
  const SurahNameLine(super.number, this.surah);

  final Surah surah;

  @override
  bool operator ==(Object other) =>
      other is SurahNameLine && other.number == number && other.surah == surah;

  @override
  int get hashCode => Object.hash(number, surah);

  @override
  String toString() => 'SurahNameLine($number, surah ${surah.id})';
}

/// The basmala line before the first ayah of [surah]. Its [words] are the
/// words of ayah 1:1 without its end marker, as stored in the database.
final class BasmalaLine extends PageLine {
  BasmalaLine(super.number, this.surah, List<Word> words)
    : words = List<Word>.unmodifiable(words);

  final Surah surah;
  final List<Word> words;

  @override
  bool operator ==(Object other) =>
      other is BasmalaLine &&
      other.number == number &&
      other.surah == surah &&
      listEquals(other.words, words);

  @override
  int get hashCode => Object.hash(number, surah, Object.hashAll(words));

  @override
  String toString() => 'BasmalaLine($number, surah ${surah.id})';
}

/// One Mushaf page with its lines in order.
@immutable
class MushafPage {
  MushafPage(this.number, List<PageLine> lines)
    : lines = List<PageLine>.unmodifiable(lines);

  /// 1 to 604.
  final int number;
  final List<PageLine> lines;

  @override
  bool operator ==(Object other) =>
      other is MushafPage &&
      other.number == number &&
      listEquals(other.lines, lines);

  @override
  int get hashCode => Object.hash(number, Object.hashAll(lines));

  @override
  String toString() => 'MushafPage($number, ${lines.length} lines)';
}
