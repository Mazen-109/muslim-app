/// Strict parsers from Quran.com API v4 JSON to typed records.
///
/// Every field is read with an exact type check. Text values are kept exactly
/// as decoded from the response body: no trimming, no normalisation.
library;

import 'errors.dart';

/// A surah as returned by `GET /chapters`.
class Chapter {
  Chapter({
    required this.id,
    required this.nameArabic,
    required this.nameSimple,
    required this.revelationPlace,
    required this.revelationOrder,
    required this.bismillahPre,
    required this.versesCount,
    required this.pageStart,
    required this.pageEnd,
  });

  final int id;
  final String nameArabic;
  final String nameSimple;
  final String revelationPlace;
  final int revelationOrder;
  final bool bismillahPre;
  final int versesCount;
  final int pageStart;
  final int pageEnd;
}

/// One word (or ayah end marker) of a verse from `GET /verses/by_page`.
///
/// [page] and [line] are the 1405H Madani layout position, read from
/// `v1_page` and `line_v1`. The API's `page_number` is not used: when
/// `word_fields` includes `text_qpc_hafs` it switches to the 1421H layout for
/// some ayahs, while the `by_page` selection and `line_number` stay on the
/// 1405H layout.
class Word {
  Word({
    required this.id,
    required this.position,
    required this.charType,
    required this.text,
    required this.page,
    required this.line,
  });

  final int id;
  final int position;
  final String charType;
  final String text;
  final int page;
  final int line;

  bool sameAs(Word o) =>
      id == o.id &&
      position == o.position &&
      charType == o.charType &&
      text == o.text &&
      page == o.page &&
      line == o.line;
}

/// A verse from `GET /verses/by_page`.
class Verse {
  Verse({
    required this.id,
    required this.verseNumber,
    required this.verseKey,
    required this.hizb,
    required this.rubElHizb,
    required this.sajdah,
    required this.juz,
    required this.textQpcHafs,
    required this.textUthmani,
    required this.textImlaeiSimple,
    required this.words,
  });

  final int id;
  final int verseNumber;
  final String verseKey;
  final int hizb;
  final int rubElHizb;
  final int? sajdah;
  final int juz;
  final String textQpcHafs;
  final String textUthmani;
  final String textImlaeiSimple;
  final List<Word> words;

  /// True when every verse-level field (not the words) is identical.
  bool sameFieldsAs(Verse o) =>
      id == o.id &&
      verseNumber == o.verseNumber &&
      verseKey == o.verseKey &&
      hizb == o.hizb &&
      rubElHizb == o.rubElHizb &&
      sajdah == o.sajdah &&
      juz == o.juz &&
      textQpcHafs == o.textQpcHafs &&
      textUthmani == o.textUthmani &&
      textImlaeiSimple == o.textImlaeiSimple;
}

/// A juz row from `GET /juzs`.
class Juz {
  Juz({
    required this.juzNumber,
    required this.firstVerseId,
    required this.lastVerseId,
  });

  final int juzNumber;
  final int firstVerseId;
  final int lastVerseId;
}

