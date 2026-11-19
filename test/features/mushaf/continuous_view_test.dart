import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:muslim/app.dart';
import 'package:muslim/core/l10n/generated/app_localizations.dart';
import 'package:muslim/core/routing/app_router.dart';
import 'package:muslim/core/settings/settings_providers.dart';
import 'package:muslim/core/settings/settings_repository.dart';
import 'package:muslim/core/theme/app_theme.dart';
import 'package:muslim/core/theme/app_typography.dart';
import 'package:muslim/data/models/ayah_ref.dart';
import 'package:muslim/data/models/mushaf_page.dart';
import 'package:muslim/data/quran_repository.dart';
import 'package:muslim/features/mushaf/continuous/ayah_paragraph.dart';
import 'package:muslim/features/mushaf/continuous/continuous_surah.dart';
import 'package:muslim/features/mushaf/continuous/continuous_view.dart';
import 'package:muslim/features/mushaf/continuous/text_size_sheet.dart';
import 'package:muslim/features/mushaf/page_view/mushaf_page_view.dart';
import 'package:muslim/features/mushaf/page_view/page_line_widgets.dart';
import 'package:muslim/features/mushaf/reader_controller.dart';
import 'package:muslim/features/mushaf/reader_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fonts.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/quran_database.dart';

// The continuous view and the mode switch (T012). Every assertion is on
// ids, keys, counts, sizes and positions; no Quran text or surah name
// appears here.

const Size phone = Size(400, 800);

const Map<String, Object> continuousPrefs = <String, Object>{
  SettingsRepository.readingModeKey: 'continuous',
};

