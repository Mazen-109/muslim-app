/// Every invariant of data-model.md section 1 and every count of
/// contracts/dataset-manifest.schema.json.
library;

import 'dataset.dart';
import 'errors.dart';
import 'layout.dart';
import 'reciters.dart';

const expectedSurahs = 114;
const expectedAyahs = 6236;
const expectedPages = 604;
const expectedPageLines = 9046;
const expectedJuzs = 30;
const expectedHizbs = 60;
const expectedRubs = 240;
const minimumWords = 77000;
const minimumReciters = 5;
const expectedSurahNameLines = 114;
const expectedBasmalaLines = 112;

final _spaces = RegExp('[\u0020\u00A0]');

/// Removes every U+0020 SPACE and U+00A0 NO-BREAK SPACE from [text].
///
/// Used only to compare texts in the word-join invariant; stored text is
/// never changed.
String withoutSpaces(String text) => text.replaceAll(_spaces, '');

/// The word-join invariant of data-model.md section 1: the ayah's word
/// texts (in position order, end marker last), concatenated with every
/// U+0020 and U+00A0 removed, equal [ayahText] with every U+0020 and U+00A0
/// removed.
///
/// Spaces are excluded because the source places them inconsistently: an
/// ayah that opens with the rub el hizb mark has U+0020 inside that word but
/// U+00A0 in the ayah text; a few ayahs have U+0020 before the end marker;
/// and a few have no space in the ayah text between two separate words.
bool wordsMatchAyahText(List<String> wordTexts, String ayahText) =>
    withoutSpaces(wordTexts.join()) == withoutSpaces(ayahText);

