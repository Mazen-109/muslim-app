import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqlite3/sqlite3.dart';

import 'models/ayah.dart';
import 'models/ayah_ref.dart';
import 'models/juz.dart';
import 'models/mushaf_page.dart';
import 'models/surah.dart';
import 'models/word.dart';
import 'quran_database.dart';

/// Read access to surahs, ayahs, juz and the Mushaf page layout.
///
/// Every text value is returned exactly as stored. Surahs, juz and the
/// basmala words are read once when the repository is created; everything
/// else is an indexed query.
class QuranRepository {
  QuranRepository(QuranDatabase database) : _db = database.db {
    _surahs = List<Surah>.unmodifiable(
      _db.select('SELECT * FROM surahs ORDER BY id').map(_surahFromRow),
    );
    if (_surahs.length != surahCount) {
      throw QuranDatabaseException(
        'Expected $surahCount surahs, found ${_surahs.length}',
      );
    }
    ayahCounts = List<int>.unmodifiable(_surahs.map((s) => s.ayahCount));
    final firstIds = <int>[];
    var next = 1;
    for (final count in ayahCounts) {
      firstIds.add(next);
      next += count;
    }
    _firstAyahIds = firstIds;
    ayahTotal = next - 1;
    _juzs = List<Juz>.unmodifiable(
      _db
          .select('SELECT * FROM juzs ORDER BY id')
          .map(
            (r) => Juz(
              id: r['id'] as int,
              firstAyahId: r['first_ayah_id'] as int,
              lastAyahId: r['last_ayah_id'] as int,
              pageStart: r['page_start'] as int,
            ),
          ),
    );
    _basmalaWords = List<Word>.unmodifiable(
      _db.select(basmalaWordsSql).map(_wordFromRow),
    );
    if (_basmalaWords.isEmpty) {
      throw const QuranDatabaseException('Ayah 1:1 has no words');
    }
    _pageWords = _db.prepare(pageWordsSql);
    _searchAyahs = _db.prepare(searchAyahsSql);
  }

  final Database _db;
  late final List<Surah> _surahs;
  late final List<Juz> _juzs;
  late final List<int> _firstAyahIds;
  late final List<Word> _basmalaWords;
  late final PreparedStatement _pageWords;
  late final PreparedStatement _searchAyahs;

  /// `ayahCounts[s - 1]` is the ayah count of surah `s`, from the database.
  late final List<int> ayahCounts;

  /// The number of ayahs (6236).
  late final int ayahTotal;

  /// The words of a page in layout order. Uses the `(page, line, ayah_id,
  /// position)` index, so it never scans the whole table.
  @visibleForTesting
  static const String pageWordsSql =
      'SELECT id, ayah_id, position, char_type, text_qpc_hafs, page, line '
      'FROM words WHERE page = ? ORDER BY line, ayah_id, position';

  /// The words of ayah 1:1 without its end marker.
  @visibleForTesting
  static const String basmalaWordsSql =
      'SELECT id, ayah_id, position, char_type, text_qpc_hafs, page, line '
      "FROM words WHERE ayah_id = 1 AND char_type = 'word' ORDER BY position";

  /// The words of the basmala that opens every surah but 1 and 9: the words
  /// of ayah 1:1 without its end marker, as stored.
  List<Word> basmalaWords() => _basmalaWords;

  /// All 114 surahs in order.
  List<Surah> surahs() => _surahs;

  /// The surah with [id]; throws [RangeError] outside 1 to 114.
  Surah surah(int id) {
    RangeError.checkValueInInterval(id, 1, surahCount, 'id');
    return _surahs[id - 1];
  }

  /// All 30 juz in order.
  List<Juz> juzs() => _juzs;

  /// Throws [RangeError] unless [ref] names an ayah of the database.
  void checkRef(AyahRef ref) => ref.checkAgainst(ayahCounts);

  /// Parses an ayah key such as `2:255` and checks it against the surah
  /// ayah counts; throws [FormatException] when it is not a valid ayah.
  AyahRef parseKey(String key) => AyahRef.parse(key, ayahCounts: ayahCounts);

  /// Like [parseKey], but returns null for an invalid key.
  AyahRef? tryParseKey(String key) =>
      AyahRef.tryParse(key, ayahCounts: ayahCounts);

  /// The ayah id (1 to 6236) of [ref]; throws [RangeError] if invalid.
  int ayahIdOf(AyahRef ref) {
    checkRef(ref);
    return _firstAyahIds[ref.surah - 1] + ref.ayah - 1;
  }

