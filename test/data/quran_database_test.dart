import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muslim/data/quran_database.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

/// Builds a minimal database file whose meta table holds [version].
Uint8List _fakeDatabase(Directory dir, String name, int? version) {
  final path = p.join(dir.path, name);
  final db = sqlite3.open(path);
  db.execute('CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT NOT NULL)');
  if (version != null) {
    db.execute(
      "INSERT INTO meta (key, value) VALUES ('dataset_version', ?)",
      <Object?>['$version'],
    );
  }
  db.close();
  return File(path).readAsBytesSync();
}

ByteData _bytes(List<int> data) =>
    ByteData.sublistView(Uint8List.fromList(data));

/// A fake asset bundle that serves a database and a manifest and counts
/// loads of the database asset.
class _Assets {
  _Assets({required this.database, required this.manifestVersion});

  Uint8List database;
  int manifestVersion;
  int databaseLoads = 0;

  Future<ByteData> load(String key) async {
    switch (key) {
      case QuranDatabase.assetKey:
        databaseLoads++;
        return _bytes(database);
      case QuranDatabase.manifestAssetKey:
        return _bytes(
          utf8.encode(
            jsonEncode(<String, Object?>{'dataset_version': manifestVersion}),
          ),
        );
    }
    throw FlutterError('Unable to load asset: $key');
  }
}

void main() {
  group('openFile', () {
    test('opens the bundled asset read-only with its dataset version', () {
      final database = QuranDatabase.openFile(QuranDatabase.assetKey);
      addTearDown(database.close);

      final manifest = jsonDecode(
        File(QuranDatabase.manifestAssetKey).readAsStringSync(),
      ) as Map<String, Object?>;
      expect(database.datasetVersion, manifest['dataset_version']);
      expect(
        () => database.db.execute("DELETE FROM meta WHERE key = 'x'"),
        throwsA(isA<SqliteException>()),
      );
    });

    test('a missing file is a QuranDatabaseException', () {
      expect(
        () => QuranDatabase.openFile('does/not/exist.db'),
        throwsA(isA<QuranDatabaseException>()),
      );
    });

    test('a file that is not a database is a QuranDatabaseException', () {
      final dir = Directory.systemTemp.createTempSync('quran_db_test');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File(p.join(dir.path, 'junk.db'))
        ..writeAsStringSync('not a database, just some bytes' * 100);
      expect(
        () => QuranDatabase.openFile(file.path),
        throwsA(isA<QuranDatabaseException>()),
      );
    });

    test('a database without meta.dataset_version is rejected', () {
      final dir = Directory.systemTemp.createTempSync('quran_db_test');
      addTearDown(() => dir.deleteSync(recursive: true));
      _fakeDatabase(dir, 'nometa.db', null);
      expect(
        () => QuranDatabase.openFile(p.join(dir.path, 'nometa.db')),
        throwsA(isA<QuranDatabaseException>()),
      );
    });
  });

  group('install', () {
    late Directory work;
    late Directory appDir;

    setUp(() {
      work = Directory.systemTemp.createTempSync('quran_db_install');
      appDir = Directory(p.join(work.path, 'support'));
    });
    tearDown(() => work.deleteSync(recursive: true));

    String installed() => p.join(appDir.path, QuranDatabase.fileName);

    List<String> filesInAppDir() =>
        appDir.listSync().map((e) => p.basename(e.path)).toList()..sort();

    test('copies the asset on first run, creating the directory', () async {
      final assets = _Assets(
        database: _fakeDatabase(work, 'v1.db', 1),
        manifestVersion: 1,
      );
      final database = await QuranDatabase.install(
        directory: appDir.path,
        loadAsset: assets.load,
      );
      addTearDown(database.close);

      expect(database.datasetVersion, 1);
      expect(assets.databaseLoads, 1);
      expect(filesInAppDir(), <String>[QuranDatabase.fileName]);
    });

    test('keeps the installed copy when the version is unchanged', () async {
      final assets = _Assets(
        database: _fakeDatabase(work, 'v1.db', 1),
        manifestVersion: 1,
      );
      (await QuranDatabase.install(
        directory: appDir.path,
        loadAsset: assets.load,
      )).close();
      final modified = File(installed()).lastModifiedSync();

      final database = await QuranDatabase.install(
        directory: appDir.path,
        loadAsset: assets.load,
      );
      addTearDown(database.close);

      expect(assets.databaseLoads, 1);
      expect(File(installed()).lastModifiedSync(), modified);
      expect(database.datasetVersion, 1);
    });

    test('replaces the installed copy when the version changes', () async {
      final assets = _Assets(
        database: _fakeDatabase(work, 'v1.db', 1),
        manifestVersion: 1,
      );
      (await QuranDatabase.install(
        directory: appDir.path,
        loadAsset: assets.load,
      )).close();

      assets
        ..database = _fakeDatabase(work, 'v2.db', 2)
        ..manifestVersion = 2;
      final database = await QuranDatabase.install(
        directory: appDir.path,
        loadAsset: assets.load,
      );
      addTearDown(database.close);

      expect(assets.databaseLoads, 2);
      expect(database.datasetVersion, 2);
      expect(filesInAppDir(), <String>[QuranDatabase.fileName]);
    });

    test('replaces an unreadable installed copy', () async {
      appDir.createSync(recursive: true);
      File(installed()).writeAsStringSync('corrupt' * 200);
      final assets = _Assets(
        database: _fakeDatabase(work, 'v1.db', 1),
        manifestVersion: 1,
      );
      final database = await QuranDatabase.install(
        directory: appDir.path,
        loadAsset: assets.load,
      );
      addTearDown(database.close);

      expect(database.datasetVersion, 1);
      expect(assets.databaseLoads, 1);
    });

    test('an asset whose meta disagrees with the manifest is rejected and '
        'leaves the installed copy in place', () async {
      final assets = _Assets(
        database: _fakeDatabase(work, 'v1.db', 1),
        manifestVersion: 1,
      );
      (await QuranDatabase.install(
        directory: appDir.path,
        loadAsset: assets.load,
      )).close();

      assets
        ..database = _fakeDatabase(work, 'v3.db', 3)
        ..manifestVersion = 2;
      await expectLater(
        QuranDatabase.install(directory: appDir.path, loadAsset: assets.load),
        throwsA(isA<QuranDatabaseException>()),
      );
      expect(filesInAppDir(), <String>[QuranDatabase.fileName]);
      final kept = QuranDatabase.openFile(installed());
      addTearDown(kept.close);
      expect(kept.datasetVersion, 1);
    });

    test('a missing asset is a QuranDatabaseException', () async {
      Future<ByteData> loadNothing(String key) async =>
          throw FlutterError('Unable to load asset: $key');
      await expectLater(
        QuranDatabase.install(directory: appDir.path, loadAsset: loadNothing),
        throwsA(isA<QuranDatabaseException>()),
      );
    });

    test('installs the real bundled asset', () async {
      Future<ByteData> loadFile(String key) async =>
          _bytes(File(key).readAsBytesSync());
      final database = await QuranDatabase.install(
        directory: appDir.path,
        loadAsset: loadFile,
      );
      addTearDown(database.close);
      expect(database.datasetVersion, greaterThanOrEqualTo(1));
      expect(
        File(installed()).lengthSync(),
        File(QuranDatabase.assetKey).lengthSync(),
      );
    });
  });
}
