/// Table rows of `quran.db` and their assembly from parsed API records.
library;

import 'package:search_folding/search_folding.dart';

import 'errors.dart';
import 'layout.dart';
import 'parsers.dart';
import 'reciters.dart';

/// A row whose [values] are in the column order of data-model.md section 1.
abstract class TableRow {
  List<Object?> get values;
}

class SurahRow implements TableRow {
  SurahRow({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.revelationPlace,
    required this.revelationOrder,
    required this.ayahCount,
    required this.bismillahPre,
    required this.pageStart,
    required this.pageEnd,
  });

  final int id;
  final String nameAr;
  final String nameEn;
  final String revelationPlace;
  final int revelationOrder;
  final int ayahCount;
  final int bismillahPre;
  final int pageStart;
  final int pageEnd;

  @override
  List<Object?> get values => [
    id,
    nameAr,
    nameEn,
    revelationPlace,
    revelationOrder,
    ayahCount,
    bismillahPre,
    pageStart,
    pageEnd,
  ];
}

class AyahRow implements TableRow {
  AyahRow({
    required this.id,
    required this.surahId,
    required this.ayahNumber,
    required this.verseKey,
    required this.textQpcHafs,
    required this.textUthmani,
    required this.textSearch,
    required this.textSearchFolded,
    required this.page,
    required this.juz,
    required this.hizb,
    required this.rubElHizb,
    required this.sajdah,
  });

  final int id;
  final int surahId;
  final int ayahNumber;
  final String verseKey;
  final String textQpcHafs;
  final String textUthmani;
  final String textSearch;
  final String textSearchFolded;
  final int page;
  final int juz;
  final int hizb;
  final int rubElHizb;
  final int? sajdah;

  @override
  List<Object?> get values => [
    id,
    surahId,
    ayahNumber,
    verseKey,
    textQpcHafs,
    textUthmani,
    textSearch,
    textSearchFolded,
    page,
    juz,
    hizb,
    rubElHizb,
    sajdah,
  ];
}

class WordRow implements TableRow {
  WordRow({
    required this.id,
    required this.ayahId,
    required this.position,
    required this.charType,
    required this.textQpcHafs,
    required this.page,
    required this.line,
  });

  final int id;
  final int ayahId;
  final int position;
  final String charType;
  final String textQpcHafs;
  final int page;
  final int line;

  @override
  List<Object?> get values => [
    id,
    ayahId,
    position,
    charType,
    textQpcHafs,
    page,
    line,
  ];
}

class PageLineRow implements TableRow {
  PageLineRow(this.line);

  final PageLine line;

  @override
  List<Object?> get values => [
    line.page,
    line.line,
    line.lineType,
    line.surahId,
  ];
}

class JuzRow implements TableRow {
  JuzRow({
    required this.id,
    required this.firstAyahId,
    required this.lastAyahId,
    required this.pageStart,
  });

  final int id;
  final int firstAyahId;
  final int lastAyahId;
  final int pageStart;

  @override
  List<Object?> get values => [id, firstAyahId, lastAyahId, pageStart];
}

class TafsirRow implements TableRow {
  TafsirRow({
    required this.id,
    required this.nameAr,
    required this.author,
    required this.language,
    required this.slug,
  });

  final int id;
  final String nameAr;
  final String author;
  final String language;
  final String slug;

  @override
  List<Object?> get values => [id, nameAr, author, language, slug];
}

class TafsirTextRow implements TableRow {
  TafsirTextRow({
    required this.tafsirId,
    required this.ayahId,
    required this.text,
  });

  final int tafsirId;
  final int ayahId;
  final String text;

  @override
  List<Object?> get values => [tafsirId, ayahId, text];
}

class ReciterRow implements TableRow {
  ReciterRow({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.style,
    required this.urlTemplate,
    required this.sourceId,
    required this.sortOrder,
  });

  final int id;
  final String nameAr;
  final String nameEn;
  final String? style;
  final String urlTemplate;
  final String sourceId;
  final int sortOrder;

  @override
  List<Object?> get values => [
    id,
    nameAr,
    nameEn,
    style,
    urlTemplate,
    sourceId,
    sortOrder,
  ];
}

/// All rows of the content database except `meta`, each list in primary-key
/// order.
class Dataset {
  Dataset({
    required this.surahs,
    required this.ayahs,
    required this.words,
    required this.pageLines,
    required this.juzs,
    required this.tafsirs,
    required this.tafsirTexts,
    required this.reciters,
  });

