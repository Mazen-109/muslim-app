/// Writes `quran.db` with the schema of data-model.md section 1.
library;

import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

import 'dataset.dart';
import 'errors.dart';

/// The content database schema (data-model.md section 1). CHECK constraints
/// encode the column rules that SQLite can express.
const schemaSql = '''
CREATE TABLE meta (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);

CREATE TABLE surahs (
  id INTEGER PRIMARY KEY CHECK (id BETWEEN 1 AND 114),
  name_ar TEXT NOT NULL,
  name_en TEXT NOT NULL,
  revelation_place TEXT NOT NULL CHECK (revelation_place IN ('makkah', 'madinah')),
  revelation_order INTEGER NOT NULL UNIQUE CHECK (revelation_order BETWEEN 1 AND 114),
  ayah_count INTEGER NOT NULL,
  bismillah_pre INTEGER NOT NULL CHECK (bismillah_pre IN (0, 1)),
  page_start INTEGER NOT NULL CHECK (page_start BETWEEN 1 AND 604),
  page_end INTEGER NOT NULL CHECK (page_end BETWEEN page_start AND 604)
);

CREATE TABLE ayahs (
  id INTEGER PRIMARY KEY CHECK (id BETWEEN 1 AND 6236),
  surah_id INTEGER NOT NULL REFERENCES surahs (id),
  ayah_number INTEGER NOT NULL CHECK (ayah_number >= 1),
  verse_key TEXT NOT NULL UNIQUE,
  text_qpc_hafs TEXT NOT NULL,
  text_uthmani TEXT NOT NULL,
  text_search TEXT NOT NULL,
  text_search_folded TEXT NOT NULL,
  page INTEGER NOT NULL CHECK (page BETWEEN 1 AND 604),
  juz INTEGER NOT NULL CHECK (juz BETWEEN 1 AND 30),
  hizb INTEGER NOT NULL CHECK (hizb BETWEEN 1 AND 60),
  rub_el_hizb INTEGER NOT NULL CHECK (rub_el_hizb BETWEEN 1 AND 240),
  sajdah INTEGER
);
CREATE UNIQUE INDEX ayahs_surah_ayah ON ayahs (surah_id, ayah_number);
CREATE INDEX ayahs_page ON ayahs (page);
CREATE INDEX ayahs_juz ON ayahs (juz);

CREATE TABLE words (
  id INTEGER PRIMARY KEY,
  ayah_id INTEGER NOT NULL REFERENCES ayahs (id),
  position INTEGER NOT NULL CHECK (position >= 1),
  char_type TEXT NOT NULL CHECK (char_type IN ('word', 'end')),
  text_qpc_hafs TEXT NOT NULL,
  page INTEGER NOT NULL CHECK (page BETWEEN 1 AND 604),
  line INTEGER NOT NULL CHECK (line BETWEEN 1 AND 15)
);
CREATE INDEX words_page_line ON words (page, line, ayah_id, position);
CREATE UNIQUE INDEX words_ayah_position ON words (ayah_id, position);

CREATE TABLE page_lines (
  page INTEGER NOT NULL CHECK (page BETWEEN 1 AND 604),
  line INTEGER NOT NULL CHECK (line BETWEEN 1 AND 15),
  line_type TEXT NOT NULL CHECK (line_type IN ('ayah', 'surah_name', 'basmala')),
  surah_id INTEGER REFERENCES surahs (id),
  PRIMARY KEY (page, line),
  CHECK ((line_type = 'ayah') = (surah_id IS NULL))
);

CREATE TABLE juzs (
  id INTEGER PRIMARY KEY CHECK (id BETWEEN 1 AND 30),
  first_ayah_id INTEGER NOT NULL REFERENCES ayahs (id),
  last_ayah_id INTEGER NOT NULL REFERENCES ayahs (id),
  page_start INTEGER NOT NULL CHECK (page_start BETWEEN 1 AND 604)
);

CREATE TABLE tafsirs (
  id INTEGER PRIMARY KEY,
  name_ar TEXT NOT NULL,
  author TEXT NOT NULL,
  language TEXT NOT NULL,
  slug TEXT NOT NULL UNIQUE
);

CREATE TABLE tafsir_texts (
  tafsir_id INTEGER NOT NULL REFERENCES tafsirs (id),
  ayah_id INTEGER NOT NULL REFERENCES ayahs (id),
  text TEXT NOT NULL,
  PRIMARY KEY (tafsir_id, ayah_id)
);

CREATE TABLE reciters (
  id INTEGER PRIMARY KEY,
  name_ar TEXT NOT NULL,
  name_en TEXT NOT NULL,
  style TEXT CHECK (style IN ('murattal', 'mujawwad', 'muallim')),
  url_template TEXT NOT NULL,
  source_id TEXT NOT NULL,
  sort_order INTEGER NOT NULL
);
''';

/// Number of columns per table, for inserts in declared column order.
const _insertColumns = {
  'surahs': 9,
  'ayahs': 13,
  'words': 7,
  'page_lines': 4,
  'juzs': 4,
  'tafsirs': 5,
  'tafsir_texts': 3,
  'reciters': 7,
};

/// Creates a fresh database at [path] (replacing any file there), inserts
/// every row and the [meta] pairs in one transaction, checks integrity and
/// foreign keys, then VACUUMs.
void writeDatabase(String path, Dataset dataset, Map<String, String> meta) {
  final file = File(path);
  if (file.existsSync()) file.deleteSync();
  final db = sqlite3.open(path);
  try {
    db.execute('PRAGMA foreign_keys = ON');
    db.execute(schemaSql);
    db.execute('BEGIN');
    final metaStmt = db.prepare('INSERT INTO meta (key, value) VALUES (?, ?)');
    for (final e in meta.entries) {
      metaStmt.execute([e.key, e.value]);
    }
    metaStmt.close();
    for (final MapEntry(key: table, value: rows) in dataset.tables.entries) {
      final n = _insertColumns[table]!;
      final stmt = db.prepare(
        'INSERT INTO $table VALUES (${List.filled(n, '?').join(', ')})',
      );
      for (final row in rows) {
        final values = row.values;
        check(
          values.length == n,
          () => '$table: row has ${values.length} values, expected $n',
        );
        stmt.execute(values);
      }
      stmt.close();
    }
    db.execute('COMMIT');
    final fk = db.select('PRAGMA foreign_key_check');
    check(fk.isEmpty, () => 'foreign key violations: ${fk.rows}');
    final integrity = db.select('PRAGMA integrity_check');
    check(
      integrity.length == 1 && integrity.first.values.first == 'ok',
      () => 'integrity_check failed: ${integrity.rows}',
    );
    db.execute('VACUUM');
  } finally {
    db.close();
  }
}
