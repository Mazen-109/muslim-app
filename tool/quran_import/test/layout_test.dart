import 'package:quran_import/quran_import.dart';
import 'package:test/test.dart';

/// Builds a synthetic Mushaf of [pageCount] pages from per-surah word lines.
///
/// [placement] maps surah id to a list of ayahs, each ayah a list of
/// (page, line) positions, one per word. Word ids follow reading order
/// unless [idOf] maps the reading index to another id.
List<LayoutWord> buildWords(
  Map<int, List<List<(int, int)>>> placement, {
  int Function(int readingIndex)? idOf,
}) {
  var index = 0;
  var ayahId = 0;
  final words = <LayoutWord>[];
  for (final MapEntry(key: surah, value: ayahs) in placement.entries) {
    for (final (ai, positions) in ayahs.indexed) {
      ayahId++;
      for (final (wi, (page, line)) in positions.indexed) {
        words.add(
          LayoutWord(
            id: idOf == null ? index + 1 : idOf(index),
            ayahId: ayahId,
            surah: surah,
            ayah: ai + 1,
            position: wi + 1,
            page: page,
            line: line,
          ),
        );
        index++;
      }
    }
  }
  return words;
}

/// One ayah filling lines [from]..[to] of [page], one word per line.
List<(int, int)> lines(int page, int from, int to) => [
  for (var l = from; l <= to; l++) (page, l),
];

const s = LayoutSurah.new;

