import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muslim/data/models/ayah_ref.dart';
import 'package:muslim/data/quran_database.dart';
import 'package:muslim/data/quran_repository.dart';
import 'package:muslim/data/reciter_repository.dart';
import 'package:muslim/data/tafsir_repository.dart';

void main() {
  test('repositories are built on the database provider', () async {
    final container = ProviderContainer(
      overrides: [
        quranDatabaseProvider.overrideWith(
          (ref) async => QuranDatabase.openFile(QuranDatabase.assetKey),
        ),
      ],
    );
    addTearDown(container.dispose);

    final quran = await container.read(quranRepositoryProvider.future);
    final tafsir = await container.read(tafsirRepositoryProvider.future);
    final reciters = await container.read(reciterRepositoryProvider.future);

    expect(quran.surahs(), hasLength(114));
    expect(tafsir.tafsirs(), isNotEmpty);
    expect(reciters.reciters(), isNotEmpty);
    expect(
      reciters.audioUrl(reciters.reciters().first.id, AyahRef(1, 1)).scheme,
      'https',
    );
  });

  test('a database failure surfaces as a QuranDatabaseException', () async {
    final container = ProviderContainer(
      overrides: [
        quranDatabaseProvider.overrideWith(
          (ref) async => QuranDatabase.openFile('missing/quran.db'),
        ),
      ],
    );
    addTearDown(container.dispose);

    await expectLater(
      container.read(quranRepositoryProvider.future),
      throwsA(isA<QuranDatabaseException>()),
    );
  });
}
