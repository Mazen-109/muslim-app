import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:muslim/app.dart';
import 'package:muslim/core/l10n/generated/app_localizations.dart';
import 'package:muslim/core/routing/app_router.dart';
import 'package:muslim/core/theme/app_colors.dart';
import 'package:muslim/core/theme/app_theme.dart';
import 'package:muslim/core/theme/app_typography.dart';
import 'package:muslim/core/widgets/state_views.dart';
import 'package:muslim/data/models/ayah_ref.dart';
import 'package:muslim/data/models/mushaf_page.dart';
import 'package:muslim/data/models/word.dart';
import 'package:muslim/data/quran_database.dart' show AssetLoader;
import 'package:muslim/data/quran_repository.dart';
import 'package:muslim/features/mushaf/page_view/mushaf_page_view.dart';
import 'package:muslim/features/mushaf/page_view/mushaf_page_widget.dart';
import 'package:muslim/features/mushaf/page_view/page_line_widgets.dart';
import 'package:muslim/features/mushaf/quran_font_check.dart';
import 'package:muslim/features/mushaf/reader_controller.dart';

import '../../helpers/fonts.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/quran_database.dart';

// The Mushaf page view (T011). Every assertion is on ids, keys, counts,
// line types and positions; no Quran text or surah name appears here.

final AppLocalizations ar = lookupAppLocalizations(const Locale('ar'));

const Size phone = Size(400, 800);

enum LineType { ayah, surahName, basmala }