  final List<SurahRow> surahs;
  final List<AyahRow> ayahs;
  final List<WordRow> words;
  final List<PageLineRow> pageLines;
  final List<JuzRow> juzs;
  final List<TafsirRow> tafsirs;
  final List<TafsirTextRow> tafsirTexts;
  final List<ReciterRow> reciters;

  /// Rows per table name, keyed like `hashedTables`.
  Map<String, List<TableRow>> get tables => {
    'surahs': surahs,
    'ayahs': ayahs,
    'words': words,
    'page_lines': pageLines,
    'juzs': juzs,
    'tafsirs': tafsirs,
    'tafsir_texts': tafsirTexts,
    'reciters': reciters,
  };
}

// ---------------------------------------------------------------------------

/// Merges the verses of every `by_page` response.
///
/// An ayah that spans two pages may be returned by both pages. Verses are
/// de-duplicated by id (their fields must be identical) and their words are
/// merged by word id (a word seen twice must be identical). The result is
/// sorted by verse id, each verse's words by position.
List<Verse> mergeVerses(Iterable<List<Verse>> pages) {
  final verses = <int, Verse>{};
  final words = <int, Map<int, Word>>{};
  for (final page in pages) {
    for (final v in page) {
      final seen = verses[v.id];
      if (seen == null) {
        verses[v.id] = v;
        words[v.id] = {};
      } else {
        check(
          seen.sameFieldsAs(v),
          () =>
              'verse ${v.verseKey} (id ${v.id}) differs between two page '
              'responses',
        );
      }
      final byId = words[v.id]!;
      for (final w in v.words) {
        final prior = byId[w.id];
        check(
          prior == null || prior.sameAs(w),
          () =>
              'word ${w.id} of ${v.verseKey} differs between two page '
              'responses',
        );
        byId[w.id] = w;
      }
    }
  }
  final ids = verses.keys.toList()..sort();
  return [
    for (final id in ids)
      () {
        final v = verses[id]!;
        final ws = words[id]!.values.toList()
          ..sort((a, b) => a.position.compareTo(b.position));
        return Verse(
          id: v.id,
          verseNumber: v.verseNumber,
          verseKey: v.verseKey,
          hizb: v.hizb,
          rubElHizb: v.rubElHizb,
          sajdah: v.sajdah,
          juz: v.juz,
          textQpcHafs: v.textQpcHafs,
          textUthmani: v.textUthmani,
          textImlaeiSimple: v.textImlaeiSimple,
          words: ws,
        );
      }(),
  ];
}

/// De-duplicates `/juzs` rows by `juz_number`.
///
/// Rows sharing a juz number must agree on their verse range. Requires
/// exactly 30 juz, numbered 1 to 30, whose ranges are contiguous and cover
/// verse ids 1 to [ayahCount]. Returns them sorted by juz number.
List<Juz> dedupeJuzs(List<Juz> rows, {int ayahCount = 6236}) {
  final byNumber = <int, Juz>{};
  for (final j in rows) {
    final prior = byNumber[j.juzNumber];
    check(
      prior == null ||
          (prior.firstVerseId == j.firstVerseId &&
              prior.lastVerseId == j.lastVerseId),
      () =>
          'juz ${j.juzNumber} is listed with two different ranges: '
          '${prior!.firstVerseId}-${prior.lastVerseId} and '
          '${j.firstVerseId}-${j.lastVerseId}',
    );
    byNumber[j.juzNumber] = j;
  }
  final numbers = byNumber.keys.toList()..sort();
  check(
    numbers.length == 30 && numbers.first == 1 && numbers.last == 30,
    () => 'expected juz numbers 1..30, got $numbers',
  );
  var expectedFirst = 1;
  for (final n in numbers) {
    final j = byNumber[n]!;
    check(
      j.firstVerseId == expectedFirst,
      () =>
          'juz $n starts at verse id ${j.firstVerseId}, expected '
          '$expectedFirst (ranges must be contiguous)',
    );
    check(
      j.lastVerseId >= j.firstVerseId,
      () => 'juz $n ends at ${j.lastVerseId}, before its start',
    );
    expectedFirst = j.lastVerseId + 1;
  }
  check(
    expectedFirst == ayahCount + 1,
    () =>
        'juz ranges end at verse id ${expectedFirst - 1}, expected '
        '$ayahCount',
  );
  return [for (final n in numbers) byNumber[n]!];
}

/// A reciter with its resolved template.
class ResolvedReciter {
  ResolvedReciter(this.recitation, this.template, this.sortOrder);

  final Recitation recitation;
  final ResolvedTemplate template;
  final int sortOrder;
}