void main() {
  late QuranRepository repository;
  late void Function() closeRepository;

  setUpAll(() async {
    await loadAppFonts();
    (repository, closeRepository) = openBundledQuranRepository();
  });
  tearDownAll(() => closeRepository());

  int idOf(String key) => repository.ayahIdOf(AyahRef.parse(key));

  Future<ProviderContainer> openReader(
    WidgetTester tester,
    String path, {
    Map<String, Object> preferences = const <String, Object>{},
  }) async {
    final container = await pumpApp(
      tester,
      size: phone,
      preferences: preferences,
    );
    container.read(appRouterProvider).go(path);
    await tester.pumpAndSettle();
    return container;
  }

  RenderBox viewport(WidgetTester tester) =>
      tester.renderObject<RenderBox>(find.byKey(continuousScrollKey));

  /// The top of [ayahId]'s first line relative to the top of the
  /// continuous view, or null when its paragraph is not built.
  double? topOf(WidgetTester tester, int ayahId) {
    final box = viewport(tester);
    for (final state in tester.stateList<AyahParagraphState>(
      find.byType(AyahParagraph, skipOffstage: false),
    )) {
      for (final (id, top) in state.ayahTops(box)) {
        if (id == ayahId) return top;
      }
    }
    return null;
  }

  /// Whether the first line of [ayahId] is inside the continuous view.
  bool onScreen(WidgetTester tester, int ayahId) {
    final top = topOf(tester, ayahId);
    return top != null && top >= -1 && top < viewport(tester).size.height;
  }

  int shownPage(WidgetTester tester) {
    final view = tester.widget<PageView>(find.byType(PageView));
    return view.controller!.page!.round() + 1;
  }

  /// A word of [ayahId] on [page], as the page view draws it.
  Finder wordOf(int page, int ayahId) => find.byKey(
    MushafWordKey(
      repository
          .page(page)
          .lines
          .whereType<AyahLine>()
          .expand((l) => l.words)
          .firstWhere((w) => w.ayahId == ayahId)
          .id,
    ),
  );

  Future<void> toggleMode(WidgetTester tester) async {
    await tester.tap(find.byKey(readerModeToggleKey));
    await tester.pumpAndSettle();
  }

  group('surah data', () {
    test('paragraphs cover the surah in order, one page each', () {
      for (final surahId in <int>[1, 2, 9, 114]) {
        final ayahs = repository.ayahsOfSurah(surahId);
        final paragraphs = ContinuousSurah.paragraphsByPage(ayahs);
        expect(
          paragraphs.expand((p) => p).map((a) => a.id),
          ayahs.map((a) => a.id),
        );
        for (final p in paragraphs) {
          expect(p.map((a) => a.page).toSet(), hasLength(1));
        }
      }
    });
  });

  group('mode switch', () {
    testWidgets('page view to continuous view keeps the ayah on screen, and '
        'the mode persists', (tester) async {
      // Page 51 starts mid-surah; a surah's first ayah opens under its
      // header instead (see the scrolling group).
      final c = await openReader(tester, AppRoutes.mushafPage(51));
      final ayah = c.read(readerControllerProvider).currentAyahId;
      expect(find.byType(MushafPageView), findsOneWidget);

      await toggleMode(tester);
      expect(find.byType(ContinuousView), findsOneWidget);
      expect(find.byType(MushafPageView), findsNothing);
      final state = c.read(readerControllerProvider);
      expect(state.mode, ReadingMode.continuous);
      expect(state.currentAyahId, ayah);
      expect(topOf(tester, ayah), closeTo(0, 1));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(SettingsRepository.readingModeKey), 'continuous');
    });

    testWidgets('continuous view to page view returns to the page of the '
        'current ayah, after scrolling', (tester) async {
      final c = await openReader(
        tester,
        AppRoutes.mushafAyah(AyahRef.parse('2:100')),
        preferences: continuousPrefs,
      );
      expect(find.byType(ContinuousView), findsOneWidget);
      expect(topOf(tester, idOf('2:100')), closeTo(0, 1));

      await tester.drag(find.byKey(continuousScrollKey), const Offset(0, -900));
      await tester.pumpAndSettle();
      final ayah = c.read(readerControllerProvider).currentAyahId;
      expect(ayah, greaterThan(idOf('2:100')));
      expect(onScreen(tester, ayah), isTrue);

      await toggleMode(tester);
      expect(find.byType(MushafPageView), findsOneWidget);
      expect(c.read(readerControllerProvider).mode, ReadingMode.pages);
      expect(c.read(readerControllerProvider).currentAyahId, ayah);
      final page = repository.pageOf(ayah);
      expect(shownPage(tester), page);
      expect(wordOf(page, ayah).hitTestable(), findsOneWidget);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(SettingsRepository.readingModeKey), 'pages');
    });

    testWidgets('a round trip from a page comes back to that page', (
      tester,
    ) async {
      await openReader(tester, AppRoutes.mushafPage(300));
      await toggleMode(tester);
      await toggleMode(tester);
      expect(shownPage(tester), 300);
    });

    testWidgets('the saved mode opens the continuous view', (tester) async {
      final c = await openReader(
        tester,
        AppRoutes.mushafPage(3),
        preferences: continuousPrefs,
      );
      expect(find.byType(ContinuousView), findsOneWidget);
      expect(
        onScreen(tester, c.read(readerControllerProvider).currentAyahId),
        isTrue,
      );
    });
  });

  group('font scale', () {
    double paragraphFontSize(WidgetTester tester) => tester
        .widget<AyahParagraph>(find.byType(AyahParagraph).first)
        .style
        .fontSize!;

    double paragraphHeight(WidgetTester tester) =>
        tester.getSize(find.byType(AyahParagraph).first).height;

    testWidgets('the control resizes the text at once, keeps the ayah on '
        'screen, and persists', (tester) async {
      final c = await openReader(
        tester,
        AppRoutes.mushafAyah(AyahRef.parse('2:30')),
        preferences: continuousPrefs,
      );
      expect(paragraphFontSize(tester), AppTypography.quranFontSize);
      final heightBefore = paragraphHeight(tester);

      await tester.tap(find.byKey(readerMoreKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(readerTextSizeKey));
      await tester.pumpAndSettle();
      expect(find.byType(TextSizeSheet), findsOneWidget);
      await tester.tap(find.byKey(textSizeLargerKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(textSizeLargerKey));
      await tester.pumpAndSettle();

      expect(c.read(fontScaleProvider), 1.2);
      expect(paragraphFontSize(tester), closeTo(26 * 1.2, 0.001));
      expect(paragraphHeight(tester), greaterThan(heightBefore));
      expect(topOf(tester, idOf('2:30')), closeTo(0, 1));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble(SettingsRepository.fontScaleKey), 1.2);

      await tester.tap(find.byKey(textSizeSmallerKey));
      await tester.pumpAndSettle();
      expect(c.read(fontScaleProvider), 1.1);
      expect(paragraphFontSize(tester), closeTo(26 * 1.1, 0.001));
    });

    testWidgets('a saved size is used on the next launch', (tester) async {
      await openReader(
        tester,
        AppRoutes.mushafAyah(AyahRef.parse('2:30')),
        preferences: <String, Object>{
          ...continuousPrefs,
          SettingsRepository.fontScaleKey: 1.5,
        },
      );
      expect(paragraphFontSize(tester), closeTo(26 * 1.5, 0.001));
    });

    testWidgets('the size control is shown only in the continuous view', (
      tester,
    ) async {
      Future<void> openMenu() async {
        await tester.tap(find.byKey(readerMoreKey));
        await tester.pumpAndSettle();
      }

      await openReader(tester, AppRoutes.mushafPage(3));
      await openMenu();
      expect(find.byKey(readerGoToKey), findsOneWidget);
      expect(find.byKey(readerTextSizeKey), findsNothing);
      await tester.tapAt(Offset.zero);
      await tester.pumpAndSettle();

      await toggleMode(tester);
      await openMenu();
      expect(find.byKey(readerTextSizeKey), findsOneWidget);
    });
  });

  group('scrolling', () {
    testWidgets('scrolling updates the current ayah to the ayah at the top', (
      tester,
    ) async {
      final c = await openReader(
        tester,
        AppRoutes.mushafAyah(AyahRef.parse('2:1')),
        preferences: continuousPrefs,
      );
      expect(c.read(readerControllerProvider).currentAyahId, idOf('2:1'));
      // The surah opens at its start, with the header and basmala.
      expect(find.byKey(const ContinuousHeaderKey(2)), findsOneWidget);
      expect(find.byKey(const ContinuousBasmalaKey(2)), findsOneWidget);

      var last = idOf('2:1');
      for (var i = 0; i < 3; i++) {
        await tester.drag(
          find.byKey(continuousScrollKey),
          const Offset(0, -1200),
        );
        await tester.pumpAndSettle();
        final state = c.read(readerControllerProvider);
        expect(state.currentAyahId, greaterThan(last));
        expect(state.page, repository.pageOf(state.currentAyahId));
        // It is the first ayah whose first line is at or below the top.
        final top = topOf(tester, state.currentAyahId)!;
        expect(top, greaterThanOrEqualTo(-1));
        expect(top, lessThan(viewport(tester).size.height));
        final previousTop = topOf(tester, state.currentAyahId - 1);
        if (previousTop != null) expect(previousTop, lessThan(-1));
        last = state.currentAyahId;
      }

      // Scrolling back moves it back.
      await tester.drag(find.byKey(continuousScrollKey), const Offset(0, 1200));
      await tester.pumpAndSettle();
      expect(c.read(readerControllerProvider).currentAyahId, lessThan(last));
    });

    testWidgets('a link to an ayah off screen moves the view to it', (
      tester,
    ) async {
      final c = await openReader(
        tester,
        AppRoutes.mushafAyah(AyahRef.parse('2:1')),
        preferences: continuousPrefs,
      );
      c.read(appRouterProvider).go(AppRoutes.mushafAyah(AyahRef.parse('3:50')));
      await tester.pumpAndSettle();
      expect(c.read(readerControllerProvider).currentAyahId, idOf('3:50'));
      expect(topOf(tester, idOf('3:50')), closeTo(0, 1));
      expect(find.byKey(const ContinuousHeaderKey(2)), findsNothing);
    });
  });

  group('surah', () {
    testWidgets('surah 1 and surah 9 have no separate basmala', (tester) async {
      for (final surah in <int>[1, 9]) {
        await openReader(
          tester,
          AppRoutes.mushafAyah(AyahRef(surah, 1)),
          preferences: continuousPrefs,
        );
        expect(find.byKey(ContinuousHeaderKey(surah)), findsOneWidget);
        expect(find.byKey(ContinuousBasmalaKey(surah)), findsNothing);
      }
    });

    testWidgets('the next and previous surah buttons open those surahs at '
        'their start', (tester) async {
      final c = await openReader(
        tester,
        AppRoutes.mushafAyah(AyahRef.parse('112:1')),
        preferences: continuousPrefs,
      );
      await tester.scrollUntilVisible(
        find.byKey(continuousNextSurahKey),
        300,
        scrollable: find.descendant(
          of: find.byKey(continuousScrollKey),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.tap(find.byKey(continuousNextSurahKey));
      await tester.pumpAndSettle();
      expect(c.read(readerControllerProvider).currentAyahId, idOf('113:1'));
      expect(find.byKey(const ContinuousHeaderKey(113)), findsOneWidget);

      await tester.tap(find.byKey(continuousPreviousSurahKey));
      await tester.pumpAndSettle();
      expect(c.read(readerControllerProvider).currentAyahId, idOf('112:1'));
      expect(find.byKey(const ContinuousHeaderKey(112)), findsOneWidget);
    });

    testWidgets('the first surah has no previous and the last no next', (
      tester,
    ) async {
      await openReader(
        tester,
        AppRoutes.mushafAyah(AyahRef.parse('1:1')),
        preferences: continuousPrefs,
      );
      expect(find.byKey(continuousPreviousSurahKey), findsNothing);
      await openReader(
        tester,
        AppRoutes.mushafAyah(AyahRef.parse('114:1')),
        preferences: continuousPrefs,
      );
      expect(
        find.byKey(continuousNextSurahKey, skipOffstage: false),
        findsNothing,
      );
    });
  });

  group('ayah interaction', () {
    /// Pumps the continuous view on its own with the given callbacks.
    Future<ProviderContainer> pumpView(
      WidgetTester tester, {
      AyahCallback? onTap,
      AyahCallback? onLongPress,
    }) async {
      final container = await pumpApp(
        tester,
        size: phone,
        child: Consumer(
          builder: (context, ref, _) => MaterialApp(
            theme: AppTheme.light,
            locale: const Locale('ar'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: appLocalizationsDelegates,
            home: Scaffold(
              body: ref.watch(quranRepositoryProvider).hasValue
                  ? ContinuousView(
                      onAyahTap: onTap,
                      onAyahLongPress: onLongPress,
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ),
      );
      // The controller starts at ayah 1; surah 1 is one page, so move to
      // surah 2, which has several paragraphs.
      container.read(readerControllerProvider.notifier).goToAyah(idOf('2:1'));
      await tester.pumpAndSettle();
      return container;
    }

    /// The point on the first line of the paragraph that starts with
    /// [ayahId], near its right edge, where the text starts.
    Offset startOfParagraph(WidgetTester tester, int ayahId) {
      final paragraph = find.byWidgetPredicate(
        (w) => w is AyahParagraph && w.ayahs.first.id == ayahId,
      );
      final rect = tester.getRect(paragraph);
      return Offset(rect.right - 8, rect.top + 26);
    }

    int firstOfSecondParagraph(int surahId) => ContinuousSurah.paragraphsByPage(
      repository.ayahsOfSurah(surahId),
    )[1].first.id;

    testWidgets('a tap and a long press report the ayah under them', (
      tester,
    ) async {
      final taps = <int>[];
      final longPresses = <int>[];
      await pumpView(tester, onTap: taps.add, onLongPress: longPresses.add);

      final first = idOf('2:1');
      await tester.tapAt(startOfParagraph(tester, first));
      expect(taps, <int>[first]);
      final second = firstOfSecondParagraph(2);
      await tester.longPressAt(startOfParagraph(tester, second));
      expect(longPresses, <int>[second]);
      expect(taps, <int>[first]);
    });

    testWidgets('the header and basmala report no taps', (tester) async {
      final taps = <int>[];
      await pumpView(tester, onTap: taps.add);
      await tester.tap(find.byKey(const ContinuousHeaderKey(2)));
      await tester.tap(find.byKey(const ContinuousBasmalaKey(2)));
      expect(taps, isEmpty);
    });

    testWidgets('the highlighted ayah is drawn on the wash, in its paragraph '
        'only', (tester) async {
      final c = await pumpView(tester);
      Finder washIn(int firstAyahId) => find.descendant(
        of: find.byWidgetPredicate(
          (w) => w is AyahParagraph && w.ayahs.first.id == firstAyahId,
        ),
        matching: find.byType(CustomPaint),
      );
      final first = idOf('2:1');
      final second = firstOfSecondParagraph(2);
      expect(washIn(first), findsNothing);

      c.read(readerControllerProvider.notifier).highlight(first);
      await tester.pumpAndSettle();
      expect(washIn(first), findsOneWidget);
      expect(washIn(second), findsNothing);

      c.read(readerControllerProvider.notifier).highlight(second);
      await tester.pumpAndSettle();
      expect(washIn(first), findsNothing);
      expect(washIn(second), findsOneWidget);
    });
  });

  // Checked by eye against DESIGN.md: header in the interface face over a
  // hairline rule, centred basmala, justified paragraphs with end markers,
  // the ayah wash behind one ayah, nothing clipped.
  testWidgets('golden: the start of a surah, light theme, phone', (
    tester,
  ) async {
    final c = await openReader(
      tester,
      AppRoutes.mushafAyah(AyahRef.parse('2:1')),
      preferences: continuousPrefs,
    );
    c.read(readerControllerProvider.notifier).highlight(idOf('2:3'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../goldens/mushaf/continuous_light.png'),
    );
  });
}
