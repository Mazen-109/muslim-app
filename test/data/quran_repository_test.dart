// QuranRepository against the real bundled database, opened directly from
// assets/data/quran.db. Assertions use ids, keys, counts and hashes only.
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muslim/data/models/ayah_ref.dart';
import 'package:muslim/data/models/mushaf_page.dart';
import 'package:muslim/data/models/word.dart';
import 'package:muslim/data/quran_database.dart';
import 'package:muslim/data/quran_repository.dart';
import 'package:sqlite3/sqlite3.dart';

String _hash(Iterable<String> values) =>
    sha256.convert(utf8.encode(values.join('\u001E'))).toString();

void main() {
  late QuranDatabase database;
  late QuranRepository repository;
  late Database db;
  late List<MushafPage> pages;

  int scalar(String sql, [List<Object?> args = const <Object?>[]]) =>
      db.select(sql, args).first.values.first! as int;

  List<int> ints(String sql, [List<Object?> args = const <Object?>[]]) => <int>[
    for (final r in db.select(sql, args)) r.values.first! as int,
  ];

  setUpAll(() {
    database = QuranDatabase.openFile(QuranDatabase.assetKey);
    db = database.db;
    repository = QuranRepository(database);
    pages = <MushafPage>[for (var n = 1; n <= 604; n++) repository.page(n)];
  });

  tearDownAll(() {
    repository.dispose();
    database.close();
  });

  List<String> lineTypes(MushafPage page) => <String>[
    for (final line in page.lines)
      switch (line) {
        AyahLine() => 'ayah',
        SurahNameLine(:final surah) => 'name ${surah.id}',
        BasmalaLine(:final surah) => 'basmala ${surah.id}',
      },
  ];

  group('counts', () {
    test('114 surahs, 6236 ayahs, 30 juz', () {
      final surahs = repository.surahs();
      expect(surahs, hasLength(114));
      expect(<int>[
        for (final s in surahs) s.id,
      ], List.generate(114, (i) => i + 1));
      expect(repository.ayahTotal, 6236);
      expect(repository.ayahCounts.fold<int>(0, (a, b) => a + b), 6236);
      expect(repository.juzs(), hasLength(30));
      var total = 0;
      for (final surah in surahs) {
        final ayahs = repository.ayahsOfSurah(surah.id);
        expect(ayahs, hasLength(surah.ayahCount), reason: 'surah ${surah.id}');
        expect(
          <String>[for (final a in ayahs) a.verseKey],
          <String>[for (var n = 1; n <= surah.ayahCount; n++) '${surah.id}:$n'],
        );
        total += ayahs.length;
      }
      expect(total, 6236);
    });

    test('surahs 1 and 9 alone have no basmala before them', () {
      expect(
        <int>[
          for (final s in repository.surahs())
            if (!s.bismillahPre) s.id,
        ],
        <int>[1, 9],
      );
    });

    test('juz ranges are contiguous and start on their pages', () {
      var next = 1;
      for (final juz in repository.juzs()) {
        expect(juz.firstAyahId, next, reason: 'juz ${juz.id}');
        expect(juz.lastAyahId, greaterThanOrEqualTo(juz.firstAyahId));
        expect(juz.pageStart, repository.pageOf(juz.firstAyahId));
        next = juz.lastAyahId + 1;
      }
      expect(next, 6237);
    });
  });

  group('ayah lookup', () {
    test('by id and by ref agree for every ayah', () {
      expect(<int>[
        for (var id = 1; id <= 6236; id++)
          if (repository.ayahIdOf(repository.refOf(id)) != id) id,
      ], isEmpty);
      final ayah = repository.ayahByRef(AyahRef(2, 255));
      expect(ayah.verseKey, '2:255');
      expect(ayah.ref, AyahRef(2, 255));
      expect(repository.ayah(ayah.id), ayah);
      expect(repository.ayah(1).verseKey, '1:1');
      expect(repository.ayah(6236).verseKey, '114:6');
    });

    test('rejects ids, refs and keys outside the data', () {
      expect(() => repository.ayah(0), throwsRangeError);
      expect(() => repository.ayah(6237), throwsRangeError);
      expect(() => repository.ayahByRef(AyahRef(1, 8)), throwsRangeError);
      expect(() => repository.surah(0), throwsRangeError);
      expect(() => repository.surah(115), throwsRangeError);
      expect(() => repository.page(0), throwsRangeError);
      expect(() => repository.page(605), throwsRangeError);
      expect(repository.parseKey('2:286'), AyahRef(2, 286));
      expect(() => repository.parseKey('2:287'), throwsFormatException);
      expect(repository.tryParseKey('114:7'), isNull);
      expect(repository.tryParseKey('114:6'), AyahRef(114, 6));
    });

    test('ayah counts come from the database', () {
      expect(
        repository.ayahCounts,
        ints('SELECT ayah_count FROM surahs ORDER BY id'),
      );
    });

    test('text_qpc_hafs is returned exactly as stored', () {
      final direct = <String>[
        for (final r in db.select(
          'SELECT text_qpc_hafs FROM ayahs ORDER BY id',
        ))
          r['text_qpc_hafs'] as String,
      ];
      final viaRepository = <String>[
        for (final s in repository.surahs())
          for (final a in repository.ayahsOfSurah(s.id)) a.textQpcHafs,
      ];
      expect(viaRepository, hasLength(6236));
      expect(_hash(viaRepository), _hash(direct));
      expect(
        sha256.convert(utf8.encode(repository.ayah(262).textQpcHafs)),
        sha256.convert(
          utf8.encode(
            db
                    .select('SELECT text_qpc_hafs FROM ayahs WHERE id = 262')
                    .single
                    .values
                    .single!
                as String,
          ),
        ),
      );
    });
  });

  group('pages', () {
    test('page 1: surah 1 name line, then 7 ayah lines', () {
      expect(pages[0].number, 1);
      expect(lineTypes(pages[0]), <String>[
        'name 1',
        ...List.filled(7, 'ayah'),
      ]);
    });

    test('page 2: surah 2 name and basmala lines, then 6 ayah lines', () {
      expect(lineTypes(pages[1]), <String>[
        'name 2',
        'basmala 2',
        ...List.filled(6, 'ayah'),
      ]);
    });

    test('page 3: 15 ayah lines', () {
      expect(lineTypes(pages[2]), List.filled(15, 'ayah'));
    });

    test('page 604: surahs 112, 113 and 114 each start mid-page', () {
      expect(lineTypes(pages[603]), <String>[
        'name 112',
        'basmala 112',
        'ayah',
        'ayah',
        'name 113',
        'basmala 113',
        'ayah',
        'ayah',
        'ayah',
        'name 114',
        'basmala 114',
        'ayah',
        'ayah',
        'ayah',
        'ayah',
      ]);
      expect(repository.surah(113).pageStart, 604);
    });

    test('line numbers and counts match page_lines', () {
      for (final page in pages) {
        final expected = page.number <= 2 ? 8 : 15;
        expect(
          <int>[for (final l in page.lines) l.number],
          List.generate(expected, (i) => i + 1),
          reason: 'page ${page.number}',
        );
      }
    });

    test('surahs whose name line is on the previous page', () {
      final ids = ints('''
        SELECT s.id FROM surahs s
        JOIN page_lines pl ON pl.surah_id = s.id AND pl.line_type = 'surah_name'
        WHERE pl.page <> s.page_start ORDER BY s.id
      ''');
      expect(ids, isNotEmpty);
      for (final id in ids) {
        final surah = repository.surah(id);
        final previous = pages[surah.pageStart - 2];
        final start = pages[surah.pageStart - 1];
        final last = previous.lines.last;
        expect(last, isA<SurahNameLine>(), reason: 'surah $id');
        expect((last as SurahNameLine).surah, surah);
        if (surah.bismillahPre) {
          final first = start.lines.first;
          expect(first, isA<BasmalaLine>(), reason: 'surah $id');
          expect((first as BasmalaLine).surah, surah);
          expect(start.lines[1], isA<AyahLine>());
        } else {
          expect(start.lines.first, isA<AyahLine>());
        }
        // The first word of ayah 1 is on page_start.
        final firstAyahId = repository.ayahIdOf(AyahRef(id, 1));
        expect(repository.pageOf(firstAyahId), surah.pageStart);
      }
    });

    test('every surah name line comes before its first ayah', () {
      var names = 0;
      var basmalas = 0;
      for (final page in pages) {
        for (final line in page.lines) {
          if (line is SurahNameLine) names++;
          if (line is BasmalaLine) basmalas++;
        }
      }
      expect(names, 114);
      expect(basmalas, 112);
    });

    test('ayah-line words cover every word exactly once, in reading order', () {
      // Problems are collected and asserted once: one expect per word is
      // far too slow for 83 thousand words.
      final problems = <String>[];
      final seen = <int>{};
      var count = 0;
      (int, int)? previous;
      for (final page in pages) {
        for (final line in page.lines.whereType<AyahLine>()) {
          if (line.words.isEmpty) problems.add('empty ${page.number}');
          for (final word in line.words) {
            count++;
            if (!seen.add(word.id)) problems.add('duplicate ${word.id}');
            if (word.page != page.number || word.line != line.number) {
              problems.add('misplaced ${word.id}');
            }
            final key = (word.ayahId, word.position);
            if (previous != null &&
                !(key.$1 > previous.$1 ||
                    (key.$1 == previous.$1 && key.$2 > previous.$2))) {
              problems.add('out of order ${word.id}');
            }
            previous = key;
          }
        }
      }
      expect(problems, isEmpty);
      expect(count, scalar('SELECT COUNT(*) FROM words'));
      // Compared as sorted lists; set matchers are quadratic.
      expect(seen.toList()..sort(), ints('SELECT id FROM words ORDER BY id'));
    });

    test('words follow (ayah_id, position), not word id', () {
      // Word ids do not follow reading order in the data, so a layout
      // ordered by id would be wrong.
      final idsInPageOrder = <int>[
        for (final page in pages)
          for (final line in page.lines.whereType<AyahLine>())
            for (final w in line.words) w.id,
      ];
      var inversions = 0;
      for (var i = 1; i < idsInPageOrder.length; i++) {
        if (idsInPageOrder[i] < idsInPageOrder[i - 1]) inversions++;
      }
      expect(inversions, greaterThan(0));
      expect(
        idsInPageOrder,
        ints('SELECT id FROM words ORDER BY ayah_id, position'),
      );
      expect(
        <int>[
          for (final line in pages[49].lines.whereType<AyahLine>())
            for (final w in line.words) w.id,
        ],
        ints('SELECT id FROM words WHERE page = 50 ORDER BY ayah_id, position'),
      );
    });

    test('word text on pages equals the stored text', () {
      final direct = <String>[
        for (final r in db.select(
          'SELECT text_qpc_hafs FROM words ORDER BY ayah_id, position',
        ))
          r['text_qpc_hafs'] as String,
      ];
      final viaPages = <String>[
        for (final page in pages)
          for (final line in page.lines.whereType<AyahLine>())
            for (final w in line.words) w.textQpcHafs,
      ];
      expect(_hash(viaPages), _hash(direct));
    });

    test('basmala words are the words of 1:1 without its end marker', () {
      final wordIds = ints(
        "SELECT id FROM words WHERE ayah_id = 1 AND char_type = 'word' "
        'ORDER BY position',
      );
      final allIds = ints(
        'SELECT id FROM words WHERE ayah_id = 1 ORDER BY position',
      );
      final endId = scalar(
        "SELECT id FROM words WHERE ayah_id = 1 AND char_type = 'end'",
      );
      expect(wordIds, allIds.sublist(0, allIds.length - 1));
      for (final page in pages) {
        for (final line in page.lines.whereType<BasmalaLine>()) {
          expect(<int>[for (final w in line.words) w.id], wordIds);
          expect(line.words.map((w) => w.id), isNot(contains(endId)));
          expect(
            line.words.every((w) => w.charType == WordCharType.word),
            isTrue,
          );
        }
      }
    });

    test('no ayah spans two pages; ayahs do span lines', () {
      // The Madinah Mushaf ends every page at the end of an ayah, so every
      // ayah's words are on the page of its first word.
      final pagesOfAyah = <int, Set<int>>{};
      final linesOfAyah = <int, Set<(int, int)>>{};
      for (final page in pages) {
        for (final line in page.lines.whereType<AyahLine>()) {
          for (final w in line.words) {
            (pagesOfAyah[w.ayahId] ??= <int>{}).add(page.number);
            (linesOfAyah[w.ayahId] ??= <(int, int)>{}).add((
              page.number,
              line.number,
            ));
          }
        }
      }
      expect(pagesOfAyah, hasLength(6236));
      expect(<int>[
        for (final entry in pagesOfAyah.entries)
          if (entry.value.length != 1 ||
              entry.value.single != repository.pageOf(entry.key))
            entry.key,
      ], isEmpty);
      // An ayah spanning two lines: 2:6, from the data, appears on two
      // consecutive ayah lines of one page.
      final spanning = repository.ayahIdOf(AyahRef(2, 6));
      final lines = linesOfAyah[spanning]!.toList()
        ..sort((a, b) => a.$2 - b.$2);
      expect(lines.length, greaterThanOrEqualTo(2));
      expect(lines.map((l) => l.$1).toSet(), hasLength(1));
      expect(
        linesOfAyah.values.where((l) => l.length > 1).length,
        scalar(
          'SELECT COUNT(*) FROM (SELECT ayah_id FROM words GROUP BY ayah_id '
          'HAVING MIN(line) <> MAX(line))',
        ),
      );
    });

    test('page of an ayah and first ayah of a page', () {
      expect(repository.pageOf(1), 1);
      expect(repository.pageOf(6236), 604);
      expect(repository.firstAyahOfPage(1).verseKey, '1:1');
      expect(repository.firstAyahOfPage(2).verseKey, '2:1');
      expect(repository.firstAyahOfPage(604).ref, AyahRef(112, 1));
      for (final page in pages) {
        final firstWord = page.lines.whereType<AyahLine>().first.words.first;
        final first = repository.firstAyahOfPage(page.number);
        expect(first.id, firstWord.ayahId, reason: 'page ${page.number}');
        expect(repository.pageOf(first.id), page.number);
      }
    });

    test('the page word query uses the page index', () {
      final plan = db
          .select(
            'EXPLAIN QUERY PLAN ${QuranRepository.pageWordsSql}',
            <Object?>[1],
          )
          .map((r) => r['detail'] as String)
          .join('\n');
      expect(plan, contains('words_page_line'));
      expect(plan, isNot(contains('SCAN words')));
      expect(plan, isNot(contains('TEMP B-TREE')));
    });

    test('pages have value equality', () {
      expect(repository.page(300), pages[299]);
      expect(repository.page(300).hashCode, pages[299].hashCode);
      expect(pages[299], isNot(pages[300]));
    });
  });
}
