/// The provenance manifest (contracts/dataset-manifest.schema.json).
library;

import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

import 'api_client.dart';
import 'errors.dart';
import 'validate.dart';

const manifestSchemaVersion = 1;

/// Row counts as the manifest defines them, read from [db].
Map<String, int> countRows(Database db) {
  int count(String sql) => db.select(sql).first.values.first as int;
  return {
    'surahs': count('SELECT COUNT(*) FROM surahs'),
    'ayahs': count('SELECT COUNT(*) FROM ayahs'),
    'words': count('SELECT COUNT(*) FROM words'),
    'pages': count('SELECT COUNT(DISTINCT page) FROM page_lines'),
    'page_lines': count('SELECT COUNT(*) FROM page_lines'),
    'juzs': count('SELECT COUNT(*) FROM juzs'),
    'tafsir_texts': count('SELECT COUNT(*) FROM tafsir_texts'),
    'reciters': count('SELECT COUNT(*) FROM reciters'),
  };
}

/// Checks [counts] against the constants and minimums of the manifest
/// schema.
void checkManifestCounts(Map<String, int> counts) {
  const exact = {
    'surahs': expectedSurahs,
    'ayahs': expectedAyahs,
    'pages': expectedPages,
    'page_lines': expectedPageLines,
    'juzs': expectedJuzs,
    'tafsir_texts': expectedAyahs,
  };
  for (final e in exact.entries) {
    check(
      counts[e.key] == e.value,
      () => 'manifest count ${e.key} is ${counts[e.key]}, expected ${e.value}',
    );
  }
  check(
    (counts['words'] ?? 0) >= minimumWords,
    () =>
        'manifest count words is ${counts['words']}, expected at least '
        '$minimumWords',
  );
  check(
    (counts['reciters'] ?? 0) >= minimumReciters,
    () =>
        'manifest count reciters is ${counts['reciters']}, expected at '
        'least $minimumReciters',
  );
}

/// Renders the manifest JSON (two-space indent, trailing newline).
String buildManifest({
  required int datasetVersion,
  required String generatedAt,
  required String toolVersion,
  required List<RequestRecord> requests,
  required Map<String, int> counts,
  required Map<String, String> tableHashes,
}) {
  check(requests.isNotEmpty, () => 'manifest: no requests recorded');
  for (final r in requests) {
    check(
      r.url.startsWith('https://') &&
          r.bytes >= 1 &&
          RegExp(r'^[a-f0-9]{64}$').hasMatch(r.sha256),
      () => 'manifest: invalid request record for ${r.url}',
    );
  }
  final json = {
    'schema_version': manifestSchemaVersion,
    'dataset_version': datasetVersion,
    'generated_at': generatedAt,
    'tool_version': toolVersion,
    'requests': [for (final r in requests) r.toJson()],
    'counts': counts,
    'table_hashes': tableHashes,
  };
  return '${const JsonEncoder.withIndent('  ').convert(json)}\n';
}
