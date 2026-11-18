import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqlite3/sqlite3.dart';

import 'models/ayah_ref.dart';
import 'models/tafsir.dart';
import 'quran_database.dart';

/// Read access to tafsir works and their stored text per ayah.
class TafsirRepository {
  TafsirRepository(QuranDatabase database) : _db = database.db;

  final Database _db;

  /// Every tafsir work, by id.
  List<Tafsir> tafsirs() => List<Tafsir>.unmodifiable(
    _db
        .select(
          'SELECT id, name_ar, author, language, slug FROM tafsirs ORDER BY id',
        )
        .map(
          (r) => Tafsir(
            id: r['id'] as int,
            nameAr: r['name_ar'] as String,
            author: r['author'] as String,
            language: r['language'] as String,
            slug: r['slug'] as String,
          ),
        ),
  );

  /// The tafsir work with [id], or null.
  Tafsir? tafsir(int id) {
    for (final t in tafsirs()) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// The stored text of [tafsirId] for ayah [ayahId], unchanged, or null
  /// when there is none.
  String? text(int tafsirId, int ayahId) {
    final rows = _db.select(
      'SELECT text FROM tafsir_texts WHERE tafsir_id = ? AND ayah_id = ?',
      <Object?>[tafsirId, ayahId],
    );
    return rows.isEmpty ? null : rows.first['text'] as String;
  }

  /// The run of consecutive ayahs of the same surah around [ayahId] whose
  /// stored text for [tafsirId] is identical to that of [ayahId], or null
  /// when [ayahId] has no text. The source explains some groups of
  /// consecutive ayahs in one entry and the import stores that entry for
  /// every ayah of the group; this recovers the group by comparing stored
  /// text only.
  AyahRange? sharedRange(int tafsirId, int ayahId) {
    final target = _db.select(
      'SELECT a.surah_id, a.ayah_number FROM ayahs a '
      'JOIN tafsir_texts t ON t.ayah_id = a.id AND t.tafsir_id = ? '
      'WHERE a.id = ?',
      <Object?>[tafsirId, ayahId],
    );
    if (target.isEmpty) return null;
    final surah = target.first['surah_id'] as int;
    final number = target.first['ayah_number'] as int;

    // Ayah numbers of the surah whose text equals the target's. The text is
    // compared inside SQLite, over the surah's primary-key range only.
    final same = <int>{
      for (final r in _db.select(
        '''
        SELECT a.ayah_number FROM tafsir_texts t
        JOIN ayahs a ON a.id = t.ayah_id
        WHERE t.tafsir_id = ?1
          AND t.ayah_id BETWEEN
            (SELECT MIN(id) FROM ayahs WHERE surah_id = ?2) AND
            (SELECT MAX(id) FROM ayahs WHERE surah_id = ?2)
          AND t.text = (SELECT text FROM tafsir_texts
                        WHERE tafsir_id = ?1 AND ayah_id = ?3)
        ''',
        <Object?>[tafsirId, surah, ayahId],
      ))
        r['ayah_number'] as int,
    };
    var from = number;
    var to = number;
    while (same.contains(from - 1)) {
      from--;
    }
    while (same.contains(to + 1)) {
      to++;
    }
    return AyahRange(AyahRef(surah, from), AyahRef(surah, to));
  }

  /// The text of [tafsirId] for [ayahId] with the ayahs it covers, or null
  /// when there is no text.
  TafsirEntry? entry(int tafsirId, int ayahId) {
    final text = this.text(tafsirId, ayahId);
    final covers = sharedRange(tafsirId, ayahId);
    if (text == null || covers == null) return null;
    return TafsirEntry(
      tafsirId: tafsirId,
      ayahId: ayahId,
      text: text,
      covers: covers,
    );
  }
}

/// The tafsir repository over the installed content database.
final tafsirRepositoryProvider = FutureProvider<TafsirRepository>(
  retry: contentNoRetry,

  (ref) async =>
      TafsirRepository(await ref.watch(quranDatabaseProvider.future)),
);
