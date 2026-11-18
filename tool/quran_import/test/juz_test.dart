import 'package:quran_import/quran_import.dart';
import 'package:test/test.dart';

/// 30 contiguous synthetic ranges over [total] verse ids.
List<Juz> ranges(int total) {
  final size = total ~/ 30;
  return [
    for (var n = 1; n <= 30; n++)
      Juz(
        juzNumber: n,
        firstVerseId: (n - 1) * size + 1,
        lastVerseId: n == 30 ? total : n * size,
      ),
  ];
}

void main() {
  test('de-duplicates each juz listed twice and sorts by number', () {
    final rows = [...ranges(300).reversed, ...ranges(300)];
    expect(rows, hasLength(60));
    final juzs = dedupeJuzs(rows, ayahCount: 300);
    expect(juzs.map((j) => j.juzNumber), List.generate(30, (i) => i + 1));
    expect(juzs.first.firstVerseId, 1);
    expect(juzs.last.lastVerseId, 300);
  });

  test('fails when duplicates disagree', () {
    final rows = [
      ...ranges(300),
      Juz(juzNumber: 4, firstVerseId: 31, lastVerseId: 41),
    ];
    expect(
      () => dedupeJuzs(rows, ayahCount: 300),
      throwsA(isA<ImportException>()),
    );
  });

  test('fails with 29 juz', () {
    expect(
      () => dedupeJuzs(ranges(300).take(29).toList(), ayahCount: 300),
      throwsA(isA<ImportException>()),
    );
  });

  test('fails on a gap between ranges', () {
    final rows = ranges(300);
    rows[5] = Juz(
      juzNumber: 6,
      firstVerseId: rows[5].firstVerseId + 1,
      lastVerseId: rows[5].lastVerseId,
    );
    expect(
      () => dedupeJuzs(rows, ayahCount: 300),
      throwsA(isA<ImportException>()),
    );
  });

  test('fails when coverage ends early', () {
    expect(
      () => dedupeJuzs(ranges(300), ayahCount: 301),
      throwsA(isA<ImportException>()),
    );
  });
}
