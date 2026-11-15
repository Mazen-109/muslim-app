import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'user_database.dart';

/// The two kinds of per-ayah marks a user can set. Both share one table
/// shape (data-model.md section 3).
enum AyahMarkKind {
  bookmark('bookmarks'),
  memorisation('memorisation_marks');

  const AyahMarkKind(this.table);

  /// The `user.db` table that stores this kind.
  final String table;
}

/// One stored mark: the ayah and when it was set.
@immutable
class AyahMark {
  const AyahMark({required this.ayahId, required this.createdAt});

  final int ayahId;
  final DateTime createdAt;

  @override
  bool operator ==(Object other) =>
      other is AyahMark &&
      other.ayahId == ayahId &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(ayahId, createdAt);

  @override
  String toString() => 'AyahMark($ayahId, $createdAt)';
}

/// A change to the marks of one kind: [ayahId] is now set or cleared.
@immutable
class AyahMarkChange {
  const AyahMarkChange({required this.ayahId, required this.isSet});

  final int ayahId;
  final bool isSet;

  @override
  bool operator ==(Object other) =>
      other is AyahMarkChange && other.ayahId == ayahId && other.isSet == isSet;

  @override
  int get hashCode => Object.hash(ayahId, isSet);

  @override
  String toString() => 'AyahMarkChange($ayahId, isSet: $isSet)';
}

/// Bookmarks or memorisation marks, depending on [kind].
///
/// Adding a mark that already exists keeps its original time; removing one
/// that does not exist does nothing. [changes] emits only when a row actually
/// changed.
class BookmarkRepository {
  BookmarkRepository(this._database, this.kind, {this._clock = DateTime.now});

  final UserDatabase _database;
  final DateTime Function() _clock;
  final StreamController<AyahMarkChange> _changes =
      StreamController<AyahMarkChange>.broadcast();

  /// Which marks this repository manages.
  final AyahMarkKind kind;

  /// Emits after every add or remove that changed the stored marks.
  Stream<AyahMarkChange> get changes => _changes.stream;

  /// Whether [ayahId] is marked.
  bool isSet(int ayahId) => _database.db.select(
    'SELECT 1 FROM ${kind.table} WHERE ayah_id = ?',
    <Object?>[ayahId],
  ).isNotEmpty;

  /// Marks [ayahId]. Throws [RangeError] outside 1 to 6236.
  void add(int ayahId) {
    // Checked here because OR IGNORE would also silently skip a CHECK
    // violation.
    _checkAyahId(ayahId);
    _database.db.execute(
      'INSERT OR IGNORE INTO ${kind.table} (ayah_id, created_at) '
      'VALUES (?, ?)',
      <Object?>[ayahId, _clock().millisecondsSinceEpoch],
    );
    _emitIfChanged(ayahId, isSet: true);
  }

  /// Clears the mark on [ayahId].
  void remove(int ayahId) {
    _database.db.execute(
      'DELETE FROM ${kind.table} WHERE ayah_id = ?',
      <Object?>[ayahId],
    );
    _emitIfChanged(ayahId, isSet: false);
  }

  /// Flips the mark on [ayahId] and returns the new state.
  bool toggle(int ayahId) {
    if (isSet(ayahId)) {
      remove(ayahId);
      return false;
    }
    add(ayahId);
    return true;
  }

  /// Every mark, newest first; marks set in the same millisecond are ordered
  /// by ayah id.
  List<AyahMark> list() => <AyahMark>[
    for (final row in _database.db.select(
      'SELECT ayah_id, created_at FROM ${kind.table} '
      'ORDER BY created_at DESC, ayah_id ASC',
    ))
      AyahMark(
        ayahId: row['ayah_id'] as int,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          row['created_at'] as int,
        ),
      ),
  ];

  /// Closes [changes]. The repository must not be used afterwards.
  Future<void> dispose() => _changes.close();

  void _emitIfChanged(int ayahId, {required bool isSet}) {
    if (_database.db.updatedRows > 0) {
      _changes.add(AyahMarkChange(ayahId: ayahId, isSet: isSet));
    }
  }

  static void _checkAyahId(int ayahId) => RangeError.checkValueInInterval(
    ayahId,
    firstAyahId,
    lastAyahId,
    'ayahId',
  );
}

/// The clock used to time-stamp marks. Tests override it.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

FutureProvider<BookmarkRepository> _markRepositoryProvider(AyahMarkKind kind) =>
    FutureProvider<BookmarkRepository>((ref) async {
      final repository = BookmarkRepository(
        await ref.watch(userDatabaseProvider.future),
        kind,
        clock: ref.watch(clockProvider),
      );
      ref.onDispose(repository.dispose);
      return repository;
    });

/// The user's bookmarks.
final bookmarkRepositoryProvider = _markRepositoryProvider(
  AyahMarkKind.bookmark,
);

/// The user's memorisation marks.
final memorisationRepositoryProvider = _markRepositoryProvider(
  AyahMarkKind.memorisation,
);
