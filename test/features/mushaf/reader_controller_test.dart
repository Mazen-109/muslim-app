import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muslim/core/settings/settings_providers.dart';
import 'package:muslim/core/settings/settings_repository.dart';
import 'package:muslim/data/models/ayah_ref.dart';
import 'package:muslim/data/models/mushaf_page.dart';
import 'package:muslim/data/models/word.dart';
import 'package:muslim/data/quran_repository.dart';
import 'package:muslim/features/mushaf/reader_controller.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/quran_database.dart';

// The reader's one position. Ayahs are named by key and id only.

void main() {
  late QuranRepository repository;
  late void Function() closeRepository;

  setUpAll(() {
    (repository, closeRepository) = openBundledQuranRepository();
  });
  tearDownAll(() => closeRepository());

  Future<ProviderContainer> container({
    Map<String, Object> preferences = const <String, Object>{},
  }) async {
    final c = ProviderContainer(
      overrides: await appTestOverrides(preferences: preferences),
    );
    addTearDown(c.dispose);
    await c.read(quranRepositoryProvider.future);
    return c;
  }

  int idOf(String key) => repository.ayahIdOf(AyahRef.parse(key));

  test('starts in the saved reading mode', () async {
    final c = await container(
      preferences: <String, Object>{
        SettingsRepository.readingModeKey: ReadingMode.continuous.storageValue,
      },
    );
    expect(c.read(readerControllerProvider).mode, ReadingMode.continuous);
  });

  test('an ayah link moves to its page without a highlight', () async {
    final c = await container();
    c
        .read(readerControllerProvider.notifier)
        .open(AyahTarget(AyahRef.parse('2:255')));

    final state = c.read(readerControllerProvider);
    expect(state.currentAyahId, idOf('2:255'));
    expect(state.page, repository.pageOf(idOf('2:255')));
    expect(state.highlightedAyahId, isNull);
  });

  test('a highlight link flashes the ayah until the page turns', () async {
    final c = await container();
    final controller = c.read(readerControllerProvider.notifier);
    controller.open(AyahTarget(AyahRef.parse('2:255'), highlight: true));

    var state = c.read(readerControllerProvider);
    expect(state.highlightedAyahId, idOf('2:255'));
    expect(state.highlightIsFlash, isTrue);

    // The page view reporting the page it already shows changes nothing.
    controller.showPage(state.page);
    expect(c.read(readerControllerProvider), state);

    controller.showPage(state.page + 1);
    state = c.read(readerControllerProvider);
    expect(state.highlightedAyahId, isNull);
  });

  test('a page link moves to the first ayah that starts on it', () async {
    final c = await container();
    c.read(readerControllerProvider.notifier).open(const PageTarget(50));

    final state = c.read(readerControllerProvider);
    expect(state.page, 50);
    expect(repository.pageOf(state.currentAyahId), 50);
    expect(repository.pageOf(state.currentAyahId - 1), lessThan(50));
  });

  test('turning to any page and back returns to that page', () async {
    final c = await container();
    final controller = c.read(readerControllerProvider.notifier);
    for (var p = 1; p <= pageCount; p++) {
      controller.showPage(p);
      final state = c.read(readerControllerProvider);
      expect(state.page, p);
      expect(repository.pageOf(state.currentAyahId), p, reason: 'page $p');
    }
  });

  test('the audio follower keeps the highlight across pages', () async {
    final c = await container();
    final controller = c.read(readerControllerProvider.notifier);
    controller.goToAyah(idOf('2:5'));
    controller.highlight(idOf('2:6'));
    controller.setCurrentAyah(idOf('2:6'));
    controller.highlight(idOf('2:30'));
    controller.setCurrentAyah(idOf('2:30'));

    final state = c.read(readerControllerProvider);
    expect(state.currentAyahId, idOf('2:30'));
    expect(state.page, repository.pageOf(idOf('2:30')));
    expect(state.highlightedAyahId, idOf('2:30'));

    controller.highlight(null);
    expect(c.read(readerControllerProvider).highlightedAyahId, isNull);
  });

  test('the mode switch persists and keeps the ayah', () async {
    final c = await container();
    final controller = c.read(readerControllerProvider.notifier);
    controller.goToAyah(idOf('36:1'));
    await controller.setMode(ReadingMode.continuous);

    expect(c.read(readerControllerProvider).mode, ReadingMode.continuous);
    expect(c.read(readerControllerProvider).currentAyahId, idOf('36:1'));
    expect(c.read(readingModeProvider), ReadingMode.continuous);
  });

  test('targets parse from validated /mushaf queries', () {
    expect(
      ReaderTarget.fromQuery(const <String, String>{'page': '604'}),
      const PageTarget(604),
    );
    expect(
      ReaderTarget.fromQuery(const <String, String>{
        'ayah': '2:255',
        'highlight': '1',
      }),
      AyahTarget(AyahRef(2, 255), highlight: true),
    );
    expect(
      ReaderTarget.fromQuery(const <String, String>{'ayah': '2:255'}),
      AyahTarget(AyahRef(2, 255)),
    );
    expect(
      () => ReaderTarget.fromQuery(const <String, String>{}),
      throwsFormatException,
    );
  });

  test(
    'firstAyahStartingOn skips an ayah carried over from the page before',
    () {
      for (final p in <int>[1, 2, 3, 50, 300, 604]) {
        final page = repository.page(p);
        final id = firstAyahStartingOn(page);
        final words = page.lines.whereType<AyahLine>().expand((l) => l.words);
        expect(
          words.any(
            (w) =>
                w.ayahId == id &&
                w.position == 1 &&
                w.charType == WordCharType.word,
          ),
          isTrue,
          reason: 'page $p',
        );
      }
    },
  );
}
