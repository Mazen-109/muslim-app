import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:muslim/core/l10n/generated/app_localizations.dart';
import 'package:muslim/core/routing/app_router.dart';
import 'package:muslim/core/settings/settings_repository.dart';
import 'package:muslim/data/bookmark_repository.dart';
import 'package:muslim/data/models/ayah_ref.dart';
import 'package:muslim/data/models/mushaf_page.dart';
import 'package:muslim/data/models/word.dart';
import 'package:muslim/data/quran_repository.dart';
import 'package:muslim/data/user_database.dart';
import 'package:muslim/features/ayah_menu/ayah_actions.dart';
import 'package:muslim/features/ayah_menu/ayah_menu_sheet.dart';
import 'package:muslim/features/bookmarks/ayah_indicators.dart';
import 'package:muslim/features/bookmarks/bookmarks_screen.dart';
import 'package:muslim/features/mushaf/continuous/ayah_paragraph.dart';
import 'package:muslim/features/mushaf/page_view/page_line_widgets.dart';
import 'package:muslim/features/mushaf/reader_controller.dart';
import 'package:path/path.dart' as p;

import '../../helpers/fonts.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/quran_database.dart';

// Bookmarks and memorisation marks (T018, spec US5). Assertions compare
// keys, ids, repository state, stored rows and values read from the
// bundled database; no Quran text, surah name or other religious content
// appears here.

final AppLocalizations ar = lookupAppLocalizations(const Locale('ar'));

const Size phone = Size(400, 800);

/// A clock that moves one second forward each time it is read, so that
/// every mark gets a later time than the one before.
class _SteppingClock {
  int _millis = 1700000000000;

  DateTime call() => DateTime.fromMillisecondsSinceEpoch(_millis += 1000);
}

Uri location(ProviderContainer container) =>
    container.read(appRouterProvider).routerDelegate.currentConfiguration.uri;

