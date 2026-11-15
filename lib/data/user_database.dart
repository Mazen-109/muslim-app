import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

/// The first and last valid ayah ids, in Mushaf order.
const int firstAyahId = 1;
const int lastAyahId = 6236;

/// One schema step: brings a database from version `n - 1` to version `n`,
/// where `n` is the step's position in the migration list, counted from 1.
typedef UserDatabaseMigration = void Function(Database db);

/// The on-device user database (`user.db`): bookmarks and memorisation marks.
///
/// The schema version lives in `PRAGMA user_version`. Opening a database runs
/// every migration above its stored version, each in its own transaction, so
/// an empty database ends at [schemaVersion] and an up-to-date one is left
/// untouched.
class UserDatabase {
  UserDatabase._(this.db, List<UserDatabaseMigration> migrations) {
    _migrate(migrations);
  }

  /// Opens or creates the database file at [path].
  factory UserDatabase.open(String path) =>
      UserDatabase._(sqlite3.open(path), defaultMigrations);

  /// Opens a private in-memory database, used by tests.
  factory UserDatabase.inMemory() =>
      UserDatabase._(sqlite3.openInMemory(), defaultMigrations);

  /// Wraps an already open connection with a custom migration list, so tests
  /// can observe the migration runner.
  @visibleForTesting
  factory UserDatabase.withMigrations(
    Database db,
    List<UserDatabaseMigration> migrations,
  ) => UserDatabase._(db, migrations);

  /// The file name of the database inside the application support directory.
  static const String fileName = 'user.db';

  /// The schema version this build of the app expects.
  static int get schemaVersion => defaultMigrations.length;

  /// Every schema step in order; index 0 creates version 1.
  static final List<UserDatabaseMigration> defaultMigrations =
      List<UserDatabaseMigration>.unmodifiable(<UserDatabaseMigration>[
        _createVersion1,
      ]);

  /// The underlying connection. Only repositories in `lib/data/` use it.
  final Database db;

  void _migrate(List<UserDatabaseMigration> migrations) {
    final current = db.userVersion;
    if (current > migrations.length) {
      throw StateError(
        'user.db has schema version $current, newer than the supported '
        'version ${migrations.length}.',
      );
    }
    for (var version = current + 1; version <= migrations.length; version++) {
      db.execute('BEGIN');
      try {
        migrations[version - 1](db);
        db.userVersion = version;
        db.execute('COMMIT');
      } catch (_) {
        db.execute('ROLLBACK');
        rethrow;
      }
    }
  }

  static void _createVersion1(Database db) {
    for (final table in const <String>['bookmarks', 'memorisation_marks']) {
      db.execute('''
        CREATE TABLE $table (
          ayah_id INTEGER PRIMARY KEY
            CHECK (ayah_id BETWEEN $firstAyahId AND $lastAyahId),
          created_at INTEGER NOT NULL
        )
      ''');
    }
  }

  /// Closes the connection. The object must not be used afterwards.
  void close() => db.close();
}

/// The user database in the application support directory. Tests override
/// this with an in-memory database.
final userDatabaseProvider = FutureProvider<UserDatabase>((ref) async {
  final directory = await getApplicationSupportDirectory();
  final database = UserDatabase.open(
    p.join(directory.path, UserDatabase.fileName),
  );
  ref.onDispose(database.close);
  return database;
});
