import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:quran_import/quran_import.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

void main() {
  group('hashRows', () {
    test('matches a hand-computed value', () {
      // sha256 of "1␟a␟␞2␟b␟-3" (␟ = U+001F, ␞ = U+001E), UTF-8.
      expect(
        hashRows([
          [1, 'a', null],
          [2, 'b', -3],
        ]),
        '96ace9a84e7d72f641524bdb0c1e9cb7c1848795a43ff45546bda94f81025ead',
      );
    });

    test('encodes text as UTF-8', () {
      // sha256 of "7␟<U+0628>␞8␟".
      expect(
        hashRows([
          [7, '\u0628'],
          [8, null],
        ]),
        '4ff4b3c98f554020b74ecce47fe6985065c180c44efef20602343e515a294f9b',
      );
    });

    test('an empty table hashes the empty string', () {
      expect(
        hashRows(const []),
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      );
    });

    test('rejects other value types', () {
      expect(
        () => hashRows([
          [1.5],
        ]),
        throwsA(isA<ImportException>()),
      );
    });
  });

  test('hashTable reads columns in declared order and rows in key order', () {
    final db = sqlite3.openInMemory();
    addTearDown(db.close);
    db.execute(
      'CREATE TABLE page_lines (page INTEGER, line INTEGER, line_type TEXT, '
      'surah_id INTEGER, PRIMARY KEY (page, line))',
    );
    db.execute(
      "INSERT INTO page_lines VALUES (2, 1, 'ayah', NULL), "
      "(1, 2, 'ayah', NULL), (1, 1, 'surah_name', 1)",
    );
    final spec = hashedTables.firstWhere((t) => t.name == 'page_lines');
    expect(
      hashTable(db, spec),
      hashRows([
        [1, 1, 'surah_name', 1],
        [1, 2, 'ayah', null],
        [2, 1, 'ayah', null],
      ]),
    );
  });

  test('hashed tables follow data-model.md column order', () {
    expect(hashedTables.map((t) => t.name), [
      'surahs',
      'ayahs',
      'words',
      'page_lines',
      'juzs',
      'tafsirs',
      'tafsir_texts',
      'reciters',
    ]);
    final ayahs = hashedTables.firstWhere((t) => t.name == 'ayahs');
    expect(ayahs.columns.first, 'id');
    expect(ayahs.columns.last, 'sajdah');
  });

  test('writeDatabase stores rows unaltered and hashes match', () {
    final dir = Directory.systemTemp.createTempSync('quran_import_test');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = p.join(dir.path, 'test.db');
    final dataset = Dataset(
      surahs: [
        SurahRow(
          id: 1,
          nameAr: 'n1',
          nameEn: 'N1',
          revelationPlace: 'makkah',
          revelationOrder: 1,
          ayahCount: 1,
          bismillahPre: 0,
          pageStart: 1,
          pageEnd: 1,
        ),
      ],
      ayahs: [
        AyahRow(
          id: 1,
          surahId: 1,
          ayahNumber: 1,
          verseKey: '1:1',
          textQpcHafs: ' w1 w2\u00A0END1 ',
          textUthmani: 'u1',
          textSearch: 's1',
          textSearchFolded: 's1',
          page: 1,
          juz: 1,
          hizb: 1,
          rubElHizb: 1,
          sajdah: null,
        ),
      ],
      words: [
        WordRow(
          id: 1,
          ayahId: 1,
          position: 1,
          charType: 'word',
          textQpcHafs: ' w1',
          page: 1,
          line: 2,
        ),
        WordRow(
          id: 2,
          ayahId: 1,
          position: 2,
          charType: 'end',
          textQpcHafs: 'END1',
          page: 1,
          line: 2,
        ),
      ],
      pageLines: [
        PageLineRow(const PageLine(1, 1, lineTypeSurahName, 1)),
        PageLineRow(const PageLine(1, 2, lineTypeAyah, null)),
      ],
      juzs: [JuzRow(id: 1, firstAyahId: 1, lastAyahId: 1, pageStart: 1)],
      tafsirs: [
        TafsirRow(id: 16, nameAr: 't', author: 'a', language: 'l', slug: 's'),
      ],
      tafsirTexts: [TafsirTextRow(tafsirId: 16, ayahId: 1, text: 'T1')],
      reciters: [
        ReciterRow(
          id: 12,
          nameAr: 'r',
          nameEn: 'R',
          style: 'muallim',
          urlTemplate: 'https://h/{surah3}{ayah3}.mp3',
          sourceId: 'everyayah',
          sortOrder: 1,
        ),
      ],
    );
    writeDatabase(path, dataset, {'dataset_version': '1'});
    final db = sqlite3.open(path, mode: OpenMode.readOnly);
    addTearDown(db.close);
    final hashes = hashAllTables(db);
    for (final MapEntry(key: table, value: rows) in dataset.tables.entries) {
      expect(hashes[table], hashRows(rows.map((r) => r.values)), reason: table);
    }
    expect(
      db.select('SELECT text_qpc_hafs FROM ayahs').single.values.single,
      ' w1 w2\u00A0END1 ',
    );
    expect(db.select('SELECT value FROM meta').single.values.single, '1');
    expect(countRows(db)['page_lines'], 2);
  });
}
