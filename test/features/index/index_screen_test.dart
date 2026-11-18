import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:muslim/app.dart';
import 'package:muslim/core/l10n/generated/app_localizations.dart';
import 'package:muslim/core/routing/app_router.dart';
import 'package:muslim/core/widgets/state_views.dart';
import 'package:muslim/data/models/ayah_ref.dart';
import 'package:muslim/data/models/surah.dart';
import 'package:muslim/data/quran_database.dart';
import 'package:muslim/data/quran_repository.dart';
import 'package:muslim/features/index/index_screen.dart';

import '../../helpers/fonts.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/quran_database.dart';

// The surah and juz index over the real content database. Every name and
// number the tests expect is read from the repository; nothing here is
// typed Quran text or other religious content.

final AppLocalizations ar = lookupAppLocalizations(const Locale('ar'));

const Size phone = Size(400, 800);

Uri location(ProviderContainer container) =>
    container.read(appRouterProvider).routerDelegate.currentConfiguration.uri;

Future<void> go(
  WidgetTester tester,
  ProviderContainer container,
  String path,
) async {
  container.read(appRouterProvider).go(path);
  await tester.pumpAndSettle();
}

Finder surahRow(int id) => find.byKey(ValueKey<String>('surah-$id'));
Finder juzRow(int id) => find.byKey(ValueKey<String>('juz-$id'));

/// The vertical list of [tab] (not the horizontal tab view around it).
Finder listOf(IndexTab tab) => find.descendant(
  of: find.byKey(PageStorageKey<IndexTab>(tab)),
  matching: find.byType(Scrollable),
);

Future<void> showJuzTab(WidgetTester tester) async {
  await tester.tap(find.text(ar.indexTabJuz));
  await tester.pumpAndSettle();
}

/// Scrolls the visible list from top to bottom and returns the ids of the
/// rows of type [T] in the order they were first built. The lists are lazy,
/// so rows are collected while scrolling instead of all at once.
Future<List<int>> collectRows<T extends Widget>(
  WidgetTester tester,
  IndexTab tab,
  int Function(T row) idOf,
) async {
  final list = listOf(tab);
  final seen = <int>[];
  void collect() {
    for (final row in tester.widgetList<T>(find.byType(T))) {
      final id = idOf(row);
      if (!seen.contains(id)) seen.add(id);
    }
  }

  collect();
  // Bounded, so a list that stops scrolling fails instead of hanging.
  for (var drags = 0; drags < 200; drags++) {
    final position = tester.state<ScrollableState>(list).position;
    if (position.pixels >= position.maxScrollExtent) return seen;
    await tester.drag(list, const Offset(0, -300));
    await tester.pumpAndSettle();
    collect();
  }
  fail('The list did not reach its end.');
}