/// Checks every invariant and throws one [ImportException] listing all
/// violations (the first 200) if any fails.
void validateDataset(Dataset d) {
  final problems = <String>[];
  void expect(bool ok, String Function() message) {
    if (!ok) problems.add(message());
  }

  // ---- surahs
  expect(
    d.surahs.length == expectedSurahs,
    () => 'surahs: ${d.surahs.length} rows, expected $expectedSurahs',
  );
  final orders = <int>{};
  var ayahSum = 0;
  for (final (i, s) in d.surahs.indexed) {
    expect(s.id == i + 1, () => 'surahs: row $i has id ${s.id}');
    expect(
      s.revelationPlace == 'makkah' || s.revelationPlace == 'madinah',
      () => 'surah ${s.id}: revelation_place "${s.revelationPlace}"',
    );
    expect(
      s.revelationOrder >= 1 && s.revelationOrder <= expectedSurahs,
      () => 'surah ${s.id}: revelation_order ${s.revelationOrder}',
    );
    orders.add(s.revelationOrder);
    ayahSum += s.ayahCount;
    final noBasmala = s.id == 1 || s.id == 9;
    expect(
      s.bismillahPre == (noBasmala ? 0 : 1),
      () => 'surah ${s.id}: bismillah_pre ${s.bismillahPre}',
    );
    expect(
      s.pageStart >= 1 && s.pageStart <= expectedPages,
      () => 'surah ${s.id}: page_start ${s.pageStart}',
    );
    expect(
      s.pageEnd >= s.pageStart && s.pageEnd <= expectedPages,
      () => 'surah ${s.id}: page_end ${s.pageEnd} (page_start ${s.pageStart})',
    );
    expect(s.nameAr.isNotEmpty, () => 'surah ${s.id}: empty name_ar');
    expect(s.nameEn.isNotEmpty, () => 'surah ${s.id}: empty name_en');
  }
  expect(
    orders.length == expectedSurahs,
    () => 'surahs: revelation_order values are not unique',
  );
  expect(
    ayahSum == expectedAyahs,
    () => 'surahs: ayah_count sums to $ayahSum, expected $expectedAyahs',
  );

  // ---- ayahs
  expect(
    d.ayahs.length == expectedAyahs,
    () => 'ayahs: ${d.ayahs.length} rows, expected $expectedAyahs',
  );
  final surahById = {for (final s in d.surahs) s.id: s};
  final sajdahs = <int>[];
  final hizbs = <int>{};
  final rubs = <int>{};
  final juzOfAyah = <int, int>{};
  final ayahById = <int, AyahRow>{};
  AyahRow? prev;
  for (final (i, a) in d.ayahs.indexed) {
    ayahById[a.id] = a;
    juzOfAyah[a.id] = a.juz;
    expect(a.id == i + 1, () => 'ayahs: row $i has id ${a.id}');
    expect(
      a.verseKey == '${a.surahId}:${a.ayahNumber}',
      () =>
          'ayah ${a.id}: verse_key ${a.verseKey} does not match '
          '${a.surahId}:${a.ayahNumber}',
    );
    final s = surahById[a.surahId];
    expect(s != null, () => 'ayah ${a.verseKey}: unknown surah');
    if (s != null) {
      expect(
        a.ayahNumber >= 1 && a.ayahNumber <= s.ayahCount,
        () => 'ayah ${a.verseKey}: ayah_number outside 1..${s.ayahCount}',
      );
    }
    if (prev == null) {
      expect(
        a.surahId == 1 && a.ayahNumber == 1,
        () => 'ayahs: first ayah is ${a.verseKey}, expected 1:1',
      );
    } else {
      final next = a.surahId == prev.surahId
          ? a.ayahNumber == prev.ayahNumber + 1
          : a.surahId == prev.surahId + 1 &&
                a.ayahNumber == 1 &&
                prev.ayahNumber == surahById[prev.surahId]?.ayahCount;
      expect(
        next,
        () =>
            'ayahs: ${a.verseKey} (id ${a.id}) does not follow '
            '${prev!.verseKey} in Mushaf order',
      );
      expect(
        a.page >= prev.page &&
            a.juz >= prev.juz &&
            a.hizb >= prev.hizb &&
            a.rubElHizb >= prev.rubElHizb,
        () =>
            'ayah ${a.verseKey}: page/juz/hizb/rub_el_hizb decrease '
            'relative to ${prev!.verseKey}',
      );
    }
    for (final (name, text) in [
      ('text_qpc_hafs', a.textQpcHafs),
      ('text_uthmani', a.textUthmani),
      ('text_search', a.textSearch),
      ('text_search_folded', a.textSearchFolded),
    ]) {
      expect(text.isNotEmpty, () => 'ayah ${a.verseKey}: empty $name');
    }
    expect(
      a.page >= 1 && a.page <= expectedPages,
      () => 'ayah ${a.verseKey}: page ${a.page}',
    );
    expect(
      a.juz >= 1 && a.juz <= expectedJuzs,
      () => 'ayah ${a.verseKey}: juz ${a.juz}',
    );
    expect(
      a.hizb >= 1 && a.hizb <= expectedHizbs,
      () => 'ayah ${a.verseKey}: hizb ${a.hizb}',
    );
    expect(
      a.rubElHizb >= 1 && a.rubElHizb <= expectedRubs,
      () => 'ayah ${a.verseKey}: rub_el_hizb ${a.rubElHizb}',
    );
    expect(
      a.hizb == (a.rubElHizb - 1) ~/ 4 + 1,
      () =>
          'ayah ${a.verseKey}: hizb ${a.hizb} does not contain rub_el_hizb '
          '${a.rubElHizb}',
    );
    expect(
      a.juz == (a.hizb - 1) ~/ 2 + 1,
      () => 'ayah ${a.verseKey}: juz ${a.juz} does not contain hizb ${a.hizb}',
    );
    hizbs.add(a.hizb);
    rubs.add(a.rubElHizb);
    if (a.sajdah != null) sajdahs.add(a.sajdah!);
    prev = a;
  }
  expect(
    hizbs.length == expectedHizbs,
    () =>
        'ayahs: ${hizbs.length} distinct hizb values, expected '
        '$expectedHizbs',
  );
  expect(
    rubs.length == expectedRubs,
    () =>
        'ayahs: ${rubs.length} distinct rub_el_hizb values, expected '
        '$expectedRubs',
  );
  for (final (i, n) in sajdahs.indexed) {
    expect(
      n == i + 1,
      () =>
          'ayahs: sajdah numbers are not 1..${sajdahs.length} in order: '
          '$sajdahs',
    );
  }
  for (final s in d.surahs) {
    final count = d.ayahs.where((a) => a.surahId == s.id).length;
    expect(
      count == s.ayahCount,
      () =>
          'surah ${s.id}: $count ayahs imported, ayah_count '
          '${s.ayahCount}',
    );
  }
  // ---- words
  expect(
    d.words.length >= minimumWords,
    () => 'words: ${d.words.length} rows, expected at least $minimumWords',
  );
  final wordsByAyah = <int, List<WordRow>>{};
  final wordIds = <int>{};
  for (final w in d.words) {
    expect(wordIds.add(w.id), () => 'words: duplicate id ${w.id}');
    expect(
      ayahById.containsKey(w.ayahId),
      () => 'word ${w.id}: unknown ayah_id ${w.ayahId}',
    );
    expect(
      w.charType == 'word' || w.charType == 'end',
      () => 'word ${w.id}: char_type "${w.charType}"',
    );
    expect(w.textQpcHafs.isNotEmpty, () => 'word ${w.id}: empty text');
    expect(
      w.page >= 1 && w.page <= expectedPages,
      () => 'word ${w.id}: page ${w.page}',
    );
    expect(
      w.line >= 1 && w.line <= linesOnPage(w.page),
      () => 'word ${w.id}: line ${w.line} on page ${w.page}',
    );
    (wordsByAyah[w.ayahId] ??= []).add(w);
  }
  final joinFailures = <String>[];
  for (final a in d.ayahs) {
    final ws = [...?wordsByAyah[a.id]]
      ..sort((x, y) => x.position.compareTo(y.position));
    if (ws.isEmpty) {
      problems.add('ayah ${a.verseKey}: no words');
      continue;
    }
    var contiguous = true;
    for (final (i, w) in ws.indexed) {
      if (w.position != i + 1) contiguous = false;
    }
    expect(
      contiguous,
      () =>
          'ayah ${a.verseKey}: word positions are '
          '${ws.map((w) => w.position).toList()}, expected 1..${ws.length}',
    );
    final ends = ws.where((w) => w.charType == 'end').length;
    expect(
      ends == 1 && ws.last.charType == 'end',
      () =>
          'ayah ${a.verseKey}: $ends end marker(s); the end marker must be '
          'exactly one and last',
    );
    expect(
      ws.first.page == a.page,
      () =>
          'ayah ${a.verseKey}: page ${a.page} but first word on page '
          '${ws.first.page}',
    );
    if (ends == 1 && ws.last.charType == 'end') {
      final texts = [for (final w in ws) w.textQpcHafs];
      if (!wordsMatchAyahText(texts, a.textQpcHafs)) {
        joinFailures.add(a.verseKey);
        final joined = withoutSpaces(texts.join());
        final text = withoutSpaces(a.textQpcHafs);
        problems.add(
          'ayah ${a.verseKey}: joined words differ from text_qpc_hafs '
          'ignoring spaces (${_describeDifference(joined, text)})',
        );
      }
    }
  }

  // ---- page_lines
  expect(
    d.pageLines.length == expectedPageLines,
    () =>
        'page_lines: ${d.pageLines.length} rows, expected '
        '$expectedPageLines',
  );
  final linesPerPage = <int, int>{};
  final wordLines = <(int, int)>{for (final w in d.words) (w.page, w.line)};
  final surahNameOf = <int, int>{};
  final basmalaOf = <int, int>{};
  for (final r in d.pageLines) {
    final l = r.line;
    linesPerPage[l.page] = (linesPerPage[l.page] ?? 0) + 1;
    final hasWords = wordLines.contains((l.page, l.line));
    switch (l.lineType) {
      case lineTypeAyah:
        expect(
          hasWords && l.surahId == null,
          () =>
              'page ${l.page} line ${l.line}: ayah line without words or '
              'with a surah id',
        );
      case lineTypeSurahName || lineTypeBasmala:
        expect(
          !hasWords && l.surahId != null,
          () =>
              'page ${l.page} line ${l.line}: ${l.lineType} line with '
              'words or without a surah id',
        );
        final map = l.lineType == lineTypeSurahName ? surahNameOf : basmalaOf;
        map[l.surahId!] = (map[l.surahId!] ?? 0) + 1;
      default:
        problems.add('page ${l.page} line ${l.line}: type "${l.lineType}"');
    }
  }
  expect(
    linesPerPage.length == expectedPages,
    () =>
        'page_lines: ${linesPerPage.length} pages, expected '
        '$expectedPages',
  );
  for (var p = 1; p <= expectedPages; p++) {
    expect(
      linesPerPage[p] == linesOnPage(p),
      () => 'page $p: ${linesPerPage[p]} lines, expected ${linesOnPage(p)}',
    );
  }
  final nameLines = surahNameOf.values.fold(0, (a, b) => a + b);
  final basmalaLines = basmalaOf.values.fold(0, (a, b) => a + b);
  expect(
    nameLines == expectedSurahNameLines,
    () =>
        'page_lines: $nameLines surah_name lines, expected '
        '$expectedSurahNameLines',
  );
  expect(
    basmalaLines == expectedBasmalaLines,
    () =>
        'page_lines: $basmalaLines basmala lines, expected '
        '$expectedBasmalaLines',
  );
  for (final s in d.surahs) {
    expect(
      surahNameOf[s.id] == 1,
      () => 'surah ${s.id}: ${surahNameOf[s.id] ?? 0} surah_name lines',
    );
    expect(
      (basmalaOf[s.id] ?? 0) == s.bismillahPre,
      () =>
          'surah ${s.id}: ${basmalaOf[s.id] ?? 0} basmala lines, '
          'bismillah_pre ${s.bismillahPre}',
    );
  }
  problems.addAll(surahPageRangeProblems(d.surahs, d.ayahs, d.words));

  // ---- juzs
  expect(
    d.juzs.length == expectedJuzs,
    () => 'juzs: ${d.juzs.length} rows, expected $expectedJuzs',
  );
  var nextFirst = 1;
  for (final (i, j) in d.juzs.indexed) {
    expect(j.id == i + 1, () => 'juzs: row $i has id ${j.id}');
    expect(
      j.firstAyahId == nextFirst && j.lastAyahId >= j.firstAyahId,
      () =>
          'juz ${j.id}: range ${j.firstAyahId}-${j.lastAyahId} is not '
          'contiguous with the previous juz',
    );
    nextFirst = j.lastAyahId + 1;
    expect(
      j.pageStart == ayahById[j.firstAyahId]?.page,
      () =>
          'juz ${j.id}: page_start ${j.pageStart} is not the page of its '
          'first ayah',
    );
    for (var id = j.firstAyahId; id <= j.lastAyahId; id++) {
      if (juzOfAyah[id] != j.id) {
        problems.add(
          'juz ${j.id}: ayah id $id has juz_number ${juzOfAyah[id]}',
        );
        break;
      }
    }
  }
  expect(
    nextFirst == expectedAyahs + 1,
    () => 'juzs: ranges end at ${nextFirst - 1}, expected $expectedAyahs',
  );

  // ---- tafsirs
  expect(
    d.tafsirs.length == 1,
    () => 'tafsirs: ${d.tafsirs.length} rows, expected 1',
  );
  for (final t in d.tafsirs) {
    for (final (name, v) in [
      ('name_ar', t.nameAr),
      ('author', t.author),
      ('language', t.language),
      ('slug', t.slug),
    ]) {
      expect(v.isNotEmpty, () => 'tafsir ${t.id}: empty $name');
    }
  }
  expect(
    d.tafsirTexts.length == expectedAyahs,
    () =>
        'tafsir_texts: ${d.tafsirTexts.length} rows, expected '
        '$expectedAyahs',
  );
  final tafsirAyahs = <int>{};
  for (final t in d.tafsirTexts) {
    expect(
      tafsirAyahs.add(t.ayahId),
      () => 'tafsir_texts: two entries for ayah id ${t.ayahId}',
    );
    expect(
      t.text.isNotEmpty,
      () => 'tafsir_texts: empty text for ayah ${ayahById[t.ayahId]?.verseKey}',
    );
  }

  // ---- reciters
  expect(
    d.reciters.length >= minimumReciters,
    () =>
        'reciters: ${d.reciters.length} rows, expected at least '
        '$minimumReciters',
  );
  for (final r in d.reciters) {
    expect(
      r.style == null || reciterStyles.contains(r.style),
      () => 'reciter ${r.id}: style "${r.style}"',
    );
    expect(
      r.urlTemplate.startsWith('https://') &&
          r.urlTemplate.contains(surahPlaceholder) &&
          r.urlTemplate.contains(ayahPlaceholder),
      () => 'reciter ${r.id}: url_template "${r.urlTemplate}"',
    );
    expect(
      r.nameAr.isNotEmpty && r.nameEn.isNotEmpty && r.sourceId.isNotEmpty,
      () => 'reciter ${r.id}: empty name or source_id',
    );
  }
  final sortOrders = d.reciters.map((r) => r.sortOrder).toList()..sort();
  expect(
    sortOrders.indexed.every((e) => e.$2 == e.$1 + 1),
    () => 'reciters: sort_order values $sortOrders are not 1..n',
  );

  if (problems.isNotEmpty) {
    final shown = problems.take(200).join('\n  ');
    final more = problems.length > 200
        ? '\n  ... and ${problems.length - 200} more'
        : '';
    final joinNote = joinFailures.isEmpty
        ? ''
        : '\nword-join invariant failed for ${joinFailures.length} ayahs: '
              '${joinFailures.join(', ')}';
    throw ImportException(
      '${problems.length} invariant violation(s):\n  $shown$more$joinNote',
    );
  }
}

