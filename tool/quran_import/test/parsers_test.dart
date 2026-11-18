import 'package:quran_import/quran_import.dart';
import 'package:test/test.dart';

import 'fixtures.dart';

void main() {
  group('parseChapters', () {
    test('reads every field', () {
      final chapters = parseChapters({
        'chapters': [
          {
            'id': 9,
            'revelation_place': 'madinah',
            'revelation_order': 113,
            'bismillah_pre': false,
            'name_simple': 'Name-Nine',
            'name_complex': 'Name-Nine',
            'name_arabic': 'n9',
            'verses_count': 129,
            'pages': [187, 207],
            'translated_name': {'language_name': 'arabic', 'name': 'tn9'},
          },
        ],
      });
      final c = chapters.single;
      expect(c.id, 9);
      expect(c.revelationPlace, 'madinah');
      expect(c.revelationOrder, 113);
      expect(c.bismillahPre, isFalse);
      expect(c.nameSimple, 'Name-Nine');
      expect(c.nameArabic, 'n9');
      expect(c.versesCount, 129);
      expect((c.pageStart, c.pageEnd), (187, 207));
    });

    test('rejects a wrongly typed field', () {
      expect(
        () => parseChapters({
          'chapters': [
            {
              'id': '1',
              'revelation_place': 'makkah',
              'revelation_order': 5,
              'bismillah_pre': false,
              'name_simple': 'x',
              'name_arabic': 'y',
              'verses_count': 7,
              'pages': [1, 1],
            },
          ],
        }),
        throwsA(isA<ImportException>()),
      );
    });
  });

  group('parseVersesByPage', () {
    test('reads verses and words without altering text', () {
      const spaced = ' w1  w2 ';
      final verses = parseVersesByPage({
        'verses': [
          verseJson(
            id: 8,
            key: '2:1',
            page: 2,
            sajdah: null,
            text: spaced,
            words: [
              wordJson(30, 1, 'word', ' w1', page: 2, line: 3),
              wordJson(31, 2, 'end', 'END1 ', page: 2, line: 3),
            ],
          ),
        ],
        'pagination': pagination(),
      }, 2);
      final v = verses.single;
      expect(v.id, 8);
      expect(v.verseKey, '2:1');
      expect(v.verseNumber, 1);
      expect(v.textQpcHafs, spaced);
      expect(v.textUthmani, 'u1 u2 U-END1');
      expect(v.textImlaeiSimple, 's1 s2');
      expect(v.sajdah, isNull);
      expect(v.words.map((w) => w.text), [' w1', 'END1 ']);
      expect(v.words.map((w) => w.charType), ['word', 'end']);
      expect(v.words.first.line, 3);
      expect(v.words.first.page, 2);
    });

    test('uses v1_page and line_v1, never page_number', () {
      final verses = parseVersesByPage({
        'verses': [
          verseJson(
            id: 9,
            key: '5:77',
            page: 120,
            words: [
              wordJson(1, 1, 'word', 'w1', page: 121, line: 1, pageNumber: 120),
              wordJson(2, 2, 'end', 'END1', page: 121, line: 1),
            ],
          ),
        ],
        'pagination': pagination(),
      }, 121);
      expect(verses.single.words.map((w) => (w.page, w.line)), [
        (121, 1),
        (121, 1),
      ]);
    });

    test('fails when line_number differs from line_v1', () {
      expect(
        () => parseVersesByPage({
          'verses': [
            verseJson(
              id: 1,
              key: '1:1',
              page: 1,
              words: [
                wordJson(1, 1, 'word', 'w1', page: 1, line: 2, lineV1: 3),
                wordJson(2, 2, 'end', 'END1', page: 1, line: 3),
              ],
            ),
          ],
          'pagination': pagination(),
        }, 1),
        throwsA(
          isA<ImportException>().having(
            (e) => e.message,
            'message',
            contains('line_number 2 differs from line_v1 3'),
          ),
        ),
      );
    });

    test('fails when a verse does not start on the requested page', () {
      expect(
        () => parseVersesByPage({
          'verses': [
            verseJson(
              id: 1,
              key: '3:4',
              page: 50,
              words: [
                wordJson(1, 1, 'word', 'w1', page: 50, line: 15),
                wordJson(2, 2, 'end', 'END1', page: 51, line: 1),
              ],
            ),
          ],
          'pagination': pagination(),
        }, 51),
        throwsA(
          isA<ImportException>().having(
            (e) => e.message,
            'message',
            contains('verse 3:4 starts on page 50'),
          ),
        ),
      );
    });

    test('accepts a verse whose later words continue on the next page', () {
      final verses = parseVersesByPage({
        'verses': [
          verseJson(
            id: 1,
            key: '3:4',
            page: 50,
            words: [
              wordJson(1, 1, 'word', 'w1', page: 50, line: 15),
              wordJson(2, 2, 'end', 'END1', page: 51, line: 1),
            ],
          ),
        ],
        'pagination': pagination(),
      }, 50);
      expect(verses.single.words.last.page, 51);
    });

    test('fails when the page response is paginated', () {
      expect(
        () => parseVersesByPage({
          'verses': <Object?>[],
          'pagination': pagination(next: 2),
        }, 5),
        throwsA(isA<ImportException>()),
      );
    });

    test('fails when sajdah_number is missing', () {
      final v = verseJson(id: 1, key: '1:1', page: 1, words: [])
        ..remove('sajdah_number');
      expect(
        () => parseVersesByPage({
          'verses': [v],
          'pagination': pagination(),
        }, 1),
        throwsA(isA<ImportException>()),
      );
    });
  });

  test('parseJuzs reads numbers and ranges', () {
    final juzs = parseJuzs({
      'juzs': [
        {
          'id': 61,
          'juz_number': 1,
          'verse_mapping': {'1': '1-7'},
          'first_verse_id': 1,
          'last_verse_id': 148,
          'verses_count': 148,
        },
      ],
    });
    expect(juzs.single.juzNumber, 1);
    expect(juzs.single.firstVerseId, 1);
    expect(juzs.single.lastVerseId, 148);
  });

  test('parseTafsirResource takes the Arabic translated name', () {
    final t = parseTafsirResource({
      'tafsirs': [
        {
          'id': 15,
          'name': 'Other',
          'author_name': 'a15',
          'slug': 's15',
          'language_name': 'arabic',
          'translated_name': {'name': 't15', 'language_name': 'arabic'},
        },
        {
          'id': 16,
          'name': 'Latin name',
          'author_name': 'a16',
          'slug': 'slug-16',
          'language_name': 'arabic',
          'translated_name': {'name': 't16', 'language_name': 'arabic'},
        },
      ],
    }, 16);
    expect(
      (t.id, t.nameAr, t.author, t.language, t.slug),
      (16, 't16', 'a16', 'arabic', 'slug-16'),
    );
  });

  test('parseTafsirPage reads entries and next_page', () {
    final page = parseTafsirPage({
      'tafsirs': [
        {
          'id': 1,
          'resource_id': 16,
          'verse_key': '1:1',
          'language_id': 9,
          'text': 'T1',
          'slug': 'slug-16',
        },
      ],
      'pagination': pagination(next: 2),
    }, 'ctx');
    expect(page.nextPage, 2);
    expect(page.items.single.verseKey, '1:1');
    expect(page.items.single.text, 'T1');
    expect(page.items.single.resourceId, 16);
  });

  test('parseRecitations picks the requested ids and fails on a gap', () {
    final json = {
      'recitations': [
        {
          'id': 12,
          'reciter_name': 'Reciter A',
          'style': 'Muallim',
          'translated_name': {'name': 'ra', 'language_name': 'arabic'},
        },
        {
          'id': 7,
          'reciter_name': 'Reciter B',
          'style': null,
          'translated_name': {'name': 'rb', 'language_name': 'arabic'},
        },
      ],
    };
    final r = parseRecitations(json, [12, 7]);
    expect(r[12]!.style, 'Muallim');
    expect(r[7]!.style, isNull);
    expect(r[7]!.nameAr, 'rb');
    expect(r[7]!.reciterName, 'Reciter B');
    expect(
      () => parseRecitations(json, [12, 7, 2]),
      throwsA(isA<ImportException>()),
    );
  });

  test('parseAudioPage reads verse keys and urls', () {
    final page = parseAudioPage({
      'audio_files': [
        {'verse_key': '1:1', 'url': 'Folder/mp3/001001.mp3'},
      ],
      'pagination': pagination(),
    }, 'ctx');
    expect(page.nextPage, isNull);
    expect(page.items.single.url, 'Folder/mp3/001001.mp3');
  });

  group('mergeVerses', () {
    Verse v(List<Word> words) => Verse(
      id: 10,
      verseNumber: 3,
      verseKey: '2:3',
      hizb: 1,
      rubElHizb: 1,
      sajdah: null,
      juz: 1,
      textQpcHafs: 'w1 w2\u00A0END1',
      textUthmani: 'u',
      textImlaeiSimple: 's',
      words: words,
    );
    Word w(int id, int pos, int page, {String text = 'w'}) => Word(
      id: id,
      position: pos,
      charType: 'word',
      text: text,
      page: page,
      line: 1,
    );

    test('de-duplicates a verse returned by two pages and unions words', () {
      final merged = mergeVerses([
        [
          v([w(1, 1, 2), w(2, 2, 2)]),
        ],
        [
          v([w(2, 2, 2), w(3, 3, 3)]),
        ],
      ]);
      expect(merged.single.words.map((x) => x.id), [1, 2, 3]);
    });

    test('fails when a word differs between pages', () {
      expect(
        () => mergeVerses([
          [
            v([w(1, 1, 2)]),
          ],
          [
            v([w(1, 1, 2, text: 'other')]),
          ],
        ]),
        throwsA(isA<ImportException>()),
      );
    });
  });
}
