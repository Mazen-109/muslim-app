// TafsirRepository against the real bundled database. Assertions use ids,
// keys, counts and hashes only, never tafsir text.
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muslim/data/models/ayah_ref.dart';
import 'package:muslim/data/quran_database.dart';
import 'package:muslim/data/quran_repository.dart';
import 'package:muslim/data/tafsir_repository.dart';

const int _muyassar = 16;

String _sha(String s) => sha256.convert(utf8.encode(s)).toString();

void main() {
  late QuranDatabase database;
  late QuranRepository quran;
  late TafsirRepository repository;

  setUpAll(() {
    database = QuranDatabase.openFile(QuranDatabase.assetKey);
    quran = QuranRepository(database);
    repository = TafsirRepository(database);
  });

  tearDownAll(() {
    quran.dispose();
    database.close();
  });

  /// Ayah ids whose stored text equals that of the previous ayah of the
  /// same surah, read directly with SQL.
  List<int> continuations() => <int>[
    for (final r in database.db.select('''
      SELECT t.ayah_id FROM tafsir_texts t
      JOIN tafsir_texts p ON p.tafsir_id = t.tafsir_id
        AND p.ayah_id = t.ayah_id - 1
      JOIN ayahs a ON a.id = t.ayah_id
      JOIN ayahs b ON b.id = p.ayah_id
      WHERE t.tafsir_id = $_muyassar AND a.surah_id = b.surah_id
        AND t.text = p.text
      ORDER BY t.ayah_id
    '''))
      r['ayah_id'] as int,
  ];

  test('metadata', () {
    final tafsirs = repository.tafsirs();
    expect(tafsirs.map((t) => t.id), <int>[_muyassar]);
    expect(tafsirs.single.slug, 'ar-tafsir-muyassar');
    expect(tafsirs.single.language, 'arabic');
    expect(repository.tafsir(_muyassar), tafsirs.single);
    expect(repository.tafsir(14), isNull);
  });

  test('text is returned exactly as stored for every ayah', () {
    final direct = <String>[
      for (final r in database.db.select(
        'SELECT text FROM tafsir_texts WHERE tafsir_id = ? ORDER BY ayah_id',
        <Object?>[_muyassar],
      ))
        r['text'] as String,
    ];
    final viaRepository = <String>[
      for (var id = 1; id <= 6236; id++) repository.text(_muyassar, id)!,
    ];
    expect(_sha(viaRepository.join('\u001E')), _sha(direct.join('\u001E')));
    expect(repository.text(_muyassar, 0), isNull);
    expect(repository.text(14, 1), isNull);
  });

  test('958 ayahs continue a grouped entry', () {
    expect(continuations(), hasLength(958));
  });

  test('shared range of a grouped ayah', () {
    // The first grouped run in the data: its first ayah, then every ayah
    // that continues it.
    final continued = continuations();
    final first = continued.first - 1;
    var last = continued.first;
    while (continued.contains(last + 1)) {
      last++;
    }
    final range = AyahRange(quran.refOf(first), quran.refOf(last));
    expect(range.isSingle, isFalse);
    for (var id = first; id <= last; id++) {
      expect(repository.sharedRange(_muyassar, id), range, reason: 'ayah $id');
      final entry = repository.entry(_muyassar, id)!;
      expect(entry.covers, range);
      expect(entry.ayahId, id);
      expect(_sha(entry.text), _sha(repository.text(_muyassar, first)!));
    }
    // The neighbours outside the run are not part of it.
    expect(
      repository.sharedRange(_muyassar, first - 1)!.contains(range.from),
      isFalse,
    );
    expect(
      repository.sharedRange(_muyassar, last + 1)!.contains(range.to),
      isFalse,
    );
  });

  test('shared range of an ungrouped ayah is that ayah', () {
    final continued = continuations().toSet();
    // 1:1 starts no group when 1:2 does not continue it.
    expect(continued.contains(2), isFalse);
    expect(
      repository.sharedRange(_muyassar, 1),
      AyahRange.single(AyahRef(1, 1)),
    );
    final id = quran.ayahIdOf(AyahRef(2, 255));
    expect(continued.contains(id) || continued.contains(id + 1), isFalse);
    expect(
      repository.entry(_muyassar, id)!.covers,
      AyahRange.single(AyahRef(2, 255)),
    );
  });

  test('every shared range matches the SQL continuation runs', () {
    final continued = continuations().toSet();
    var grouped = 0;
    final wrong = <int>[];
    for (var id = 1; id <= 6236; id++) {
      final ref = quran.refOf(id);
      final range = repository.sharedRange(_muyassar, id)!;
      if (!range.isSingle) grouped++;
      // The range holds the ayah, starts where its run starts and ends
      // where its run ends.
      final startsRun = !continued.contains(id);
      final endsRun = !continued.contains(id + 1);
      if (!range.contains(ref) ||
          (range.from == ref) != startsRun ||
          (range.to == ref) != endsRun) {
        wrong.add(id);
      }
    }
    expect(wrong, isEmpty);
    expect(grouped, 958 + 494);
  });

  test('no shared range or entry for an ayah without text', () {
    expect(repository.sharedRange(14, 1), isNull);
    expect(repository.entry(14, 1), isNull);
  });
}
