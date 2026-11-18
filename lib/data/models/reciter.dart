import 'package:flutter/foundation.dart';

import 'ayah_ref.dart';

/// The recitation style of a reciter (`reciters.style`).
enum ReciterStyle {
  murattal,
  mujawwad,
  muallim;

  /// Returns the style stored as [value], null for NULL, or throws
  /// [FormatException].
  static ReciterStyle? parse(String? value) => switch (value) {
    null => null,
    'murattal' => murattal,
    'mujawwad' => mujawwad,
    'muallim' => muallim,
    _ => throw FormatException('Unknown reciter style "$value"'),
  };
}

/// One row of `reciters` (data-model.md section 1).
@immutable
class Reciter {
  const Reciter({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.style,
    required this.urlTemplate,
    required this.sourceId,
    required this.sortOrder,
  });

  final int id;
  final String nameAr;
  final String nameEn;
  final ReciterStyle? style;

  /// An HTTPS URL containing `{surah3}` and `{ayah3}`.
  final String urlTemplate;

  /// The id of the reciter's entry in the sources registry.
  final String sourceId;
  final int sortOrder;

  /// The audio file of [ref]: the template with `{surah3}` and `{ayah3}`
  /// replaced by the surah and ayah numbers, zero-padded to three digits.
  Uri audioUrl(AyahRef ref) => Uri.parse(
    urlTemplate
        .replaceAll('{surah3}', ref.surah.toString().padLeft(3, '0'))
        .replaceAll('{ayah3}', ref.ayah.toString().padLeft(3, '0')),
  );

  @override
  bool operator ==(Object other) =>
      other is Reciter &&
      other.id == id &&
      other.nameAr == nameAr &&
      other.nameEn == nameEn &&
      other.style == style &&
      other.urlTemplate == urlTemplate &&
      other.sourceId == sourceId &&
      other.sortOrder == sortOrder;

  @override
  int get hashCode =>
      Object.hash(id, nameAr, nameEn, style, urlTemplate, sourceId, sortOrder);

  @override
  String toString() => 'Reciter($id)';
}
