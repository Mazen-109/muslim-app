import 'package:quran_import/quran_import.dart';
import 'package:test/test.dart';

// Placeholder tokens only. \u00A0 is the no-break space, \u06DE and \u06E9
// stand for the rub el hizb and sajdah marks the source uses.
void main() {
  group('wordsMatchAyahText', () {
    test('exact join: words with spaces, U+00A0 before the end marker', () {
      expect(
        wordsMatchAyahText(['w1', 'w2', 'END1'], 'w1 w2\u00A0END1'),
        isTrue,
      );
    });

    test('a word holding U+0020 where the ayah text has U+00A0', () {
      expect(
        wordsMatchAyahText([
          '\u06DE w1',
          'w2',
          'END1',
        ], '\u06DE\u00A0w1 w2\u00A0END1'),
        isTrue,
      );
    });

    test('U+0020 before the end marker in the ayah text', () {
      expect(wordsMatchAyahText(['w1', 'w2', 'END1'], 'w1 w2 END1'), isTrue);
    });

    test('no space in the ayah text between two separate words', () {
      expect(
        wordsMatchAyahText(['w1', '\u06E9', 'END1'], 'w1\u06E9\u00A0END1'),
        isTrue,
      );
    });

    test('fails when a letter differs', () {
      expect(
        wordsMatchAyahText(['w1', 'w3', 'END1'], 'w1 w2\u00A0END1'),
        isFalse,
      );
    });

    test('fails when the end marker is not last', () {
      expect(
        wordsMatchAyahText(['w1', 'END1', 'w2'], 'w1 w2\u00A0END1'),
        isFalse,
      );
    });

    test('withoutSpaces removes only U+0020 and U+00A0', () {
      expect(withoutSpaces(' a\u00A0b\u2009c '), 'ab\u2009c');
    });
  });

  group('surahPageRangeProblems', () {
    SurahRow surah(int id, int start, int end) => SurahRow(
      id: id,
      nameAr: 'n',
      nameEn: 'N',
      revelationPlace: 'makkah',
      revelationOrder: id,
      ayahCount: 2,
      bismillahPre: 1,
      pageStart: start,
      pageEnd: end,
    );
    AyahRow ayah(int id, int surahId, int number, int page) => AyahRow(
      id: id,
      surahId: surahId,
      ayahNumber: number,
      verseKey: '$surahId:$number',
      textQpcHafs: 't',
      textUthmani: 'u',
      textSearch: 's',
      textSearchFolded: 's',
      page: page,
      juz: 1,
      hizb: 1,
      rubElHizb: 1,
      sajdah: null,
    );
    WordRow word(int id, int ayahId, int position, int page) => WordRow(
      id: id,
      ayahId: ayahId,
      position: position,
      charType: 'word',
      textQpcHafs: 'w',
      page: page,
      line: 1,
    );

    // Surah 7's name and basmala lines sit at the bottom of page 10; its
    // first word is on page 11 and its last on page 12. Word ids are not in
    // reading order.
    final ayahs = [ayah(1, 7, 1, 11), ayah(2, 7, 2, 12)];
    final words = [
      word(50, 2, 1, 12),
      word(40, 1, 1, 11),
      word(60, 1, 2, 11),
      word(30, 2, 2, 12),
    ];

    test('page_start is the page of the first word, not of the banner', () {
      expect(surahPageRangeProblems([surah(7, 11, 12)], ayahs, words), isEmpty);
    });

    test('a page_start on the banner page fails', () {
      expect(surahPageRangeProblems([surah(7, 10, 12)], ayahs, words), [
        contains('surah 7: page_start 10'),
      ]);
    });

    test('page_end is the maximum page, whatever the id order', () {
      expect(surahPageRangeProblems([surah(7, 11, 11)], ayahs, words), [
        contains('surah 7: page_end 11 but its last word is on page 12'),
      ]);
    });
  });
}
