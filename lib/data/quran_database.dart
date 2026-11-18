import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

/// Thrown when the content database cannot be installed or opened. The
/// Mushaf turns it into its blocking error state (plan.md, Errors).
class QuranDatabaseException implements Exception {
  const QuranDatabaseException(this.message, [this.cause]);

  final String message;

  /// The underlying error, when there was one.
  final Object? cause;

  @override
  String toString() => cause == null
      ? 'QuranDatabaseException: $message'
      : 'QuranDatabaseException: $message ($cause)';
}

/// Loads an asset's bytes by key, like `AssetBundle.load`.
typedef AssetLoader = Future<ByteData> Function(String key);

/// The read-only content database (`quran.db`, data-model.md section 1).
///
/// The app copies the bundled asset into its support directory with
/// [install] and opens that copy read-only. Tests open the asset file
/// directly with [openFile].
class QuranDatabase {
  QuranDatabase._(this.db, this.datasetVersion);

  /// Asset key of the bundled database.
  static const String assetKey = 'assets/data/quran.db';

  /// Asset key of the provenance manifest, whose `dataset_version` equals
  /// `meta.dataset_version` of the bundled database (checked by the dataset
  /// integrity test).
  static const String manifestAssetKey = 'assets/data/manifest.json';

  /// File name of the installed copy.
  static const String fileName = 'quran.db';

  /// The underlying connection, opened read-only. Only repositories in
  /// `lib/data/` use it.
  final Database db;

  /// `meta.dataset_version` of the open database.
  final int datasetVersion;

  /// Opens the database file at [path] read-only and reads its dataset
  /// version. Throws [QuranDatabaseException] if the file is missing, is not
  /// a database, or has no valid `meta.dataset_version`.
  static QuranDatabase openFile(String path) {
    if (!File(path).existsSync()) {
      throw QuranDatabaseException('No content database at $path');
    }
    Database? db;
    try {
      db = sqlite3.open(path, mode: OpenMode.readOnly);
      final version = _readVersion(db);
      if (version == null) {
        throw const QuranDatabaseException('meta.dataset_version is missing');
      }
      return QuranDatabase._(db, version);
    } on QuranDatabaseException {
      db?.close();
      rethrow;
    } on Object catch (e) {
      db?.close();
      throw QuranDatabaseException('Cannot open the content database', e);
    }
  }

  /// Makes sure [directory] holds a copy of the bundled database whose
  /// dataset version matches the bundle, then opens it read-only.
  ///
  /// The bundled version is read from the manifest asset, so an up-to-date
  /// copy is opened without loading the 14 MB asset. When the installed copy
  /// is missing, unreadable or of another version, the asset is written to a
  /// temporary file, its `meta.dataset_version` is checked against the
  /// manifest, and the file is renamed over the installed copy. Any failure
  /// throws [QuranDatabaseException].
  static Future<QuranDatabase> install({
    required String directory,
    required AssetLoader loadAsset,
  }) async {
    final target = p.join(directory, fileName);
    final int bundledVersion;
    try {
      bundledVersion = await _bundledVersion(loadAsset);
    } on Object catch (e) {
      throw QuranDatabaseException('Cannot read the bundled manifest', e);
    }

    if (_installedVersion(target) != bundledVersion) {
      await _copyAsset(
        loadAsset: loadAsset,
        directory: directory,
        target: target,
        expectedVersion: bundledVersion,
      );
    }
    return openFile(target);
  }

  static Future<int> _bundledVersion(AssetLoader loadAsset) async {
    final data = await loadAsset(manifestAssetKey);
    final manifest = jsonDecode(
      utf8.decode(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      ),
    );
    if (manifest is! Map<String, Object?>) {
      throw const FormatException('manifest is not a JSON object');
    }
    final version = manifest['dataset_version'];
    if (version is! int) {
      throw const FormatException('manifest has no integer dataset_version');
    }
    return version;
  }

  /// The version of the installed copy, or null when it is missing or
  /// unreadable.
  static int? _installedVersion(String path) {
    if (!File(path).existsSync()) return null;
    Database? db;
    try {
      db = sqlite3.open(path, mode: OpenMode.readOnly);
      return _readVersion(db);
    } on Object {
      return null;
    } finally {
      db?.close();
    }
  }

  static Future<void> _copyAsset({
    required AssetLoader loadAsset,
    required String directory,
    required String target,
    required int expectedVersion,
  }) async {
    final temp = File('$target.tmp');
    try {
      await Directory(directory).create(recursive: true);
      final data = await loadAsset(assetKey);
      await temp.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: true,
      );
      final copied = _installedVersion(temp.path);
      if (copied != expectedVersion) {
        throw QuranDatabaseException(
          'The bundled database has dataset version $copied, but the '
          'manifest says $expectedVersion',
        );
      }
      await temp.rename(target);
    } on QuranDatabaseException {
      _deleteQuietly(temp);
      rethrow;
    } on Object catch (e) {
      _deleteQuietly(temp);
      throw QuranDatabaseException('Cannot install the content database', e);
    }
  }

  static void _deleteQuietly(File file) {
    try {
      if (file.existsSync()) file.deleteSync();
    } on FileSystemException {
      // Nothing more to do; the next install overwrites it.
    }
  }

  static int? _readVersion(Database db) {
    final rows = db.select(
      "SELECT value FROM meta WHERE key = 'dataset_version'",
    );
    if (rows.length != 1) return null;
    final value = rows.first['value'];
    return value is String ? int.tryParse(value) : null;
  }

  /// Closes the connection. The object must not be used afterwards.
  void close() => db.close();
}

/// Retry policy of the content providers: never retry. A failed install or
/// open is deterministic, and the Mushaf shows it as a blocking error.
Duration? contentNoRetry(int retryCount, Object error) => null;

/// The installed content database. A failure surfaces as an [AsyncError]
/// holding a [QuranDatabaseException], and is not retried automatically.
final quranDatabaseProvider = FutureProvider<QuranDatabase>(
  retry: contentNoRetry,
  (ref) async {
    final String directory;
    try {
      directory = (await getApplicationSupportDirectory()).path;
    } on Object catch (e) {
      throw QuranDatabaseException('No application support directory', e);
    }
    final database = await QuranDatabase.install(
      directory: directory,
      loadAsset: rootBundle.load,
    );
    ref.onDispose(database.close);
    return database;
  },
);