void main() {
  late QuranRepository quran;
  late void Function() close;

  setUpAll(() async {
    await loadAppFonts();
    (quran, close) = openBundledQuranRepository();
  });
  tearDownAll(() => close());

  int idOf(String key) => quran.ayahIdOf(AyahRef.parse(key));

  Future<ProviderContainer> pump(
    WidgetTester tester, {
    Map<String, Object> preferences = const <String, Object>{},
    UserDatabase Function()? openUserDatabase,
  }) {
    final clock = _SteppingClock();
    return pumpApp(
      tester,
      size: phone,
      preferences: preferences,
      openUserDatabase: openUserDatabase,
      overrides: <Override>[clockProvider.overrideWithValue(clock.call)],
    );
  }

  Future<void> go(
    WidgetTester tester,
    ProviderContainer container,
    String path,
  ) async {
    container.read(appRouterProvider).go(path);
    await tester.pumpAndSettle();
  }

  Future<BookmarkRepository> repositoryOf(
    ProviderContainer container,
    AyahMarkKind kind,
  ) => container.read(markRepositoryProvider(kind).future);

  /// The end marker word of ayah [id] on its page.
  Word endMarkerOf(int id) {
    final page = quran.page(quran.pageOf(id));
    return page.lines
        .whereType<AyahLine>()
        .expand((line) => line.words)
        .singleWhere((w) => w.ayahId == id && w.charType == WordCharType.end);
  }

  /// Long presses a word of ayah [id] on the page that is shown.
  Future<void> openMenu(WidgetTester tester, int id) async {
    final word = quran
        .page(quran.pageOf(id))
        .lines
        .whereType<AyahLine>()
        .expand((line) => line.words)
        .firstWhere((w) => w.ayahId == id);
    await tester.longPress(find.byKey(MushafWordKey(word.id)));
    await tester.pumpAndSettle();
  }

  Finder action(AyahAction a) => find.byKey(AyahActionKey(a));

  Finder markOf(int id, AyahMarkKind kind) =>
      find.byKey(AyahIndicatorMarkKey(id, kind));

  Finder row(AyahMarkKind kind, int id) => find.byKey(BookmarkRowKey(kind, id));

  /// The ayah ids of a section's rows, top to bottom.
  List<int> rowsOf(WidgetTester tester, AyahMarkKind kind) {
    final rows = tester
        .widgetList<Widget>(
          find.byWidgetPredicate(
            (w) =>
                w.key is BookmarkRowKey &&
                (w.key! as BookmarkRowKey).value.$1 == kind,
          ),
        )
        .toList();
    final ids = <(double, int)>[
      for (final w in rows)
        (
          tester.getTopLeft(find.byKey(w.key!)).dy,
          (w.key! as BookmarkRowKey).value.$2,
        ),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    return <int>[for (final (_, id) in ids) id];
  }

  group('ayah menu', () {
    testWidgets('Mark as memorised sits next to Bookmark, toggles, shows its '
        'state, and the menu stays open', (tester) async {
      final id = idOf('2:6');
      final container = await pump(tester);
      await go(tester, container, AppRoutes.mushafPage(quran.pageOf(id)));
      await openMenu(tester, id);

      expect(
        AyahAction.values.indexOf(AyahAction.memorise),
        AyahAction.values.indexOf(AyahAction.bookmark) + 1,
      );
      final bookmarkTop = tester.getTopLeft(action(AyahAction.bookmark)).dy;
      final memoriseTop = tester.getTopLeft(action(AyahAction.memorise)).dy;
      final shareTop = tester.getTopLeft(action(AyahAction.share)).dy;
      expect(memoriseTop, greaterThan(bookmarkTop));
      expect(shareTop, greaterThan(memoriseTop));

      Finder titled(AyahAction a, String title) =>
          find.descendant(of: action(a), matching: find.text(title));
      expect(
        titled(AyahAction.memorise, ar.ayahMenuMarkMemorised),
        findsOneWidget,
      );

      final memorised = await repositoryOf(
        container,
        AyahMarkKind.memorisation,
      );
      final bookmarks = await repositoryOf(container, AyahMarkKind.bookmark);
      await tester.tap(action(AyahAction.memorise));
      await tester.pumpAndSettle();
      expect(memorised.isSet(id), isTrue);
      expect(bookmarks.isSet(id), isFalse);
      expect(find.byKey(ayahMenuKey), findsOneWidget);
      expect(
        titled(AyahAction.memorise, ar.ayahMenuUnmarkMemorised),
        findsOneWidget,
      );
      expect(
        titled(AyahAction.bookmark, ar.ayahMenuAddBookmark),
        findsOneWidget,
      );

      await tester.tap(action(AyahAction.memorise));
      await tester.pumpAndSettle();
      expect(memorised.isSet(id), isFalse);
      expect(
        titled(AyahAction.memorise, ar.ayahMenuMarkMemorised),
        findsOneWidget,
      );
      expect(find.byKey(ayahMenuKey), findsOneWidget);
    });

    testWidgets('toggling from the menu updates the list and the indicators', (
      tester,
    ) async {
      final id = idOf('2:6');
      final container = await pump(tester);
      await go(tester, container, AppRoutes.mushafPage(quran.pageOf(id)));
      expect(find.byKey(AyahIndicatorKey(id)), findsNothing);

      await openMenu(tester, id);
      await tester.tap(action(AyahAction.bookmark));
      await tester.pumpAndSettle();
      await tester.tap(action(AyahAction.memorise));
      await tester.pumpAndSettle();
      // Close the menu.
      await tester.tapAt(const Offset(200, 40));
      await tester.pumpAndSettle();

      expect(markOf(id, AyahMarkKind.bookmark), findsOneWidget);
      expect(markOf(id, AyahMarkKind.memorisation), findsOneWidget);

      await go(tester, container, AppRoutes.bookmarks);
      expect(rowsOf(tester, AyahMarkKind.bookmark), <int>[id]);
      expect(rowsOf(tester, AyahMarkKind.memorisation), <int>[id]);

      // Clearing the bookmark from the menu takes it off the page and the
      // list, and leaves the memorised mark.
      await go(tester, container, AppRoutes.mushafPage(quran.pageOf(id)));
      await openMenu(tester, id);
      await tester.tap(action(AyahAction.bookmark));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(200, 40));
      await tester.pumpAndSettle();
      expect(markOf(id, AyahMarkKind.bookmark), findsNothing);
      expect(markOf(id, AyahMarkKind.memorisation), findsOneWidget);

      await go(tester, container, AppRoutes.bookmarks);
      expect(rowsOf(tester, AyahMarkKind.bookmark), isEmpty);
      expect(rowsOf(tester, AyahMarkKind.memorisation), <int>[id]);
    });
  });

  group('indicators', () {
    testWidgets('sit over the end marker area in the page view and leave '
        'the words where they were', (tester) async {
      final id = idOf('2:7');
      final page = quran.pageOf(id);
      final container = await pump(tester);
      await go(tester, container, AppRoutes.mushafPage(page));
      final marker = endMarkerOf(id);
      final words = quran
          .page(page)
          .lines
          .whereType<AyahLine>()
          .expand((line) => line.words)
          .toList();
      final before = <int, Rect>{
        for (final w in words)
          w.id: tester.getRect(find.byKey(MushafWordKey(w.id))),
      };

      (await repositoryOf(container, AyahMarkKind.bookmark)).add(id);
      await tester.pumpAndSettle();

      final indicator = tester.getRect(find.byKey(AyahIndicatorKey(id)));
      final markerRect = tester.getRect(find.byKey(MushafWordKey(marker.id)));
      final slot = tester.getRect(find.byKey(MushafLineKey(page, marker.line)));
      expect(
        indicator.center.dx,
        moreOrLessEquals(markerRect.center.dx, epsilon: 0.5),
      );
      expect(indicator.top, moreOrLessEquals(slot.top, epsilon: 0.5));
      expect(indicator.bottom, lessThan(markerRect.center.dy));
      expect(indicator.width, lessThan(markerRect.width * 1.5));
      expect(markOf(id, AyahMarkKind.memorisation), findsNothing);

      // Every word keeps its place.
      for (final w in words) {
        expect(
          tester.getRect(find.byKey(MushafWordKey(w.id))),
          before[w.id],
          reason: 'word ${w.id}',
        );
      }

      // Only the marked ayah has an indicator on the page.
      expect(find.byType(AyahIndicators), findsOneWidget);
    });

    testWidgets('a tap on the indicator still reaches the ayah', (
      tester,
    ) async {
      final id = idOf('2:7');
      final container = await pump(tester);
      await go(tester, container, AppRoutes.mushafPage(quran.pageOf(id)));
      (await repositoryOf(container, AyahMarkKind.memorisation)).add(id);
      await tester.pumpAndSettle();

      await tester.longPress(
        find.byKey(AyahIndicatorKey(id)),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<AyahMenuSheet>(find.byType(AyahMenuSheet)).ayahId,
        id,
      );
    });

    testWidgets('follow the repository in the continuous view', (tester) async {
      final id = idOf('2:3');
      final container = await pump(
        tester,
        preferences: const <String, Object>{
          SettingsRepository.readingModeKey: 'continuous',
        },
      );
      await go(tester, container, AppRoutes.mushafAyah(AyahRef.parse('2:1')));
      expect(find.byType(AyahParagraph), findsWidgets);
      expect(find.byKey(AyahIndicatorKey(id)), findsNothing);

      final bookmarks = await repositoryOf(container, AyahMarkKind.bookmark);
      final memorised = await repositoryOf(
        container,
        AyahMarkKind.memorisation,
      );
      bookmarks.add(id);
      memorised.add(id);
      await tester.pumpAndSettle();
      expect(markOf(id, AyahMarkKind.bookmark), findsOneWidget);
      expect(markOf(id, AyahMarkKind.memorisation), findsOneWidget);

      // The marks are on the paragraph that holds the ayah, inside it.
      final paragraph = find.ancestor(
        of: find.byKey(AyahIndicatorKey(id)),
        matching: find.byType(AyahParagraph),
      );
      expect(
        tester.widget<AyahParagraph>(paragraph).ayahs.map((a) => a.id),
        contains(id),
      );
      final box = tester.getRect(paragraph);
      final indicator = tester.getRect(find.byKey(AyahIndicatorKey(id)));
      expect(box.contains(indicator.topLeft), isTrue);
      expect(box.contains(indicator.bottomRight), isTrue);

      bookmarks.remove(id);
      await tester.pumpAndSettle();
      expect(markOf(id, AyahMarkKind.bookmark), findsNothing);
      expect(markOf(id, AyahMarkKind.memorisation), findsOneWidget);
      memorised.remove(id);
      await tester.pumpAndSettle();
      expect(find.byKey(AyahIndicatorKey(id)), findsNothing);
    });
  });

  group('bookmarks screen', () {
    testWidgets('shows an empty state for each section', (tester) async {
      final container = await pump(tester);
      await go(tester, container, AppRoutes.bookmarks);

      for (final kind in AyahMarkKind.values) {
        expect(find.byKey(BookmarkSectionKey(kind)), findsOneWidget);
        expect(find.byKey(BookmarkSectionEmptyKey(kind)), findsOneWidget);
      }
      expect(find.text(ar.bookmarksEmptyTitle), findsOneWidget);
      expect(find.text(ar.memorisedEmptyTitle), findsOneWidget);

      (await repositoryOf(
        container,
        AyahMarkKind.memorisation,
      )).add(idOf('3:1'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const BookmarkSectionEmptyKey(AyahMarkKind.bookmark)),
        findsOneWidget,
      );
      expect(
        find.byKey(const BookmarkSectionEmptyKey(AyahMarkKind.memorisation)),
        findsNothing,
      );
    });

    testWidgets('lists each section newest first with surah, ayah and page', (
      tester,
    ) async {
      final container = await pump(tester);
      final bookmarks = await repositoryOf(container, AyahMarkKind.bookmark);
      final memorised = await repositoryOf(
        container,
        AyahMarkKind.memorisation,
      );
      final first = idOf('2:255');
      final second = idOf('1:1');
      final third = idOf('114:6');
      bookmarks
        ..add(first)
        ..add(second)
        ..add(third);
      memorised.add(second);
      await go(tester, container, AppRoutes.bookmarks);

      expect(rowsOf(tester, AyahMarkKind.bookmark), <int>[
        third,
        second,
        first,
      ]);
      expect(rowsOf(tester, AyahMarkKind.memorisation), <int>[second]);
      // The bookmarks section comes first.
      expect(
        tester
            .getTopLeft(
              find.byKey(const BookmarkSectionKey(AyahMarkKind.memorisation)),
            )
            .dy,
        greaterThan(tester.getTopLeft(row(AyahMarkKind.bookmark, first)).dy),
      );

      final ayah = quran.ayah(first);
      final tile = tester.widget<ListTile>(
        find.descendant(
          of: row(AyahMarkKind.bookmark, first),
          matching: find.byType(ListTile),
        ),
      );
      expect((tile.title! as Text).data, quran.surah(ayah.surahId).nameAr);
      expect(
        (tile.subtitle! as Text).data,
        ar.bookmarksRowDetails(ayah.ayahNumber, ayah.page),
      );
    });

    testWidgets('tapping a row opens the reader on that ayah', (tester) async {
      final container = await pump(tester);
      final id = idOf('18:10');
      (await repositoryOf(container, AyahMarkKind.memorisation)).add(id);
      await go(tester, container, AppRoutes.bookmarks);

      await tester.tap(row(AyahMarkKind.memorisation, id));
      await tester.pumpAndSettle();

      expect(
        location(container).toString(),
        AppRoutes.mushafAyah(AyahRef.parse('18:10'), highlight: true),
      );
      final reader = container.read(readerControllerProvider);
      expect(reader.currentAyahId, id);
      expect(reader.page, quran.pageOf(id));
      expect(markOf(id, AyahMarkKind.memorisation), findsOneWidget);
    });

    testWidgets('the remove button removes with an undo that restores the '
        'row in its place', (tester) async {
      final container = await pump(tester);
      final bookmarks = await repositoryOf(container, AyahMarkKind.bookmark);
      final a = idOf('2:1');
      final b = idOf('2:2');
      final c = idOf('2:3');
      bookmarks
        ..add(a)
        ..add(b)
        ..add(c);
      final stored = bookmarks.list();
      await go(tester, container, AppRoutes.bookmarks);

      await tester.tap(find.byKey(BookmarkRemoveKey(AyahMarkKind.bookmark, b)));
      await tester.pumpAndSettle();
      expect(bookmarks.isSet(b), isFalse);
      expect(rowsOf(tester, AyahMarkKind.bookmark), <int>[c, a]);
      expect(find.text(ar.bookmarksBookmarkRemoved), findsOneWidget);

      await tester.tap(find.text(ar.bookmarksUndo));
      await tester.pumpAndSettle();
      expect(bookmarks.list(), stored);
      expect(rowsOf(tester, AyahMarkKind.bookmark), <int>[c, b, a]);
    });

    testWidgets('swiping a row away removes it, and undo brings it back', (
      tester,
    ) async {
      final container = await pump(tester);
      final memorised = await repositoryOf(
        container,
        AyahMarkKind.memorisation,
      );
      final a = idOf('112:1');
      final b = idOf('112:2');
      memorised
        ..add(a)
        ..add(b);
      final stored = memorised.list();
      await go(tester, container, AppRoutes.bookmarks);

      await tester.drag(
        row(AyahMarkKind.memorisation, a),
        const Offset(-500, 0),
      );
      await tester.pumpAndSettle();
      expect(memorised.isSet(a), isFalse);
      expect(rowsOf(tester, AyahMarkKind.memorisation), <int>[b]);
      expect(find.text(ar.bookmarksMemorisedRemoved), findsOneWidget);

      await tester.tap(find.text(ar.bookmarksUndo));
      await tester.pumpAndSettle();
      expect(memorised.list(), stored);
      expect(rowsOf(tester, AyahMarkKind.memorisation), <int>[b, a]);

      // Removing the last one shows the section's empty state.
      for (final id in <int>[a, b]) {
        await tester.tap(
          find.byKey(BookmarkRemoveKey(AyahMarkKind.memorisation, id)),
        );
        await tester.pumpAndSettle();
      }
      expect(
        find.byKey(const BookmarkSectionEmptyKey(AyahMarkKind.memorisation)),
        findsOneWidget,
      );
    });

    testWidgets('a mark removed here leaves the page too', (tester) async {
      final container = await pump(tester);
      final id = idOf('2:6');
      (await repositoryOf(container, AyahMarkKind.bookmark)).add(id);
      await go(tester, container, AppRoutes.bookmarks);
      await tester.tap(
        find.byKey(BookmarkRemoveKey(AyahMarkKind.bookmark, id)),
      );
      await tester.pumpAndSettle();

      await go(tester, container, AppRoutes.mushafPage(quran.pageOf(id)));
      expect(find.byKey(AyahIndicatorKey(id)), findsNothing);
    });
  });

  testWidgets('marks survive a re-opened database (quickstart scenario 9)', (
    tester,
  ) async {
    final directory = Directory.systemTemp.createTempSync('bookmarks_test');
    addTearDown(() => directory.deleteSync(recursive: true));
    final path = p.join(directory.path, UserDatabase.fileName);
    UserDatabase openFile() => UserDatabase.open(path);

    final first = idOf('2:6');
    final second = idOf('2:7');
    var container = await pump(tester, openUserDatabase: openFile);
    await go(tester, container, AppRoutes.mushafPage(quran.pageOf(first)));
    for (final (id, a) in <(int, AyahAction)>[
      (first, AyahAction.bookmark),
      (second, AyahAction.bookmark),
      (second, AyahAction.memorise),
    ]) {
      await openMenu(tester, id);
      await tester.tap(action(a));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(200, 40));
      await tester.pumpAndSettle();
    }

    // Restart: a new provider scope opens the same file again.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    container = await pump(tester, openUserDatabase: openFile);

    await go(tester, container, AppRoutes.bookmarks);
    expect(rowsOf(tester, AyahMarkKind.bookmark), <int>[second, first]);
    expect(rowsOf(tester, AyahMarkKind.memorisation), <int>[second]);

    await go(tester, container, AppRoutes.mushafPage(quran.pageOf(first)));
    expect(markOf(first, AyahMarkKind.bookmark), findsOneWidget);
    expect(markOf(second, AyahMarkKind.bookmark), findsOneWidget);
    expect(markOf(second, AyahMarkKind.memorisation), findsOneWidget);

    final rows = UserDatabase.open(path);
    addTearDown(rows.close);
    expect(
      rows.db
          .select('SELECT ayah_id FROM bookmarks ORDER BY ayah_id')
          .map((r) => r['ayah_id']),
      <int>[first, second],
    );
    expect(
      rows.db
          .select('SELECT ayah_id FROM memorisation_marks')
          .map((r) => r['ayah_id']),
      <int>[second],
    );
  });
}
