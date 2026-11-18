/// Table content hashes recorded in `manifest.json`.
///
/// Definition (also used by the app's dataset integrity test):
///
/// 1. Read every row of the table in primary-key order, with the columns in
///    the order declared in data-model.md section 1 (see [hashedTables]).
/// 2. Write each value as a string: an INTEGER as its decimal form (`-` sign
///    if negative, no leading zeros), a TEXT value unchanged, NULL as the
///    empty string. No other storage class occurs.
/// 3. Join a row's values with U+001F (unit separator), and the rows with
///    U+001E (record separator). There is no leading or trailing separator.
/// 4. Encode the resulting string as UTF-8 and take its SHA-256, written as
///    64 lower-case hex digits.
///
/// An empty table hashes the empty string.
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:sqlite3/sqlite3.dart';

import 'errors.dart';

const unitSeparator = '\u001F';
const recordSeparator = '\u001E';

/// A table's hashed columns and its primary-key order.
class TableSpec {
  const TableSpec(this.name, this.columns, this.orderBy);

  final String name;
  final List<String> columns;
  final List<String> orderBy;

  String get selectSql =>
      'SELECT ${columns.join(', ')} FROM $name ORDER BY ${orderBy.join(', ')}';
}

/// Every table with a hash in the manifest, in manifest order.
const hashedTables = [
  TableSpec(
    'surahs',
    [
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
    ['id'],
  ),
  TableSpec(
    'ayahs',
    [
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
    ['id'],
  ),
  TableSpec(
    'words',
    ['id', 'ayah_id', 'position', 'char_type', 'text_qpc_hafs', 'page', 'line'],
    ['id'],
  ),
  TableSpec(
    'page_lines',
    ['page', 'line', 'line_type', 'surah_id'],
    ['page', 'line'],
  ),
  TableSpec(
    'juzs',
    ['id', 'first_ayah_id', 'last_ayah_id', 'page_start'],
    ['id'],
  ),
  TableSpec('tafsirs', ['id', 'name_ar', 'author', 'language', 'slug'], ['id']),
  TableSpec(
    'tafsir_texts',
    ['tafsir_id', 'ayah_id', 'text'],
    ['tafsir_id', 'ayah_id'],
  ),
  TableSpec(
    'reciters',
    [
      'id',
      'name_ar',
      'name_en',
      'style',
      'url_template',
      'source_id',
      'sort_order',
    ],
    ['id'],
  ),
];

/// Hashes rows already in primary-key order, per the library definition.
String hashRows(Iterable<List<Object?>> rows) {
  final text = rows
      .map((row) => row.map(_cell).join(unitSeparator))
      .join(recordSeparator);
  return sha256.convert(utf8.encode(text)).toString();
}

String _cell(Object? v) => switch (v) {
  null => '',
  int() => v.toString(),
  String() => v,
  _ => throw ImportException(
    'cannot hash value of type ${v.runtimeType}: only INTEGER, TEXT and NULL '
    'are allowed',
  ),
};

/// Hashes one table of [db] per the library definition.
String hashTable(Database db, TableSpec spec) =>
    hashRows(db.select(spec.selectSql).map((r) => r.values));

/// Hashes every table in [hashedTables].
Map<String, String> hashAllTables(Database db) => {
  for (final spec in hashedTables) spec.name: hashTable(db, spec),
};
