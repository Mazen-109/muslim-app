import 'package:flutter/foundation.dart';

/// One row of `juzs` (data-model.md section 1).
@immutable
class Juz {
  const Juz({
    required this.id,
    required this.firstAyahId,
    required this.lastAyahId,
    required this.pageStart,
  });

  /// 1 to 30.
  final int id;
  final int firstAyahId;
  final int lastAyahId;

  /// The page of [firstAyahId].
  final int pageStart;

  @override
  bool operator ==(Object other) =>
      other is Juz &&
      other.id == id &&
      other.firstAyahId == firstAyahId &&
      other.lastAyahId == lastAyahId &&
      other.pageStart == pageStart;

  @override
  int get hashCode => Object.hash(id, firstAyahId, lastAyahId, pageStart);

  @override
  String toString() => 'Juz($id, $firstAyahId-$lastAyahId)';
}