  /// The ref of ayah [ayahId]; throws [RangeError] outside 1 to 6236.
  AyahRef refOf(int ayahId) {
    _checkAyahId(ayahId);
    var surah = 1;
    while (surah < surahCount && _firstAyahIds[surah] <= ayahId) {
      surah++;
    }
    return AyahRef(surah, ayahId - _firstAyahIds[surah - 1] + 1);
  }

  /// The ayah with [id]; throws [RangeError] outside 1 to 6236.
  Ayah ayah(int id) {
    _checkAyahId(id);
    return _ayahFromRow(
      _db.select('SELECT * FROM ayahs WHERE id = ?', <Object?>[id]).single,
    );
  }

  /// The ayah [ref]; throws [RangeError] if it does not exist.
  Ayah ayahByRef(AyahRef ref) => ayah(ayahIdOf(ref));

  /// Every ayah of surah [surahId], in order.
  List<Ayah> ayahsOfSurah(int surahId) {
    final surah = this.surah(surahId);
    final first = _firstAyahIds[surahId - 1];
    return List<Ayah>.unmodifiable(
      _db
          .select(
            'SELECT * FROM ayahs WHERE id BETWEEN ? AND ? ORDER BY id',
            <Object?>[first, first + surah.ayahCount - 1],
          )
          .map(_ayahFromRow),
    );
  }

  /// The page of the first word of ayah [ayahId].
  int pageOf(int ayahId) {
    _checkAyahId(ayahId);
    return _db.select('SELECT page FROM ayahs WHERE id = ?', <Object?>[
          ayahId,
        ]).single['page']
        as int;
  }

  /// The first ayah whose words appear on [page], in reading order.
  Ayah firstAyahOfPage(int page) {
    _checkPage(page);
    final row = _db.select(
      'SELECT ayah_id FROM words WHERE page = ? '
      'ORDER BY line, ayah_id, position LIMIT 1',
      <Object?>[page],
    );
    if (row.isEmpty) {
      throw QuranDatabaseException('Page $page has no words');
    }
    return ayah(row.first['ayah_id'] as int);
  }

  /// Mushaf page [number] (1 to 604) with its lines in order. Ayah lines
  /// hold their words in (ayah id, position) order; surah name and basmala
  /// lines hold their surah; basmala lines also hold the words of ayah 1:1
  /// without its end marker.
  MushafPage page(int number) {
    _checkPage(number);
    final wordsByLine = <int, List<Word>>{};
    for (final row in _pageWords.select(<Object?>[number])) {
      final word = _wordFromRow(row);
      (wordsByLine[word.line] ??= <Word>[]).add(word);
    }
    final lines = <PageLine>[];
    for (final row in _db.select(
      'SELECT line, line_type, surah_id FROM page_lines WHERE page = ? '
      'ORDER BY line',
      <Object?>[number],
    )) {
      final line = row['line'] as int;
      final type = row['line_type'] as String;
      final words = wordsByLine.remove(line);
      if (type != 'ayah' && words != null) {
        throw QuranDatabaseException(
          'Page $number line $line is $type but has words',
        );
      }
      lines.add(switch (type) {
        'ayah' => AyahLine(
          line,
          words ??
              (throw QuranDatabaseException(
                'Page $number line $line is an ayah line without words',
              )),
        ),
        'surah_name' => SurahNameLine(line, surah(row['surah_id'] as int)),
        'basmala' => BasmalaLine(
          line,
          surah(row['surah_id'] as int),
          _basmalaWords,
        ),
        _ => throw QuranDatabaseException('Unknown line type "$type"'),
      });
    }
    if (wordsByLine.isNotEmpty) {
      throw QuranDatabaseException(
        'Page $number has words on lines without a page_lines row',
      );
    }
    return MushafPage(number, lines);
  }

  /// The fewest letters a search query needs; shorter queries match nothing
  /// (tasks.md, T019).
  static const int minSearchLetters = 2;

  /// Whether [foldedQuery] has at least [minSearchLetters] letters, counting
  /// every code point that is not white space.
  static bool isSearchable(String foldedQuery) =>
      foldedQuery.replaceAll(_whitespace, '').runes.length >= minSearchLetters;

  static final RegExp _whitespace = RegExp(r'\s+');

