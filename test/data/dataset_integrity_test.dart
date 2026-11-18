// Integrity of the bundled Quran dataset (constitution, Principle I).
//
// Recomputes the table hashes and counts of assets/data/quran.db and
// compares them with assets/data/manifest.json, then checks the structural
// invariants of data-model.md section 1. Assertions use ids, keys, counts
// and hashes only.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import '../helpers/table_hash.dart';

const String _dbPath = 'assets/data/quran.db';
const String _manifestPath = 'assets/data/manifest.json';
const String _sourcesPath = 'assets/sources.json';

/// U+0020 SPACE and U+00A0 NO-BREAK SPACE, ignored by the word-join rule.
final RegExp _spaces = RegExp('[\u0020\u00A0]');
final RegExp _sha256Hex = RegExp(r'^[a-f0-9]{64}$');

int _linesOnPage(int page) => page <= 2 ? 8 : 15;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database db;
  late Map<String, Object?> manifest;

  int scalar(String sql) => db.select(sql).first.values.first! as int;

  setUpAll(() {
    db = sqlite3.open(_dbPath, mode: OpenMode.readOnly);
    manifest = jsonDecode(
      File(_manifestPath).readAsStringSync(),
    ) as Map<String, Object?>;
  });

  tearDownAll(() => db.close());

  group('manifest', () {
    test('has the schema fields and types', () {
      expect(manifest.keys.toSet(), <String>{
        'schema_version',
        'dataset_version',
        'generated_at',
        'tool_version',
        'requests',
        'counts',
        'table_hashes',
      });
      expect(manifest['schema_version'], 1);
      expect(manifest['dataset_version'], isA<int>());
      expect(manifest['dataset_version']! as int, greaterThanOrEqualTo(1));
      expect(DateTime.tryParse(manifest['generated_at']! as String), isNotNull);
      expect(manifest['tool_version'], isA<String>());
    });

    test('dataset_version equals meta.dataset_version', () {
      final ResultSet rows = db.select(
        "SELECT value FROM meta WHERE key = 'dataset_version'",
      );
      expect(rows, hasLength(1));
      expect(
        int.parse(rows.first['value'] as String),
        manifest['dataset_version'],
      );
    });

    test('records every request as https with a SHA-256', () {
      final List<Object?> requests = manifest['requests']! as List<Object?>;
      expect(requests, isNotEmpty);
      for (final Object? r in requests) {
        final Map<String, Object?> request = r! as Map<String, Object?>;
        expect(request.keys.toSet(), <String>{'url', 'sha256', 'bytes'});
        final String url = request['url']! as String;
        expect(url, startsWith('https://'));
        expect(
          _sha256Hex.hasMatch(request['sha256']! as String),
          isTrue,
          reason: 'sha256 of $url',
        );
        expect(request['bytes']! as int, greaterThanOrEqualTo(1));
      }
    });
  });

  group('table hashes and counts', () {
    test('every table hash matches the manifest', () {
      final Map<String, Object?> recorded =
          manifest['table_hashes']! as Map<String, Object?>;
      expect(
        recorded.keys.toSet(),
        hashedTables.map((HashedTable t) => t.name).toSet(),
      );
      for (final HashedTable table in hashedTables) {
        expect(
          _sha256Hex.hasMatch(recorded[table.name]! as String),
          isTrue,
          reason: 'manifest hash of ${table.name}',
        );
        expect(
          hashTable(db, table),
          recorded[table.name],
          reason: 'table ${table.name}',
        );
      }
    });

    test('every count matches the manifest', () {
      final Map<String, Object?> counts =
          manifest['counts']! as Map<String, Object?>;
      final Map<String, int> actual = <String, int>{
        'surahs': scalar('SELECT COUNT(*) FROM surahs'),
        'ayahs': scalar('SELECT COUNT(*) FROM ayahs'),
        'words': scalar('SELECT COUNT(*) FROM words'),
        'pages': scalar('SELECT COUNT(DISTINCT page) FROM page_lines'),
        'page_lines': scalar('SELECT COUNT(*) FROM page_lines'),
        'juzs': scalar('SELECT COUNT(*) FROM juzs'),
        'tafsir_texts': scalar('SELECT COUNT(*) FROM tafsir_texts'),
        'reciters': scalar('SELECT COUNT(*) FROM reciters'),
      };
      expect(counts, actual);
      expect(actual['words'], greaterThanOrEqualTo(77000));
      expect(actual['reciters'], greaterThanOrEqualTo(5));
    });
  });

  group('structural invariants', () {
    test('114 surahs, 6236 ayahs, 30 juz', () {
      expect(scalar('SELECT COUNT(*) FROM surahs'), 114);
      expect(scalar('SELECT COUNT(*) FROM ayahs'), 6236);
      expect(scalar('SELECT SUM(ayah_count) FROM surahs'), 6236);
      expect(scalar('SELECT COUNT(*) FROM juzs'), 30);
      expect(scalar('SELECT COUNT(DISTINCT juz) FROM ayahs'), 30);
    });

    test('60 hizb and 240 rub el hizb', () {
      expect(scalar('SELECT COUNT(DISTINCT hizb) FROM ayahs'), 60);
      expect(scalar('SELECT COUNT(DISTINCT rub_el_hizb) FROM ayahs'), 240);
    });

    test('604 pages and 9046 lines, 8 on pages 1 and 2, 15 elsewhere', () {
      expect(scalar('SELECT COUNT(*) FROM page_lines'), 9046);
      final Map<int, int> perPage = <int, int>{
        for (final Row r in db.select(
          'SELECT page, COUNT(*) AS n FROM page_lines GROUP BY page',
        ))
          r['page'] as int: r['n'] as int,
      };
      expect(perPage.length, 604);
      for (int page = 1; page <= 604; page++) {
        expect(perPage[page], _linesOnPage(page), reason: 'page $page');
      }
    });

    test('114 surah_name lines and 112 basmala lines', () {
      expect(
        scalar(
          "SELECT COUNT(*) FROM page_lines WHERE line_type = 'surah_name'",
        ),
        114,
      );
      expect(
        scalar("SELECT COUNT(*) FROM page_lines WHERE line_type = 'basmala'"),
        112,
      );
    });

    test('6236 tafsir rows, one per ayah, none empty', () {
      expect(scalar('SELECT COUNT(*) FROM tafsir_texts'), 6236);
      expect(scalar('SELECT COUNT(DISTINCT ayah_id) FROM tafsir_texts'), 6236);
      expect(
        scalar(
          'SELECT COUNT(*) FROM tafsir_texts '
          "WHERE text IS NULL OR length(trim(text)) = 0",
        ),
        0,
      );
    });

    test('every ayah has exactly one end word, and it is last', () {
      final List<String> bad = <String>[
        for (final Row r in db.select('''
          SELECT a.verse_key FROM ayahs a
          WHERE (SELECT COUNT(*) FROM words w
                 WHERE w.ayah_id = a.id AND w.char_type = 'end') != 1
             OR (SELECT w.char_type FROM words w WHERE w.ayah_id = a.id
                 ORDER BY w.position DESC LIMIT 1) IS NOT 'end'
          ORDER BY a.id
        '''))
          r['verse_key'] as String,
      ];
      expect(bad, isEmpty);
    });

    test('words joined per ayah equal text_qpc_hafs, ignoring spaces', () {
      final Map<int, StringBuffer> joined = <int, StringBuffer>{};
      for (final Row r in db.select(
        'SELECT ayah_id, text_qpc_hafs FROM words ORDER BY ayah_id, position',
      )) {
        (joined[r['ayah_id'] as int] ??= StringBuffer()).write(
          r['text_qpc_hafs'] as String,
        );
      }
      final List<String> mismatched = <String>[];
      int checked = 0;
      for (final Row r in db.select(
        'SELECT id, verse_key, text_qpc_hafs FROM ayahs ORDER BY id',
      )) {
        checked++;
        final String words = (joined[r['id'] as int]?.toString() ?? '')
            .replaceAll(_spaces, '');
        final String text = (r['text_qpc_hafs'] as String).replaceAll(
          _spaces,
          '',
        );
        if (words.isEmpty || words != text) {
          mismatched.add(r['verse_key'] as String);
        }
      }
      expect(checked, 6236);
      expect(mismatched, isEmpty);
    });

    test('every reciter source_id is in the sources registry', () {
      final Map<String, Object?> registry = jsonDecode(
        File(_sourcesPath).readAsStringSync(),
      ) as Map<String, Object?>;
      final Set<String> ids = <String>{
        for (final Object? s in registry['sources']! as List<Object?>)
          (s! as Map<String, Object?>)['id']! as String,
      };
      final List<String> sourceIds = <String>[
        for (final Row r in db.select('SELECT source_id FROM reciters'))
          r['source_id'] as String,
      ];
      expect(sourceIds, isNotEmpty);
      for (final String id in sourceIds) {
        expect(ids, contains(id));
      }
    });
  });

  test('both files are bundled as assets', () async {
    for (final String path in <String>[_dbPath, _manifestPath]) {
      final ByteData data = await rootBundle.load(path);
      expect(data.lengthInBytes, File(path).lengthSync(), reason: path);
    }
  });
}
