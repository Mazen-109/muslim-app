import 'package:flutter/foundation.dart';

/// Whether a word row is a word or the ayah end marker (`words.char_type`).
enum WordCharType {
  word,
  end;

  /// Returns the type stored as [value], or throws [FormatException].
  static WordCharType parse(String value) => switch (value) {
    'word' => word,
    'end' => end,
    _ => throw FormatException('Unknown word char_type "$value"'),
  };
}

/// One row of `words` (data-model.md section 1): a word or an ayah end
/// marker, with its place in the page layout.
///
/// Reading order is ([ayahId], [position]); [id] is the source word id and
/// does not follow reading order.
@immutable
class Word {
  const Word({
    required this.id,
    required this.ayahId,
    required this.position,
    required this.charType,
    required this.textQpcHafs,
    required this.page,
    required this.line,
  });

  final int id;

  /// The ayah the word belongs to.
  final int ayahId;

  /// 1-based position within the ayah.
  final int position;
  final WordCharType charType;

  /// The stored text, unchanged. It may contain an internal space.
  final String textQpcHafs;
  final int page;
  final int line;

  @override
  bool operator ==(Object other) =>
      other is Word &&
      other.id == id &&
      other.ayahId == ayahId &&
      other.position == position &&
      other.charType == charType &&
      other.textQpcHafs == textQpcHafs &&
      other.page == page &&
      other.line == line;

  @override
  int get hashCode =>
      Object.hash(id, ayahId, position, charType, textQpcHafs, page, line);

  @override
  String toString() => 'Word($id, ayah $ayahId, position $position)';
}