/// Builds every table from parsed records. Assumes [verses] came from
/// [mergeVerses] and [juzs] from [dedupeJuzs]; the full set of invariants is
/// checked afterwards by `validateDataset`.
Dataset assembleDataset({
  required List<Chapter> chapters,
  required List<Verse> verses,
  required List<Juz> juzs,
  required TafsirResource tafsir,
  required List<TafsirEntry> tafsirEntries,
  required List<ResolvedReciter> reciters,
}) {
  final ayahs = <AyahRow>[];
  final words = <WordRow>[];
  final layoutWords = <LayoutWord>[];
  final ayahIdByKey = <String, int>{};
  final ayahPage = <int, int>{};
  for (final v in verses) {
    final (surah, ayah) = parseVerseKey(v.verseKey);
    check(
      ayah == v.verseNumber,
      () => 'verse ${v.verseKey}: verse_number is ${v.verseNumber}',
    );
    check(v.words.isNotEmpty, () => 'verse ${v.verseKey} has no words');
    ayahIdByKey[v.verseKey] = v.id;
    final firstWordPage = v.words.first.page;
    ayahPage[v.id] = firstWordPage;
    ayahs.add(
      AyahRow(
        id: v.id,
        surahId: surah,
        ayahNumber: ayah,
        verseKey: v.verseKey,
        textQpcHafs: v.textQpcHafs,
        textUthmani: v.textUthmani,
        textSearch: v.textImlaeiSimple,
        textSearchFolded: foldArabic(v.textImlaeiSimple),
        page: firstWordPage,
        juz: v.juz,
        hizb: v.hizb,
        rubElHizb: v.rubElHizb,
        sajdah: v.sajdah,
      ),
    );
    for (final w in v.words) {
      words.add(
        WordRow(
          id: w.id,
          ayahId: v.id,
          position: w.position,
          charType: w.charType,
          textQpcHafs: w.text,
          page: w.page,
          line: w.line,
        ),
      );
      layoutWords.add(
        LayoutWord(
          id: w.id,
          ayahId: v.id,
          surah: surah,
          ayah: ayah,
          position: w.position,
          page: w.page,
          line: w.line,
        ),
      );
    }
  }
  // Primary-key order. Word ids are source ids and do not follow reading
  // order, which is (ayah_id, position).
  words.sort((a, b) => a.id.compareTo(b.id));

  final pageLines = derivePageLines(
    words: layoutWords,
    surahs: [
      for (final c in chapters)
        LayoutSurah(id: c.id, bismillahPre: c.bismillahPre),
    ],
  );

  final tafsirTexts = <TafsirTextRow>[];
  for (final e in tafsirEntries) {
    check(
      e.resourceId == tafsir.id,
      () =>
          'tafsir entry ${e.verseKey} belongs to resource ${e.resourceId}, '
          'expected ${tafsir.id}',
    );
    final ayahId = ayahIdByKey[e.verseKey];
    check(
      ayahId != null,
      () => 'tafsir entry for unknown verse key ${e.verseKey}',
    );
    tafsirTexts.add(
      TafsirTextRow(tafsirId: tafsir.id, ayahId: ayahId!, text: e.text),
    );
  }
  tafsirTexts.sort((a, b) => a.ayahId.compareTo(b.ayahId));

  return Dataset(
    surahs: [
      for (final c in chapters)
        SurahRow(
          id: c.id,
          nameAr: c.nameArabic,
          nameEn: c.nameSimple,
          revelationPlace: c.revelationPlace,
          revelationOrder: c.revelationOrder,
          ayahCount: c.versesCount,
          bismillahPre: c.bismillahPre ? 1 : 0,
          pageStart: c.pageStart,
          pageEnd: c.pageEnd,
        ),
    ]..sort((a, b) => a.id.compareTo(b.id)),
    ayahs: ayahs,
    words: words,
    pageLines: [for (final l in pageLines) PageLineRow(l)],
    juzs: [
      for (final j in juzs)
        JuzRow(
          id: j.juzNumber,
          firstAyahId: j.firstVerseId,
          lastAyahId: j.lastVerseId,
          pageStart:
              ayahPage[j.firstVerseId] ??
              (throw ImportException(
                'juz ${j.juzNumber}: first verse id ${j.firstVerseId} is not '
                'an imported ayah',
              )),
        ),
    ],
    tafsirs: [
      TafsirRow(
        id: tafsir.id,
        nameAr: tafsir.nameAr,
        author: tafsir.author,
        language: tafsir.language,
        slug: tafsir.slug,
      ),
    ],
    tafsirTexts: tafsirTexts,
    reciters: [
      for (final r in reciters)
        ReciterRow(
          id: r.recitation.id,
          nameAr: r.recitation.nameAr,
          nameEn: r.recitation.reciterName,
          style: normaliseStyle(r.recitation.style, r.recitation.id),
          urlTemplate: r.template.template,
          sourceId: r.template.sourceId,
          sortOrder: r.sortOrder,
        ),
    ]..sort((a, b) => a.id.compareTo(b.id)),
  );
}

