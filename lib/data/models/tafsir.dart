import 'package:flutter/foundation.dart';

import 'ayah_ref.dart';

/// One row of `tafsirs`: a published tafsir work.
@immutable
class Tafsir {
  const Tafsir({
    required this.id,
    required this.nameAr,
    required this.author,
    required this.language,
    required this.slug,
  });

  final int id;
  final String nameAr;
  final String author;
  final String language;
  final String slug;

  @override
  bool operator ==(Object other) =>
      other is Tafsir &&
      other.id == id &&
      other.nameAr == nameAr &&
      other.author == author &&
      other.language == language &&
      other.slug == slug;

  @override
  int get hashCode => Object.hash(id, nameAr, author, language, slug);

  @override
  String toString() => 'Tafsir($id, $slug)';
}

/// The stored tafsir text for one ayah, with the run of consecutive ayahs
/// of the same surah that share exactly the same stored text ([covers]).
/// [covers] is a single ayah when the entry explains only that ayah.
@immutable
class TafsirEntry {
  const TafsirEntry({
    required this.tafsirId,
    required this.ayahId,
    required this.text,
    required this.covers,
  });

  final int tafsirId;
  final int ayahId;

  /// The stored text, unchanged.
  final String text;
  final AyahRange covers;

  @override
  bool operator ==(Object other) =>
      other is TafsirEntry &&
      other.tafsirId == tafsirId &&
      other.ayahId == ayahId &&
      other.text == text &&
      other.covers == covers;

  @override
  int get hashCode => Object.hash(tafsirId, ayahId, text, covers);

  @override
  String toString() => 'TafsirEntry($tafsirId, ayah $ayahId, $covers)';
}
