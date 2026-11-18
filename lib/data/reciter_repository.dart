import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqlite3/sqlite3.dart';

import 'models/ayah_ref.dart';
import 'models/reciter.dart';
import 'quran_database.dart';

/// Read access to reciters and their per-ayah audio URLs.
class ReciterRepository {
  ReciterRepository(QuranDatabase database) : _db = database.db;

  final Database _db;

  /// Every reciter in display order (`sort_order`, then id).
  List<Reciter> reciters() => List<Reciter>.unmodifiable(
    _db
        .select(
          'SELECT id, name_ar, name_en, style, url_template, source_id, '
          'sort_order FROM reciters ORDER BY sort_order, id',
        )
        .map(
          (r) => Reciter(
            id: r['id'] as int,
            nameAr: r['name_ar'] as String,
            nameEn: r['name_en'] as String,
            style: ReciterStyle.parse(r['style'] as String?),
            urlTemplate: r['url_template'] as String,
            sourceId: r['source_id'] as String,
            sortOrder: r['sort_order'] as int,
          ),
        ),
  );

  /// The reciter with [id], or null.
  Reciter? reciter(int id) {
    for (final r in reciters()) {
      if (r.id == id) return r;
    }
    return null;
  }

  /// The audio file of [ref] recited by [reciterId]. Throws [ArgumentError]
  /// for an unknown reciter and [RangeError] for an ayah the surah does not
  /// have.
  Uri audioUrl(int reciterId, AyahRef ref) {
    final reciter = this.reciter(reciterId);
    if (reciter == null) {
      throw ArgumentError.value(reciterId, 'reciterId', 'unknown reciter');
    }
    final count =
        _db.select('SELECT ayah_count FROM surahs WHERE id = ?', <Object?>[
              ref.surah,
            ]).single['ayah_count']
            as int;
    RangeError.checkValueInInterval(ref.ayah, 1, count, 'ayah');
    return reciter.audioUrl(ref);
  }
}

/// The reciter repository over the installed content database.
final reciterRepositoryProvider = FutureProvider<ReciterRepository>(
  retry: contentNoRetry,

  (ref) async =>
      ReciterRepository(await ref.watch(quranDatabaseProvider.future)),
);