void main() {
  test('linesOnPage: 8 on pages 1 and 2, 15 elsewhere', () {
    expect([1, 2, 3, 604].map(linesOnPage), [8, 8, 15, 15]);
  });

  // A 5-page synthetic Mushaf:
  // page 1 (8 lines): surah 1 name on line 1 (no basmala), ayahs lines 2..8
  // page 2 (8 lines): surah 2 name line 1, basmala line 2, ayahs 3..8
  // page 3 (15): surah 2 continues lines 1..6; surah 3 starts mid-page:
  //              name line 7, basmala line 8, ayahs 9..14; surah 4 name on
  //              line 15 (bottom of the page)
  // page 4 (15): surah 4 basmala line 1, ayahs 2..12; surah 5 (no basmala,
  //              like surah 9) name line 13, ayahs 14..15
  // page 5 (15): surah 5 ayahs 1..15
  final placement = <int, List<List<(int, int)>>>{
    1: [lines(1, 2, 4), lines(1, 5, 8)],
    2: [lines(2, 3, 8), lines(3, 1, 6)],
    3: [lines(3, 9, 14)],
    4: [lines(4, 2, 12)],
    5: [lines(4, 14, 15), lines(5, 1, 15)],
  };
  final surahs = [
    s(id: 1, bismillahPre: false),
    s(id: 2, bismillahPre: true),
    s(id: 3, bismillahPre: true),
    s(id: 4, bismillahPre: true),
    s(id: 5, bismillahPre: false),
  ];

  group('derivePageLines on a valid layout', () {
    final result = derivePageLines(
      words: buildWords(placement),
      surahs: surahs,
      pageCount: 5,
    );
    PageLine at(int page, int line) =>
        result.firstWhere((l) => l.page == page && l.line == line);

    test('pages 1 and 2 have 8 lines, the rest 15', () {
      for (final (page, n) in [(1, 8), (2, 8), (3, 15), (4, 15), (5, 15)]) {
        expect(result.where((l) => l.page == page), hasLength(n));
      }
      expect(result, hasLength(8 + 8 + 15 * 3));
    });

    test('surah 1 has a name line and no basmala line', () {
      expect(at(1, 1), const PageLine(1, 1, lineTypeSurahName, 1));
      expect(at(1, 2), const PageLine(1, 2, lineTypeAyah, null));
    });

    test('surah 2 on page 2: name, basmala, ayahs', () {
      expect(at(2, 1), const PageLine(2, 1, lineTypeSurahName, 2));
      expect(at(2, 2), const PageLine(2, 2, lineTypeBasmala, 2));
      expect(at(2, 3).lineType, lineTypeAyah);
    });

    test('a surah starting mid-page', () {
      expect(at(3, 6).lineType, lineTypeAyah);
      expect(at(3, 7), const PageLine(3, 7, lineTypeSurahName, 3));
      expect(at(3, 8), const PageLine(3, 8, lineTypeBasmala, 3));
      expect(at(3, 9).lineType, lineTypeAyah);
    });

    test('banner at the bottom of a page, basmala at the top of the next', () {
      expect(at(3, 15), const PageLine(3, 15, lineTypeSurahName, 4));
      expect(at(4, 1), const PageLine(4, 1, lineTypeBasmala, 4));
      expect(at(4, 2).lineType, lineTypeAyah);
    });

    test('a surah without bismillah_pre mid-page owns one line', () {
      expect(at(4, 12).lineType, lineTypeAyah);
      expect(at(4, 13), const PageLine(4, 13, lineTypeSurahName, 5));
      expect(at(4, 14).lineType, lineTypeAyah);
    });

    test('word ids out of reading order derive the same layout', () {
      final words = buildWords(placement);
      // Reverse the ids and swap neighbours, so id order matches neither
      // reading order nor its reverse.
      final scrambled = buildWords(
        placement,
        idOf: (i) => 10000 - (i.isEven ? i + 1 : i - 1),
      );
      expect(scrambled.map((w) => w.id).toSet(), hasLength(words.length));
      expect(
        derivePageLines(words: scrambled, surahs: surahs, pageCount: 5),
        result,
      );
    });

    test('counts of name and basmala lines', () {
      expect(
        result.where((l) => l.lineType == lineTypeSurahName),
        hasLength(5),
      );
      expect(result.where((l) => l.lineType == lineTypeBasmala), hasLength(3));
    });
  });

  group('derivePageLines fails on a mismatch', () {
    void expectFailure(
      Map<int, List<List<(int, int)>>> placement,
      List<LayoutSurah> surahs,
      Matcher message,
    ) {
      expect(
        () => derivePageLines(
          words: buildWords(placement),
          surahs: surahs,
          pageCount: 5,
        ),
        throwsA(
          isA<ImportException>().having((e) => e.message, 'message', message),
        ),
      );
    }

    test('basmala surah with only one empty line before it', () {
      final bad = {
        ...placement,
        3: [lines(3, 8, 14)],
      };
      expectFailure(bad, surahs, contains('surah 3: expected 2 empty line(s)'));
    });

    test('surah without bismillah_pre preceded by two empty lines', () {
      final bad = {
        ...placement,
        5: [lines(4, 15, 15), lines(5, 1, 15)],
      };
      expectFailure(bad, surahs, contains('surah 5: expected 1 empty line'));
    });

    test('three empty lines before a basmala surah', () {
      final bad = {
        ...placement,
        2: [lines(2, 3, 8), lines(3, 1, 5)],
      };
      expectFailure(bad, surahs, contains('surah 3: expected 2'));
    });

    test('an empty line that precedes no surah start', () {
      final bad = {
        ...placement,
        5: [lines(4, 14, 15), lines(5, 1, 14)],
      };
      expectFailure(bad, surahs, contains('page 5 line 15 has no words'));
    });

    test('a word on line 9 of an 8-line page', () {
      final bad = {
        ...placement,
        1: [lines(1, 2, 4), lines(1, 5, 9)],
      };
      expectFailure(bad, surahs, contains('page 1, which has 8 lines'));
    });

    test('reading order going back to an earlier line', () {
      final bad = {
        ...placement,
        1: [
          lines(1, 2, 4),
          [(1, 8), (1, 5), (1, 6), (1, 7)],
        ],
      };
      expectFailure(bad, surahs, contains('is placed before it'));
    });

    test('a surah starting mid-line', () {
      final bad = {
        ...placement,
        3: [
          [(3, 6), ...lines(3, 9, 14)],
        ],
        2: [lines(2, 3, 8), lines(3, 1, 6)],
      };
      expectFailure(bad, surahs, contains('surah 3 starts mid-line'));
    });
  });
}
