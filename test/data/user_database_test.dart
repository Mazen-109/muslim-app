import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:muslim/data/user_database.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

List<String> _tables(UserDatabase database) => <String>[
  for (final row in database.db.select(
    "SELECT name FROM sqlite_master WHERE type = 'table' ORDER BY name",
  ))
    row['name'] as String,
];

void main() {
  group('UserDatabase', () {
    test('creates both tables from an empty database at version 1', () {
      final database = UserDatabase.inMemory();
      addTearDown(database.close);

      expect(_tables(database), <String>['bookmarks', 'memorisation_marks']);
      expect(database.db.userVersion, 1);
      expect(UserDatabase.schemaVersion, 1);
    });

    test('tables have the data-model columns', () {
      final database = UserDatabase.inMemory();
      addTearDown(database.close);

      for (final table in <String>['bookmarks', 'memorisation_marks']) {
        final columns = database.db.select('PRAGMA table_info($table)');
        expect(
          <List<Object?>>[
            for (final c in columns)
              <Object?>[c['name'], c['type'], c['notnull'], c['pk']],
          ],
          <List<Object?>>[
            <Object?>['ayah_id', 'INTEGER', 0, 1],
            <Object?>['created_at', 'INTEGER', 1, 0],
          ],
          reason: table,
        );
      }
    });

    test(
      'CHECK constraint rejects ayah ids 0 and 6237, accepts 1 and 6236',
      () {
        final database = UserDatabase.inMemory();
        addTearDown(database.close);

        for (final table in <String>['bookmarks', 'memorisation_marks']) {
          void insert(int ayahId) => database.db.execute(
            'INSERT INTO $table (ayah_id, created_at) VALUES (?, 0)',
            <Object?>[ayahId],
          );
          expect(() => insert(0), throwsA(isA<SqliteException>()));
          expect(() => insert(6237), throwsA(isA<SqliteException>()));
          insert(1);
          insert(6236);
          expect(database.db.select('SELECT * FROM $table'), hasLength(2));
        }
      },
    );

    test('created_at is NOT NULL', () {
      final database = UserDatabase.inMemory();
      addTearDown(database.close);

      expect(
        () => database.db.execute(
          'INSERT INTO bookmarks (ayah_id, created_at) VALUES (1, NULL)',
        ),
        throwsA(isA<SqliteException>()),
      );
    });

    test('re-opening a file keeps data and does not re-run migrations', () {
      final directory = Directory.systemTemp.createTempSync('user_db_test');
      addTearDown(() => directory.deleteSync(recursive: true));
      final path = p.join(directory.path, UserDatabase.fileName);

      final first = UserDatabase.open(path);
      first.db.execute(
        'INSERT INTO bookmarks (ayah_id, created_at) VALUES (5, 42)',
      );
      first.close();

      // Version 1 uses plain CREATE TABLE, so re-running it would throw.
      final second = UserDatabase.open(path);
      addTearDown(second.close);
      expect(second.db.userVersion, 1);
      expect(
        second.db.select('SELECT ayah_id FROM bookmarks').single['ayah_id'],
        5,
      );
    });

    test('the runner applies only the steps above the stored version', () {
      final raw = sqlite3.openInMemory();
      addTearDown(raw.close);
      final runs = <int>[];
      List<UserDatabaseMigration> migrations() => <UserDatabaseMigration>[
        (_) => runs.add(1),
        (_) => runs.add(2),
      ];

      UserDatabase.withMigrations(raw, migrations());
      expect(runs, <int>[1, 2]);
      expect(raw.userVersion, 2);

      runs.clear();
      UserDatabase.withMigrations(raw, migrations());
      expect(runs, isEmpty);

      raw.userVersion = 1;
      UserDatabase.withMigrations(raw, migrations());
      expect(runs, <int>[2]);
      expect(raw.userVersion, 2);
    });

    test('a failing step rolls back and leaves the version unchanged', () {
      final raw = sqlite3.openInMemory();
      addTearDown(raw.close);

      expect(
        () => UserDatabase.withMigrations(raw, <UserDatabaseMigration>[
          (db) {
            db.execute('CREATE TABLE t (x INTEGER)');
            throw StateError('boom');
          },
        ]),
        throwsStateError,
      );
      expect(raw.userVersion, 0);
      expect(
        raw.select("SELECT name FROM sqlite_master WHERE name = 't'"),
        isEmpty,
      );
    });

    test('refuses a database newer than the app', () {
      final raw = sqlite3.openInMemory();
      addTearDown(raw.close);
      raw.userVersion = 2;

      expect(
        () => UserDatabase.withMigrations(raw, UserDatabase.defaultMigrations),
        throwsStateError,
      );
    });
  });
}
