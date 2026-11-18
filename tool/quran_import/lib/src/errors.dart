/// Raised whenever the source data violates an expectation of the import.
///
/// The import never guesses or patches data: every unexpected shape, count or
/// value ends the run with one of these, and the CLI exits non-zero.
class ImportException implements Exception {
  ImportException(this.message);

  final String message;

  @override
  String toString() => 'ImportException: $message';
}

final _verseKeyPattern = RegExp(r'^([1-9][0-9]{0,2}):([1-9][0-9]{0,2})$');

/// Parses a verse key such as `2:255` into (surah, ayah), or fails.
(int, int) parseVerseKey(String key) {
  final m = _verseKeyPattern.firstMatch(key);
  check(m != null, () => 'invalid verse key "$key"');
  return (int.parse(m!.group(1)!), int.parse(m.group(2)!));
}

/// Throws an [ImportException] with [message] unless [condition] holds.
void check(bool condition, String Function() message) {
  if (!condition) throw ImportException(message());
}