/// Describes where two strings first differ, by code point offsets and
/// values only (never by quoting the text).
String _describeDifference(String a, String b) {
  final x = a.runes.toList(), y = b.runes.toList();
  var i = 0;
  while (i < x.length && i < y.length && x[i] == y[i]) {
    i++;
  }
  String cp(List<int> r) => i < r.length
      ? 'U+${r[i].toRadixString(16).toUpperCase().padLeft(4, '0')}'
      : 'end of string';
  return 'joined length ${x.length}, text length ${y.length}, first '
      'difference at code point $i: joined has ${cp(x)}, text has ${cp(y)}';
}

/// Checks each surah's page range: `page_start` is the page of the first
/// word of ayah 1 (the surah name and basmala lines may sit at the bottom of
/// the previous page), and `page_end` the page of the surah's last word.
List<String> surahPageRangeProblems(
  List<SurahRow> surahs,
  List<AyahRow> ayahs,
  List<WordRow> words,
) {
  final ayahById = {for (final a in ayahs) a.id: a};
  final firstWordPage = <int, int>{};
  final lastWordPage = <int, int>{};
  for (final w in words) {
    final a = ayahById[w.ayahId];
    if (a == null) continue;
    if (a.ayahNumber == 1 && w.position == 1) {
      firstWordPage[a.surahId] = w.page;
    }
    final last = lastWordPage[a.surahId];
    if (last == null || w.page > last) lastWordPage[a.surahId] = w.page;
  }
  return [
    for (final s in surahs) ...[
      if (s.pageStart != firstWordPage[s.id])
        'surah ${s.id}: page_start ${s.pageStart} but the first word of '
            'ayah 1 is on page ${firstWordPage[s.id]}',
      if (s.pageEnd != lastWordPage[s.id])
        'surah ${s.id}: page_end ${s.pageEnd} but its last word is on '
            'page ${lastWordPage[s.id]}',
    ],
  ];
}
