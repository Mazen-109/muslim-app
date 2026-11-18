/// Table content hashes of the bundled Quran dataset, recomputed from
/// `assets/data/quran.db` for comparison with `assets/data/manifest.json`.
///
/// This mirrors the definition in `tool/quran_import/lib/src/hashing.dart`
/// (data-model.md section 2) without importing the tool package:
///
/// 1. Read every row of the table in primary-key order, with the columns in
///    the order of data-model.md section 1.
/// 2. Write each value as a string: an INTEGER as its decimal form, a TEXT
///    value unchanged, NULL as the empty string. Any other storage class is
///    an error.
/// 3. Join a row's values with U+001F and the rows with U+001E, with no
///    leading or trailing separator.
/// 4. Take the SHA-256 of the UTF-8 encoding, as 64 lower-case hex digits.
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:sqlite3/sqlite3.dart';

const String unitSeparator = '\u001F';
const String recordSeparator = '\u001E';

/// A table's hashed columns and its primary-key order.
class HashedTable {
  const HashedTable(this.name, this.columns, this.orderBy);

  final String name;
  final List<String> columns;
  final List<String> orderBy;

  String get selectSql =>
      'SELECT ${columns.join(', ')} FROM $name ORDER BY ${orderBy.join(', ')}';
}

/// Every table with a hash in the manifest.
const List<HashedTable> hashedTables = <HashedTable>[
  HashedTable(
    'surahs',
    <String>[
      'id',
      'name_ar',
      'name_en',
      'revelation_place',
      'revelation_order',
      'ayah_count',
      'bismillah_pre',
      'page_start',
      'page_end',
    ],
    <String>['id'],
  ),
  HashedTable(
    'ayahs',
    <String>[
      'id',
      'surah_id',
      'ayah_number',
      'verse_key',
      'text_qpc_hafs',
      'text_uthmani',
      'text_search',
      'text_search_folded',
      'page',
      'juz',
      'hizb',
      'rub_el_hizb',
      'sajdah',
    ],
    <String>['id'],
  ),
  HashedTable(
    'words',
    <String>[
      'id',
      'ayah_id',
      'position',
      'char_type',
      'text_qpc_hafs',
      'page',
      'line',
    ],
    <String>['id'],
  ),
  HashedTable(
    'page_lines',
    <String>['page', 'line', 'line_type', 'surah_id'],
    <String>['page', 'line'],
  ),
  HashedTable(
    'juzs',
    <String>['id', 'first_ayah_id', 'last_ayah_id', 'page_start'],
    <String>['id'],
  ),
  HashedTable(
    'tafsirs',
    <String>['id', 'name_ar', 'author', 'language', 'slug'],
    <String>['id'],
  ),
  HashedTable(
    'tafsir_texts',
    <String>['tafsir_id', 'ayah_id', 'text'],
    <String>['tafsir_id', 'ayah_id'],
  ),
  HashedTable(
    'reciters',
    <String>[
      'id',
      'name_ar',
      'name_en',
      'style',
      'url_template',
      'source_id',
      'sort_order',
    ],
    <String>['id'],
  ),
];

/// Hashes rows that are already in primary-key order.
String hashRows(Iterable<List<Object?>> rows) {
  final String text = rows
      .map((List<Object?> row) => row.map(_cell).join(unitSeparator))
      .join(recordSeparator);
  return sha256.convert(utf8.encode(text)).toString();
}

String _cell(Object? value) => switch (value) {
  null => '',
  int() => value.toString(),
  String() => value,
  _ => throw ArgumentError(
    'cannot hash a value of type ${value.runtimeType}: only INTEGER, TEXT '
    'and NULL are allowed',
  ),
};

/// Hashes one table of [db].
String hashTable(Database db, HashedTable table) =>
    hashRows(db.select(table.selectSql).map((Row r) => r.values));
