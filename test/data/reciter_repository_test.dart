import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:muslim/data/models/ayah_ref.dart';
import 'package:muslim/data/models/reciter.dart';
import 'package:muslim/data/quran_database.dart';
import 'package:muslim/data/reciter_repository.dart';
import 'package:muslim/data/sources_registry.dart';

void main() {
  late QuranDatabase database;
  late ReciterRepository repository;

  setUpAll(() {
    database = QuranDatabase.openFile(QuranDatabase.assetKey);
    repository = ReciterRepository(database);
  });

  tearDownAll(() => database.close());

  test('reciters come in sort_order', () {
    final reciters = repository.reciters();
    expect(reciters.map((r) => r.id), <int>[12, 6, 9, 7, 2]);
    expect(reciters.map((r) => r.sortOrder), <int>[1, 2, 3, 4, 5]);
    expect(reciters.first.style, ReciterStyle.muallim);
    expect(repository.reciter(9), reciters[2]);
    expect(repository.reciter(999), isNull);
  });

  test('every template is https with both placeholders', () {
    for (final reciter in repository.reciters()) {
      expect(reciter.urlTemplate, startsWith('https://'));
      expect(reciter.urlTemplate, contains('{surah3}'));
      expect(reciter.urlTemplate, contains('{ayah3}'));
    }
  });

  test('audio URLs for each reciter', () {
    final expected = <int, String>{
      12: 'https://everyayah.com/data/Husary_Muallim_128kbps/',
      6: 'https://everyayah.com/data/Husary_64kbps/',
      9: 'https://verses.quran.com/Minshawi/Murattal/mp3/',
      7: 'https://verses.quran.com/Alafasy/mp3/',
      2: 'https://verses.quran.com/AbdulBaset/Murattal/mp3/',
    };
    for (final MapEntry(key: id, value: prefix) in expected.entries) {
      expect(
        repository.audioUrl(id, AyahRef(1, 1)).toString(),
        '${prefix}001001.mp3',
      );
      expect(
        repository.audioUrl(id, AyahRef(2, 255)).toString(),
        '${prefix}002255.mp3',
      );
      expect(
        repository.audioUrl(id, AyahRef(114, 6)).toString(),
        '${prefix}114006.mp3',
      );
      expect(
        repository.audioUrl(id, AyahRef(18, 10)).toString(),
        '${prefix}018010.mp3',
      );
    }
  });

  test('audio URL rejects unknown reciters and ayahs', () {
    expect(() => repository.audioUrl(999, AyahRef(1, 1)), throwsArgumentError);
    expect(() => repository.audioUrl(12, AyahRef(1, 8)), throwsRangeError);
  });

  test('every reciter source_id is in the sources registry', () {
    final registry = SourcesRegistry.parse(
      File(sourcesRegistryAsset).readAsStringSync(),
    );
    for (final reciter in repository.reciters()) {
      expect(
        registry.byId(reciter.sourceId),
        isNotNull,
        reason: '${reciter.id}',
      );
    }
  });
}