/// Tafsir metadata from `GET /resources/tafsirs`.
class TafsirResource {
  TafsirResource({
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
}

/// One tafsir entry from `GET /tafsirs/{id}/by_chapter/{n}`.
class TafsirEntry {
  TafsirEntry({
    required this.resourceId,
    required this.verseKey,
    required this.text,
  });

  final int resourceId;
  final String verseKey;
  final String text;
}

/// Recitation metadata from `GET /resources/recitations`.
class Recitation {
  Recitation({
    required this.id,
    required this.reciterName,
    required this.style,
    required this.nameAr,
  });

  final int id;
  final String reciterName;
  final String? style;
  final String nameAr;
}

/// One audio file from `GET /recitations/{id}/by_chapter/{n}`.
class AudioFile {
  AudioFile({required this.verseKey, required this.url});

  final String verseKey;
  final String url;
}

/// A list of items plus the `pagination.next_page` value of the response.
class Paged<T> {
  Paged(this.items, this.nextPage);

  final List<T> items;
  final int? nextPage;
}

// ---------------------------------------------------------------------------

List<Chapter> parseChapters(Object? json) {
  final root = _map(json, 'chapters response');
  final list = _list(root, 'chapters', 'chapters response');
  return [
    for (final (i, item) in list.indexed)
      () {
        final m = _map(item, 'chapters[$i]');
        final ctx = 'chapter ${m['id']}';
        final pages = _list(m, 'pages', ctx);
        check(
          pages.length == 2 && pages.every((p) => p is int),
          () => '$ctx: "pages" must be [start, end], got $pages',
        );
        return Chapter(
          id: _int(m, 'id', ctx),
          nameArabic: _str(m, 'name_arabic', ctx),
          nameSimple: _str(m, 'name_simple', ctx),
          revelationPlace: _str(m, 'revelation_place', ctx),
          revelationOrder: _int(m, 'revelation_order', ctx),
          bismillahPre: _bool(m, 'bismillah_pre', ctx),
          versesCount: _int(m, 'verses_count', ctx),
          pageStart: pages[0] as int,
          pageEnd: pages[1] as int,
        );
      }(),
  ];
}

/// Parses one `GET /verses/by_page/{page}` response. Fails if the response is
/// paginated (`next_page` not null), since the import requests all verses of
/// a page in one response, if a word's `line_number` differs from its
/// `line_v1`, or if a returned verse's first word (position 1) is not on the
/// requested page (`v1_page`).
List<Verse> parseVersesByPage(Object? json, int page) {
  final ctx = 'verses/by_page/$page';
  final root = _map(json, ctx);
  final next = _pagination(root, ctx);
  check(
    next == null,
    () => '$ctx: expected a single response page, next_page=$next',
  );
  final list = _list(root, 'verses', ctx);
  final verses = [
    for (final (i, item) in list.indexed) _verse(_map(item, '$ctx verses[$i]')),
  ];
  for (final v in verses) {
    for (final w in v.words.where((w) => w.position == 1)) {
      check(
        w.page == page,
        () =>
            '$ctx: verse ${v.verseKey} starts on page ${w.page} (v1_page), '
            'not on the requested page',
      );
    }
  }
  return verses;
}

Verse _verse(Map<String, Object?> m) {
  final ctx = 'verse ${m['verse_key']}';
  final words = _list(m, 'words', ctx);
  return Verse(
    id: _int(m, 'id', ctx),
    verseNumber: _int(m, 'verse_number', ctx),
    verseKey: _str(m, 'verse_key', ctx),
    hizb: _int(m, 'hizb_number', ctx),
    rubElHizb: _int(m, 'rub_el_hizb_number', ctx),
    sajdah: _intOrNull(m, 'sajdah_number', ctx),
    juz: _int(m, 'juz_number', ctx),
    textQpcHafs: _str(m, 'text_qpc_hafs', ctx),
    textUthmani: _str(m, 'text_uthmani', ctx),
    textImlaeiSimple: _str(m, 'text_imlaei_simple', ctx),
    words: [
      for (final (i, w) in words.indexed) _word(_map(w, '$ctx words[$i]'), ctx),
    ],
  );
}

Word _word(Map<String, Object?> m, String verseCtx) {
  final ctx = '$verseCtx word ${m['id']}';
  final lineNumber = _int(m, 'line_number', ctx);
  final lineV1 = _int(m, 'line_v1', ctx);
  check(
    lineNumber == lineV1,
    () => '$ctx: line_number $lineNumber differs from line_v1 $lineV1',
  );
  return Word(
    id: _int(m, 'id', ctx),
    position: _int(m, 'position', ctx),
    charType: _str(m, 'char_type_name', ctx),
    text: _str(m, 'text_qpc_hafs', ctx),
    page: _int(m, 'v1_page', ctx),
    line: lineV1,
  );
}

List<Juz> parseJuzs(Object? json) {
  final root = _map(json, 'juzs response');
  final list = _list(root, 'juzs', 'juzs response');
  return [
    for (final (i, item) in list.indexed)
      () {
        final m = _map(item, 'juzs[$i]');
        final ctx = 'juzs[$i]';
        return Juz(
          juzNumber: _int(m, 'juz_number', ctx),
          firstVerseId: _int(m, 'first_verse_id', ctx),
          lastVerseId: _int(m, 'last_verse_id', ctx),
        );
      }(),
  ];
}

/// Finds tafsir [id] in a `GET /resources/tafsirs?language=ar` response.
///
/// `name_ar` is `translated_name.name`, which must be labelled Arabic.
TafsirResource parseTafsirResource(Object? json, int id) {
  final root = _map(json, 'resources/tafsirs');
  final list = _list(root, 'tafsirs', 'resources/tafsirs');
  final matches = [
    for (final item in list)
      if (_map(item, 'resources/tafsirs item')['id'] == id)
        _map(item, 'resources/tafsirs item'),
  ];
  check(
    matches.length == 1,
    () =>
        'resources/tafsirs: expected exactly one tafsir with id $id, '
        'found ${matches.length}',
  );
  final m = matches.single;
  final ctx = 'tafsir resource $id';
  final translated = _map(m['translated_name'], '$ctx translated_name');
  check(
    translated['language_name'] == 'arabic',
    () =>
        '$ctx: translated_name.language_name is '
        '"${translated['language_name']}", expected "arabic"',
  );
  return TafsirResource(
    id: id,
    nameAr: _str(translated, 'name', '$ctx translated_name'),
    author: _str(m, 'author_name', ctx),
    language: _str(m, 'language_name', ctx),
    slug: _str(m, 'slug', ctx),
  );
}

Paged<TafsirEntry> parseTafsirPage(Object? json, String ctx) {
  final root = _map(json, ctx);
  final next = _pagination(root, ctx);
  final list = _list(root, 'tafsirs', ctx);
  return Paged([
    for (final (i, item) in list.indexed)
      () {
        final m = _map(item, '$ctx tafsirs[$i]');
        final c = '$ctx ${m['verse_key']}';
        return TafsirEntry(
          resourceId: _int(m, 'resource_id', c),
          verseKey: _str(m, 'verse_key', c),
          text: _str(m, 'text', c),
        );
      }(),
  ], next);
}

/// Finds the recitations with the given ids in a
/// `GET /resources/recitations?language=ar` response.
///
/// `nameAr` is `translated_name.name`, which must be labelled Arabic.
Map<int, Recitation> parseRecitations(Object? json, Iterable<int> ids) {
  final root = _map(json, 'resources/recitations');
  final list = _list(root, 'recitations', 'resources/recitations');
  final out = <int, Recitation>{};
  for (final (i, item) in list.indexed) {
    final m = _map(item, 'recitations[$i]');
    final id = _int(m, 'id', 'recitations[$i]');
    if (!ids.contains(id)) continue;
    final ctx = 'recitation $id';
    check(!out.containsKey(id), () => '$ctx: listed more than once');
    final translated = _map(m['translated_name'], '$ctx translated_name');
    check(
      translated['language_name'] == 'arabic',
      () =>
          '$ctx: translated_name.language_name is '
          '"${translated['language_name']}", expected "arabic"',
    );
    out[id] = Recitation(
      id: id,
      reciterName: _str(m, 'reciter_name', ctx),
      style: _strOrNull(m, 'style', ctx),
      nameAr: _str(translated, 'name', '$ctx translated_name'),
    );
  }
  final missing = ids.where((id) => !out.containsKey(id)).toList();
  check(
    missing.isEmpty,
    () => 'resources/recitations: missing recitation ids $missing',
  );
  return out;
}

Paged<AudioFile> parseAudioPage(Object? json, String ctx) {
  final root = _map(json, ctx);
  final next = _pagination(root, ctx);
  final list = _list(root, 'audio_files', ctx);
  return Paged([
    for (final (i, item) in list.indexed)
      () {
        final m = _map(item, '$ctx audio_files[$i]');
        final c = '$ctx audio_files[$i]';
        return AudioFile(
          verseKey: _str(m, 'verse_key', c),
          url: _str(m, 'url', c),
        );
      }(),
  ], next);
}

// ---------------------------------------------------------------------------
// Strict field accessors.

int? _pagination(Map<String, Object?> root, String ctx) {
  final p = _map(root['pagination'], '$ctx pagination');
  final next = p['next_page'];
  check(
    next == null || next is int,
    () => '$ctx: pagination.next_page must be an integer or null, got $next',
  );
  return next as int?;
}

Map<String, Object?> _map(Object? v, String ctx) {
  check(
    v is Map<String, Object?>,
    () => '$ctx: expected a JSON object, got ${v.runtimeType}',
  );
  return v as Map<String, Object?>;
}

List<Object?> _list(Map<String, Object?> m, String key, String ctx) {
  final v = m[key];
  check(
    v is List<Object?>,
    () => '$ctx: "$key" must be a JSON array, got ${v.runtimeType}',
  );
  return v as List<Object?>;
}

int _int(Map<String, Object?> m, String key, String ctx) {
  final v = m[key];
  check(v is int, () => '$ctx: "$key" must be an integer, got $v');
  return v as int;
}

int? _intOrNull(Map<String, Object?> m, String key, String ctx) {
  check(m.containsKey(key), () => '$ctx: "$key" is missing');
  final v = m[key];
  check(
    v == null || v is int,
    () => '$ctx: "$key" must be an integer or null, got $v',
  );
  return v as int?;
}

String _str(Map<String, Object?> m, String key, String ctx) {
  final v = m[key];
  check(
    v is String,
    () => '$ctx: "$key" must be a string, got ${v.runtimeType}',
  );
  return v as String;
}

String? _strOrNull(Map<String, Object?> m, String key, String ctx) {
  check(m.containsKey(key), () => '$ctx: "$key" is missing');
  final v = m[key];
  check(
    v == null || v is String,
    () => '$ctx: "$key" must be a string or null, got ${v.runtimeType}',
  );
  return v as String?;
}

bool _bool(Map<String, Object?> m, String key, String ctx) {
  final v = m[key];
  check(v is bool, () => '$ctx: "$key" must be a boolean, got $v');
  return v as bool;
}