LineType typeOf(PageLine line) => switch (line) {
  AyahLine() => LineType.ayah,
  SurahNameLine() => LineType.surahName,
  BasmalaLine() => LineType.basmala,
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

  /// The line types of [page] as stored in `page_lines`, read with SQL so
  /// that the expectation does not come from the code under test.
  List<LineType> storedTypes(int page) {
    final database = openBundledQuranDatabase();
    addTearDown(database.close);
    return <LineType>[
      for (final row in database.db.select(
        'SELECT line_type FROM page_lines WHERE page = ? ORDER BY line',
        <Object?>[page],
      ))
        switch (row['line_type'] as String) {
          'ayah' => LineType.ayah,
          'surah_name' => LineType.surahName,
          'basmala' => LineType.basmala,
          final other => throw StateError(other),
        },
    ];
  }

  /// The first page where a surah begins below the top of the page.
  int midPageSurahStart() {
    final database = openBundledQuranDatabase();
    addTearDown(database.close);
    return database.db
            .select(
              "SELECT page FROM page_lines WHERE line_type = 'surah_name' "
              'AND line > 1 AND line < 14 ORDER BY page LIMIT 1',
            )
            .single['page']
        as int;
  }

  /// Pumps one page on its own, as the page view would show it.
  Future<void> pumpPage(
    WidgetTester tester,
    int number, {
    int? highlightedAyahId,
    AyahCallback? onTap,
    AyahCallback? onLongPress,
    Size size = phone,
  }) async {
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final page = repository.page(number);
    final first = page.lines.whereType<AyahLine>().first.words.first.ayahId;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('ar'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: appLocalizationsDelegates,
        home: MushafPageWidget(
          page: page,
          heading: MushafPageHeading(
            surah: repository.surah(repository.refOf(first).surah),
            juz: 1,
          ),
          highlightedAyahId: highlightedAyahId,
          onAyahTap: onTap,
          onAyahLongPress: onLongPress,
        ),
      ),
    );
  }

  group('lines', () {
    final expectedCounts = <int, int>{1: 8, 2: 8, 3: 15, 604: 15};

    for (final MapEntry(key: number, value: count) in expectedCounts.entries) {
      testWidgets('page $number has $count lines of the stored types', (
        tester,
      ) async {
        final page = repository.page(number);
        expect(page.lines, hasLength(count));
        expect(page.lines.map(typeOf).toList(), storedTypes(number));

        await pumpPage(tester, number);
        expectRenderedLines(tester, page);
      });
    }

    test('pages 1 and 2 open with a surah banner; page 2 has a basmala and '
        'page 1 none, its basmala being its first ayah', () {
      expect(repository.page(1).lines.map(typeOf).take(2), <LineType>[
        LineType.surahName,
        LineType.ayah,
      ]);
      expect(repository.page(2).lines.map(typeOf).take(3), <LineType>[
        LineType.surahName,
        LineType.basmala,
        LineType.ayah,
      ]);
      expect(repository.page(3).lines.map(typeOf), everyElement(LineType.ayah));
      final last = repository.page(604).lines.map(typeOf).toList();
      expect(last.where((t) => t == LineType.surahName), hasLength(3));
      expect(last.where((t) => t == LineType.basmala), hasLength(3));
    });

    testWidgets('a page where a surah starts mid-page', (tester) async {
      final number = midPageSurahStart();
      final page = repository.page(number);
      final types = page.lines.map(typeOf).toList();
      expect(types, storedTypes(number));
      final banner = types.indexOf(LineType.surahName);
      expect(banner, greaterThan(0));
      expect(types[banner - 1], LineType.ayah);
      expect(types[banner + 1], LineType.basmala);
      expect(types[banner + 2], LineType.ayah);

      await pumpPage(tester, number);
      expectRenderedLines(tester, page);
    });
  });

  group('layout', () {
    testWidgets('every line fits the text block, on a phone and a tablet', (
      tester,
    ) async {
      for (final size in <Size>[
        phone,
        const Size(320, 568),
        const Size(900, 1200),
      ]) {
        for (final number in <int>[1, 2, 3, 50, 106, 300, 604]) {
          await pumpPage(tester, number, size: size);
          final block = tester.getRect(find.byKey(MushafLineKey(number, 1)));
          for (final word in find.byType(GestureDetector).evaluate()) {
            final rect = tester.getRect(find.byWidget(word.widget));
            expect(rect.left, greaterThanOrEqualTo(block.left - 0.5));
            expect(rect.right, lessThanOrEqualTo(block.right + 0.5));
          }
          expect(tester.takeException(), isNull);
        }
      }
    });

    testWidgets('a full line is justified to the block and a short last line '
        'is centred', (tester) async {
      await pumpPage(tester, 604);
      final page = repository.page(604);
      final block = tester.getRect(find.byKey(const MushafLineKey(604, 3)));
      final ayahLines = page.lines.whereType<AyahLine>().toList();

      Rect wordRect(Word w) => tester.getRect(find.byKey(MushafWordKey(w.id)));

      // The first ayah line of the page spans the block edge to edge: its
      // first word starts at the right edge and its last ends at the left.
      final full = ayahLines.first;
      expect(wordRect(full.words.first).right, closeTo(block.right, 0.5));
      expect(wordRect(full.words.last).left, closeTo(block.left, 0.5));

      // The last line of the Quran is short and centred: equal margins.
      final last = ayahLines.last;
      final right = block.right - wordRect(last.words.first).right;
      final left = wordRect(last.words.last).left - block.left;
      expect(right, greaterThan(block.width / 10));
      expect(left, closeTo(right, 1));
    });

    test('measuring every page gives a positive block width', () {
      final style = AppTypography.quran.copyWith(
        fontSize: MushafGeometry.referenceFontSize,
      );
      final stopwatch = Stopwatch()..start();
      for (var p = 1; p <= pageCount; p++) {
        final layout = MushafPageLayout.measure(repository.page(p), style);
        expect(layout.blockWidth, greaterThan(0), reason: 'page $p');
        expect(layout.spaceWidth, greaterThan(0));
      }
      stopwatch.stop();
      // About 1.5 ms per page on a desktop test host, reading and measuring.
      expect(stopwatch.elapsedMilliseconds / pageCount, lessThan(16));
    });
  });

  group('interaction', () {
    /// A line of [page] that holds words of two ayahs, read with SQL.
    (int, int, int) sharedLine() {
      final database = openBundledQuranDatabase();
      addTearDown(database.close);
      final row = database.db
          .select(
            'SELECT page, line, MIN(ayah_id) AS first_ayah FROM words '
            'GROUP BY page, line HAVING COUNT(DISTINCT ayah_id) = 2 '
            'ORDER BY page, line LIMIT 1 OFFSET 5',
          )
          .single;
      return (row['page'] as int, row['line'] as int, row['first_ayah'] as int);
    }

    testWidgets('a tap and a long press report the ayah of the word, on a '
        'line shared by two ayahs', (tester) async {
      final (number, lineNumber, firstAyah) = sharedLine();
      final taps = <int>[];
      final presses = <int>[];
      await pumpPage(tester, number, onTap: taps.add, onLongPress: presses.add);
      final line =
          repository
                  .page(number)
                  .lines
                  .firstWhere((l) => l.number == lineNumber)
              as AyahLine;
      final first = line.words.firstWhere(
        (w) => w.ayahId == firstAyah && w.charType == WordCharType.word,
      );
      final second = line.words.lastWhere(
        (w) => w.ayahId == firstAyah + 1 && w.charType == WordCharType.word,
      );

      // In right-to-left order the earlier ayah's word is further right.
      final firstRect = tester.getRect(find.byKey(MushafWordKey(first.id)));
      final secondRect = tester.getRect(find.byKey(MushafWordKey(second.id)));
      expect(firstRect.center.dx, greaterThan(secondRect.center.dx));
      expect(firstRect.center.dy, closeTo(secondRect.center.dy, 0.5));

      await tester.tapAt(firstRect.center);
      await tester.tapAt(secondRect.center);
      await tester.longPressAt(secondRect.center);
      await tester.longPressAt(firstRect.center);
      await tester.pumpAndSettle();

      expect(taps, <int>[firstAyah, firstAyah + 1]);
      expect(presses, <int>[firstAyah + 1, firstAyah]);
    });

    testWidgets('the basmala and the banner report no taps', (tester) async {
      final taps = <int>[];
      await pumpPage(tester, 2, onTap: taps.add);
      await tester.tap(find.byType(BasmalaLineWidget));
      await tester.tap(find.byType(SurahBannerLine));
      await tester.pumpAndSettle();
      expect(taps, isEmpty);
    });

    testWidgets('the highlighted ayah sits on one wash', (tester) async {
      final id = idOf('2:6');
      final page = repository.page(repository.pageOf(id));
      await pumpPage(tester, page.number, highlightedAyahId: id);

      final washes = find.byWidgetPredicate(
        (w) =>
            w is DecoratedBox &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).color ==
                AppPalette.light.ayahHighlight,
      );
      final linesWithAyah = page.lines
          .whereType<AyahLine>()
          .where((l) => l.words.any((w) => w.ayahId == id))
          .length;
      expect(washes, findsNWidgets(linesWithAyah));

      // Each wash covers every word of the ayah on its line.
      final rects = washes.evaluate().map(
        (e) => tester.getRect(find.byWidget(e.widget)),
      );
      for (final line in page.lines.whereType<AyahLine>()) {
        for (final word in line.words.where((w) => w.ayahId == id)) {
          final r = tester.getRect(find.byKey(MushafWordKey(word.id)));
          expect(rects.any((h) => h.inflate(0.5).contains(r.center)), isTrue);
        }
      }
    });
  });

  group('reader', () {
    Uri location(ProviderContainer c) =>
        c.read(appRouterProvider).routerDelegate.currentConfiguration.uri;

    Future<ProviderContainer> openReader(
      WidgetTester tester,
      String path,
    ) async {
      final container = await pumpApp(tester, size: phone);
      container.read(appRouterProvider).go(path);
      await tester.pumpAndSettle();
      return container;
    }

    int shownPage(WidgetTester tester) {
      final view = tester.widget<PageView>(find.byType(PageView));
      return view.controller!.page!.round() + 1;
    }

    testWidgets('?page=N opens page N', (tester) async {
      final c = await openReader(tester, AppRoutes.mushafPage(300));
      expect(shownPage(tester), 300);
      expect(c.read(readerControllerProvider).page, 300);
      expect(find.byKey(const MushafLineKey(300, 1)), findsOneWidget);
    });

    testWidgets('?ayah=S:A&highlight=1 opens the ayah page with the ayah '
        'highlighted', (tester) async {
      final id = idOf('2:255');
      final c = await openReader(
        tester,
        AppRoutes.mushafAyah(AyahRef.parse('2:255'), highlight: true),
      );
      expect(shownPage(tester), repository.pageOf(id));
      final state = c.read(readerControllerProvider);
      expect(state.currentAyahId, id);
      expect(state.highlightedAyahId, id);

      // A later link moves the built view.
      c.read(appRouterProvider).go(AppRoutes.mushafPage(604));
      await tester.pumpAndSettle();
      expect(shownPage(tester), 604);
      expect(location(c).queryParameters['page'], '604');
    });

    testWidgets('swiping turns pages in right-to-left order', (tester) async {
      final c = await openReader(tester, AppRoutes.mushafPage(3));
      final view = find.byType(PageView);

      // Dragging from left to right brings in the next page from the left.
      await tester.fling(view, const Offset(300, 0), 1000);
      await tester.pumpAndSettle();
      expect(shownPage(tester), 4);
      expect(c.read(readerControllerProvider).page, 4);
      expect(find.byKey(const MushafLineKey(4, 1)), findsOneWidget);
      expect(
        repository.pageOf(c.read(readerControllerProvider).currentAyahId),
        4,
      );

      // Dragging from right to left goes back.
      await tester.fling(view, const Offset(-300, 0), 1000);
      await tester.pumpAndSettle();
      expect(shownPage(tester), 3);
      expect(c.read(readerControllerProvider).page, 3);

      // Only the shown page and its neighbours are built.
      expect(
        find.byType(MushafPageWidget, skipOffstage: false).evaluate().length,
        lessThanOrEqualTo(3),
      );
    });

    testWidgets('the running head and page number come from the page', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await openReader(tester, AppRoutes.mushafPage(604));
      expect(find.bySemanticsLabel(ar.mushafPageNumber(604)), findsWidgets);
      expect(find.text(ar.mushafHeadJuz(30)), findsOneWidget);
      expect(
        find.bySemanticsLabel(ar.mushafHeadSurah(repository.surah(112).nameAr)),
        findsOneWidget,
      );
      semantics.dispose();
    });
  });

  group('font check', () {
    Future<void> pumpReader(WidgetTester tester, AssetLoader? loader) async {
      await pumpApp(
        tester,
        size: phone,
        overrides: <Override>[
          if (loader != null)
            quranFontAssetLoaderProvider.overrideWithValue(loader),
        ],
        child: const MuslimApp(),
      );
      tester.container().read(appRouterProvider).go(AppRoutes.mushafPage(1));
      await tester.pumpAndSettle();
    }

    void expectBlocked() {
      expect(find.byType(ErrorStateView), findsOneWidget);
      expect(find.text(ar.mushafFontErrorTitle), findsOneWidget);
      expect(find.byType(MushafPageView), findsNothing);
      expect(find.byType(AyahLineWidget), findsNothing);
    }

    testWidgets('a missing font blocks the reader', (tester) async {
      await pumpReader(
        tester,
        (key) => Future<ByteData>.error(StateError('no asset $key')),
      );
      expectBlocked();
    });

    testWidgets('a font that differs from the registry blocks the reader', (
      tester,
    ) async {
      await pumpReader(
        tester,
        (key) async => ByteData.sublistView(Uint8List.fromList(<int>[1, 2, 3])),
      );
      expectBlocked();
    });

    testWidgets('the bundled font passes', (tester) async {
      await pumpReader(tester, null);
      expect(find.byType(ErrorStateView), findsNothing);
      expect(find.byType(MushafPageView), findsOneWidget);
    });
  });
}

/// The page renders one slot per line, in order, with the widget for its
/// type.
void expectRenderedLines(WidgetTester tester, MushafPage page) {
  final slots = <double>[];
  for (final line in page.lines) {
    final slot = find.byKey(MushafLineKey(page.number, line.number));
    expect(slot, findsOneWidget);
    final type = switch (line) {
      AyahLine() => AyahLineWidget,
      SurahNameLine() => SurahBannerLine,
      BasmalaLine() => BasmalaLineWidget,
    };
    expect(
      find.descendant(of: slot, matching: find.byType(type)),
      findsOneWidget,
    );
    if (line case AyahLine(:final words)) {
      for (final word in words) {
        expect(
          find.descendant(
            of: slot,
            matching: find.byKey(MushafWordKey(word.id)),
          ),
          findsOneWidget,
        );
      }
    }
    slots.add(tester.getRect(slot).top);
  }
  // Slots run top to bottom with equal pitch.
  for (var i = 2; i < slots.length; i++) {
    expect(slots[i] - slots[i - 1], closeTo(slots[1] - slots[0], 0.01));
  }
  expect(
    find.byType(AyahLineWidget),
    findsNWidgets(page.lines.whereType<AyahLine>().length),
  );
}
