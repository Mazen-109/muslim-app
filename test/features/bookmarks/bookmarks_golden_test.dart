import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:muslim/core/routing/app_router.dart';
import 'package:muslim/data/bookmark_repository.dart';
import 'package:muslim/data/models/ayah_ref.dart';
import 'package:muslim/data/quran_repository.dart';

import '../../helpers/fonts.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/quran_database.dart';

// Goldens of T018 at phone size in the light theme, checked by eye against
// DESIGN.md: the bookmarks screen with both sections filled, and a Mushaf
// page with a bookmarked ayah, a memorised one and one that is both. Ayahs
// are chosen by key; the text and the surah names come from the bundled
// database and nothing here names or contains them.

const Size phone = Size(400, 800);

void main() {
  late QuranRepository quran;
  late void Function() close;

  setUpAll(() async {
    await loadAppFonts();
    (quran, close) = openBundledQuranRepository();
  });
  tearDownAll(() => close());

  int idOf(String key) => quran.ayahIdOf(AyahRef.parse(key));

  /// Pumps the app with a fixed clock, then sets [bookmarks] and
  /// [memorised] in order, each one second after the one before.
  Future<ProviderContainer> pumpWithMarks(
    WidgetTester tester, {
    required List<String> bookmarks,
    required List<String> memorised,
  }) async {
    var millis = 1700000000000;
    final container = await pumpApp(
      tester,
      size: phone,
      overrides: [
        clockProvider.overrideWithValue(
          () => DateTime.fromMillisecondsSinceEpoch(millis += 1000),
        ),
      ],
    );
    final bookmarkRepository = await container.read(
      bookmarkRepositoryProvider.future,
    );
    final memorisedRepository = await container.read(
      memorisationRepositoryProvider.future,
    );
    for (final key in bookmarks) {
      bookmarkRepository.add(idOf(key));
    }
    for (final key in memorised) {
      memorisedRepository.add(idOf(key));
    }
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('bookmarks screen', (tester) async {
    final container = await pumpWithMarks(
      tester,
      bookmarks: <String>['2:255', '18:10', '36:1'],
      memorised: <String>['112:1', '112:2'],
    );
    container.read(appRouterProvider).go(AppRoutes.bookmarks);
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../goldens/bookmarks/screen_light.png'),
    );
  });

  testWidgets('indicators on a page', (tester) async {
    final container = await pumpWithMarks(
      tester,
      bookmarks: <String>['2:7', '2:10'],
      memorised: <String>['2:9', '2:10', '2:12'],
    );
    container
        .read(appRouterProvider)
        .go(AppRoutes.mushafPage(quran.pageOf(idOf('2:7'))));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../goldens/bookmarks/page_indicators_light.png'),
    );
  });
}