/// The verse keys of a surah that `by_chapter` did not list, after checking
/// the listed entries (this surah, in range, once each, [resourceId], ayah 1
/// present).
List<String> unlistedTafsirKeys({
  required int surah,
  required int ayahCount,
  required int resourceId,
  required List<TafsirEntry> listed,
}) {
  final seen = <int>{};
  for (final e in listed) {
    final (s, a) = parseVerseKey(e.verseKey);
    check(
      s == surah && a >= 1 && a <= ayahCount,
      () => 'tafsir chapter $surah lists ${e.verseKey}',
    );
    check(seen.add(a), () => 'tafsir chapter $surah lists ${e.verseKey} twice');
    check(
      e.resourceId == resourceId,
      () =>
          'tafsir ${e.verseKey}: resource ${e.resourceId}, expected '
          '$resourceId',
    );
  }
  check(seen.contains(1), () => 'tafsir chapter $surah does not list ayah 1');
  return [
    for (var a = 1; a <= ayahCount; a++)
      if (!seen.contains(a)) '$surah:$a',
  ];
}

/// The most keys the API returns in a `by_ayah` response's `verses` map.
/// Observed 2026-11-15: an entry explaining 70:19 to 70:30 lists only
/// 70:19 to 70:28.
const tafsirVersesMapCap = 10;

/// Completes one surah's tafsir entries, one per ayah (research R6).
///
/// `by_chapter` lists an entry once, under the first ayah of the group of
/// consecutive ayahs it explains. For every unlisted ayah, [groups] holds
/// that ayah's own `by_ayah` response, which must:
/// - belong to [resourceId];
/// - name, as the first key of its `verses` map, the nearest listed ayah
///   before it (the group's head), with the map a contiguous run of keys
///   from the head;
/// - contain the ayah in that map, unless the map is cut at
///   [tafsirVersesMapCap] keys;
/// - have exactly the text listed for the head.
///
/// The ayah then gets that text, unchanged. Anything else fails. Returns
/// entries for ayahs 1..[ayahCount] in order.
List<TafsirEntry> completeTafsirChapter({
  required int surah,
  required int ayahCount,
  required int resourceId,
  required List<TafsirEntry> listed,
  required Map<String, TafsirGroup> groups,
}) {
  final unlisted = unlistedTafsirKeys(
    surah: surah,
    ayahCount: ayahCount,
    resourceId: resourceId,
    listed: listed,
  );
  final byAyah = <int, TafsirEntry>{
    for (final e in listed) parseVerseKey(e.verseKey).$2: e,
  };
  var head = 0;
  for (var a = 1; a <= ayahCount; a++) {
    final key = '$surah:$a';
    if (!unlisted.contains(key)) {
      head = a;
      continue;
    }
    final group = groups[key];
    final ctx = 'tafsir by_ayah $key';
    check(group != null, () => '$ctx: no response');
    final listedHead = byAyah[head]!;
    check(
      group!.resourceId == resourceId,
      () => '$ctx: resource ${group.resourceId}, expected $resourceId',
    );
    final run = [
      for (var i = 0; i < group.verseKeys.length; i++) '$surah:${head + i}',
    ];
    final contiguousFromHead = _listEquals(group.verseKeys, run);
    final coversKey =
        group.verseKeys.contains(key) ||
        group.verseKeys.length == tafsirVersesMapCap;
    check(
      contiguousFromHead && coversKey,
      () =>
          '$ctx: group lists ${group.verseKeys}, expected a contiguous run '
          'from the listed $surah:$head that contains $key (or is cut at '
          '$tafsirVersesMapCap keys)',
    );
    check(
      group.text == listedHead.text,
      () => '$ctx: text differs from the text listed for $surah:$head',
    );
    byAyah[a] = TafsirEntry(
      resourceId: resourceId,
      verseKey: key,
      text: group.text,
    );
  }
  return [for (var a = 1; a <= ayahCount; a++) byAyah[a]!];
}

bool _listEquals(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