  /// The ayahs whose `text_search_folded` contains [foldedQuery], in Mushaf
  /// order (research R9).
  ///
  /// [foldedQuery] must already be folded with `foldQuery`; this method does
  /// not fold it again. It is matched as a substring with `LIKE`, with `%`,
  /// `_` and the escape character itself escaped, so they match only
  /// themselves. A query that is not [isSearchable] matches nothing.
  AyahSearchResult searchAyahs(String foldedQuery) {
    if (!isSearchable(foldedQuery)) {
      return AyahSearchResult(foldedQuery, const <int>[]);
    }
    final ids = _searchAyahs
        .select(<Object?>['%${escapeLike(foldedQuery)}%'])
        .map((r) => r['id'] as int);
    return AyahSearchResult(foldedQuery, List<int>.unmodifiable(ids));
  }

  /// The search query. The folded column is never selected for display.
  @visibleForTesting
  static const String searchAyahsSql =
      r"SELECT id FROM ayahs WHERE text_search_folded LIKE ? ESCAPE '\' "
      'ORDER BY id';

  /// [text] with the `LIKE` wildcards `%` and `_` and the escape character
  /// `\` escaped, for use with `ESCAPE '\'`.
  @visibleForTesting
  static String escapeLike(String text) =>
      text.replaceAllMapped(_likeSpecial, (m) => '\\${m[0]}');

  static final RegExp _likeSpecial = RegExp(r'[\\%_]');

  void _checkAyahId(int id) =>
      RangeError.checkValueInInterval(id, 1, ayahTotal, 'ayahId');

  static void _checkPage(int page) =>
      RangeError.checkValueInInterval(page, 1, pageCount, 'page');

  static Surah _surahFromRow(Row r) => Surah(
    id: r['id'] as int,
    nameAr: r['name_ar'] as String,
    nameEn: r['name_en'] as String,
    revelationPlace: RevelationPlace.parse(r['revelation_place'] as String),
    revelationOrder: r['revelation_order'] as int,
    ayahCount: r['ayah_count'] as int,
    bismillahPre: (r['bismillah_pre'] as int) == 1,
    pageStart: r['page_start'] as int,
    pageEnd: r['page_end'] as int,
  );

  static Ayah _ayahFromRow(Row r) => Ayah(
    id: r['id'] as int,
    surahId: r['surah_id'] as int,
    ayahNumber: r['ayah_number'] as int,
    verseKey: r['verse_key'] as String,
    textQpcHafs: r['text_qpc_hafs'] as String,
    textUthmani: r['text_uthmani'] as String,
    textSearch: r['text_search'] as String,
    textSearchFolded: r['text_search_folded'] as String,
    page: r['page'] as int,
    juz: r['juz'] as int,
    hizb: r['hizb'] as int,
    rubElHizb: r['rub_el_hizb'] as int,
    sajdah: r['sajdah'] as int?,
  );

  static Word _wordFromRow(Row r) => Word(
    id: r['id'] as int,
    ayahId: r['ayah_id'] as int,
    position: r['position'] as int,
    charType: WordCharType.parse(r['char_type'] as String),
    textQpcHafs: r['text_qpc_hafs'] as String,
    page: r['page'] as int,
    line: r['line'] as int,
  );

  /// Releases the prepared statements. The database stays open.
  void dispose() {
    _pageWords.close();
    _searchAyahs.close();
  }
}

/// The result of [QuranRepository.searchAyahs]: the ids of the matching
/// ayahs in Mushaf order. Rows are loaded by id when they are shown.
@immutable
class AyahSearchResult {
  const AyahSearchResult(this.foldedQuery, this.ayahIds);

  /// The folded query that was matched.
  final String foldedQuery;

  /// The matching ayah ids (1 to 6236), ascending.
  final List<int> ayahIds;

  /// The number of matching ayahs.
  int get total => ayahIds.length;

  @override
  bool operator ==(Object other) =>
      other is AyahSearchResult &&
      other.foldedQuery == foldedQuery &&
      listEquals(other.ayahIds, ayahIds);

  @override
  int get hashCode => Object.hash(foldedQuery, Object.hashAll(ayahIds));

  @override
  String toString() => 'AyahSearchResult("$foldedQuery", $total ayahs)';
}

/// The Quran repository over the installed content database.
final quranRepositoryProvider = FutureProvider<QuranRepository>(
  retry: contentNoRetry,
  (ref) async {
    final repository = QuranRepository(
      await ref.watch(quranDatabaseProvider.future),
    );
    ref.onDispose(repository.dispose);
    return repository;
  },
);