void main() {
  late QuranRepository repository;
  late void Function() closeRepository;

  setUpAll(() async {
    await loadAppFonts();
    (repository, closeRepository) = openBundledQuranRepository();
  });
  tearDownAll(() => closeRepository());

  String placeOf(Surah surah) => switch (surah.revelationPlace) {
    RevelationPlace.makkah => ar.surahMakki,
    RevelationPlace.madinah => ar.surahMadani,
  };

  group('surahs', () {
    testWidgets('is the default tab and lists all 114 surahs in order', (
      tester,
    ) async {
      final container = await pumpApp(tester, size: phone);
      expect(location(container).path, AppRoutes.index);

      final ids = await collectRows<SurahRow>(
        tester,
        IndexTab.surahs,
        (row) => row.surah.id,
      );
      expect(ids, <int>[for (final s in repository.surahs()) s.id]);
      expect(ids, hasLength(114));
    });

    for (final id in <int>[1, 114]) {
      testWidgets('row $id shows its number, name, place, ayahs and page', (
        tester,
      ) async {
        await pumpApp(tester, size: phone);
        final surah = repository.surah(id);

        await tester.scrollUntilVisible(
          surahRow(id),
          300,
          scrollable: listOf(IndexTab.surahs),
        );
        final row = surahRow(id);
        Finder inRow(String text) =>
            find.descendant(of: row, matching: find.text(text));

        expect(inRow('$id'), findsOneWidget);
        expect(inRow(surah.nameAr), findsOneWidget);
        expect(
          inRow(ar.surahDetails(placeOf(surah), ar.ayahCount(surah.ayahCount))),
          findsOneWidget,
        );
        expect(inRow(ar.pageNumber(surah.pageStart)), findsOneWidget);
      });
    }

    testWidgets('names use the interface font, not the Quran font', (
      tester,
    ) async {
      await pumpApp(tester, size: phone);
      final name = find.descendant(
        of: surahRow(1),
        matching: find.text(repository.surah(1).nameAr),
      );

      final style = DefaultTextStyle.of(tester.element(name)).style;
      final theme = Theme.of(tester.element(name));
      expect(style.fontFamily, theme.textTheme.bodyLarge!.fontFamily);
    });

    testWidgets('a row opens the Mushaf at the first ayah of its surah', (
      tester,
    ) async {
      final container = await pumpApp(tester, size: phone);

      await tester.tap(surahRow(2));
      await tester.pumpAndSettle();

      expect(location(container).path, AppRoutes.mushaf);
      expect(location(container).queryParameters, <String, String>{
        'ayah': AyahRef(2, 1).key,
      });
    });
  });

  group('juz', () {
    testWidgets('lists all 30 juz in order', (tester) async {
      await pumpApp(tester, size: phone);
      await showJuzTab(tester);

      final ids = await collectRows<JuzRow>(
        tester,
        IndexTab.juz,
        (row) => row.juz.id,
      );
      expect(ids, <int>[for (final j in repository.juzs()) j.id]);
      expect(ids, hasLength(30));
    });

    testWidgets('a row shows where the juz starts and its page', (
      tester,
    ) async {
      await pumpApp(tester, size: phone);
      await showJuzTab(tester);
      final juz = repository.juzs()[1];
      final start = repository.refOf(juz.firstAyahId);

      final row = juzRow(juz.id);
      Finder inRow(String text) =>
          find.descendant(of: row, matching: find.text(text));
      expect(inRow(ar.juzTitle(juz.id)), findsOneWidget);
      expect(
        inRow(ar.juzStart(repository.surah(start.surah).nameAr, start.ayah)),
        findsOneWidget,
      );
      expect(inRow(ar.pageNumber(juz.pageStart)), findsOneWidget);
    });

    testWidgets('a row opens the Mushaf at the first ayah of its juz', (
      tester,
    ) async {
      final container = await pumpApp(tester, size: phone);
      await showJuzTab(tester);
      final juz = repository.juzs()[2];

      await tester.tap(juzRow(juz.id));
      await tester.pumpAndSettle();

      expect(location(container).path, AppRoutes.mushaf);
      expect(location(container).queryParameters, <String, String>{
        'ayah': repository.refOf(juz.firstAyahId).key,
      });
    });
  });

  group('tab parameter', () {
    testWidgets('tab=juz opens the juz tab', (tester) async {
      final container = await pumpApp(tester, size: phone);
      await go(tester, container, '${AppRoutes.index}?tab=juz');

      expect(juzRow(1), findsOneWidget);
      expect(surahRow(1), findsNothing);

      await go(tester, container, '${AppRoutes.index}?tab=surahs');
      expect(surahRow(1), findsOneWidget);
    });

    testWidgets('an unknown tab falls back to the surahs', (tester) async {
      final container = await pumpApp(tester, size: phone);
      await go(tester, container, '${AppRoutes.index}?tab=x');

      expect(surahRow(1), findsOneWidget);
      expect(juzRow(1), findsNothing);
    });

    test('maps query values to tabs', () {
      expect(IndexTab.fromQuery(null), IndexTab.surahs);
      expect(IndexTab.fromQuery('surahs'), IndexTab.surahs);
      expect(IndexTab.fromQuery('juz'), IndexTab.juz);
      expect(IndexTab.fromQuery('JUZ'), IndexTab.surahs);
    });
  });

  group('states', () {
    testWidgets('shows an error when the database cannot be opened', (
      tester,
    ) async {
      await pumpApp(
        tester,
        size: phone,
        overrides: [
          quranRepositoryProvider.overrideWith(
            (ref) async => throw const QuranDatabaseException('unavailable'),
          ),
        ],
      );

      expect(find.byType(ErrorStateView), findsOneWidget);
      expect(find.byType(RetryButton), findsOneWidget);
      expect(find.byType(SurahRow), findsNothing);
      // The tabs stay, so the screen keeps its shape.
      expect(find.text(ar.indexTabSurahs), findsOneWidget);
    });

    testWidgets('shows progress while the database opens', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...await appTestOverrides(),
            quranRepositoryProvider.overrideWith(
              (ref) => Completer<QuranRepository>().future,
            ),
          ],
          child: const MuslimApp(),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(LoadingStateView), findsOneWidget);
    });
  });

  group('golden', () {
    testWidgets('surahs tab, light theme, phone', (tester) async {
      await pumpApp(tester, size: phone);

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../../goldens/index/index_surahs_light.png'),
      );
    });

    testWidgets('juz tab, light theme, phone', (tester) async {
      await pumpApp(tester, size: phone);
      await showJuzTab(tester);

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../../goldens/index/index_juz_light.png'),
      );
    });
  });
}
