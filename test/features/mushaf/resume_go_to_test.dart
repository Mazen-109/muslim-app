import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:muslim/core/l10n/generated/app_localizations.dart';
import 'package:muslim/core/routing/app_router.dart';
import 'package:muslim/core/settings/settings_repository.dart';
import 'package:muslim/data/models/ayah_ref.dart';
import 'package:muslim/data/models/mushaf_page.dart';
import 'package:muslim/data/quran_repository.dart';
import 'package:muslim/features/index/index_screen.dart';
import 'package:muslim/features/mushaf/continuous/continuous_view.dart';
import 'package:muslim/features/mushaf/go_to_sheet.dart';
import 'package:muslim/features/mushaf/page_view/mushaf_page_view.dart';
import 'package:muslim/features/mushaf/reader_controller.dart';
import 'package:muslim/features/mushaf/reader_screen.dart';
import 'package:muslim/features/mushaf/resume.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fonts.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/quran_database.dart';

// Resume and go-to (T013). Ayahs are named only by key and id; no Quran
// text or surah name appears here.

final AppLocalizations ar = lookupAppLocalizations(const Locale('ar'));

const Size phone = Size(400, 800);

/// Less than the save delay, so a pending save has not happened yet.
const Duration lessThanDelay = Duration(milliseconds: 400);

void main() {
  late QuranRepository repository;
  late void Function() closeRepository;

  setUpAll(() async {
    await loadAppFonts();
    (repository, closeRepository) = openBundledQuranRepository();
  });
  tearDownAll(() => closeRepository());

  int idOf(String key) => repository.ayahIdOf(AyahRef.parse(key));

  Uri location(ProviderContainer container) =>
      container.read(appRouterProvider).routerDelegate.currentConfiguration.uri;

  Future<int?> storedLastAyah() async => (await SharedPreferences.getInstance())
      .getInt(SettingsRepository.lastAyahIdKey);

  /// Every stored preference, as a new launch would read it.
  Future<Map<String, Object>> storedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    return <String, Object>{
      for (final key in prefs.getKeys()) key: prefs.get(key)!,
    };
  }

  Future<ProviderContainer> launch(
    WidgetTester tester, {
    Map<String, Object> preferences = const <String, Object>{},
  }) => pumpApp(tester, size: phone, preferences: preferences);

  Future<void> go(
    WidgetTester tester,
    ProviderContainer container,
    String path,
  ) async {
    container.read(appRouterProvider).go(path);
    await tester.pumpAndSettle();
  }

  /// Passes the save delay.
  Future<void> rest(WidgetTester tester) async {
    await tester.pump(resumeSaveDelay);
    await tester.pumpAndSettle();
  }

  group('ResumeRecorder', () {
    testWidgets('saves only the last of quick changes, after the delay', (
      tester,
    ) async {
      final saved = <int>[];
      final recorder = ResumeRecorder(save: (id) async => saved.add(id));

      recorder
        ..schedule(10)
        ..schedule(11);
      await tester.pump(lessThanDelay);
      recorder.schedule(12);
      await tester.pump(lessThanDelay);
      expect(saved, isEmpty, reason: 'each change restarts the wait');

      await tester.pump(resumeSaveDelay);
      expect(saved, <int>[12]);
      expect(recorder.hasPending, isFalse);
    });

    testWidgets('flush saves at once; an unchanged id is not saved again', (
      tester,
    ) async {
      final saved = <int>[];
      final recorder = ResumeRecorder(save: (id) async => saved.add(id));

      recorder.schedule(20);
      await recorder.flush();
      expect(saved, <int>[20]);

      await recorder.flush(20);
      recorder.schedule(20);
      await tester.pump(resumeSaveDelay);
      expect(saved, <int>[20]);

      await recorder.flush(21);
      expect(saved, <int>[20, 21]);
    });

    testWidgets('cancel drops the pending id', (tester) async {
      final saved = <int>[];
      final recorder = ResumeRecorder(save: (id) async => saved.add(id))
        ..schedule(30)
        ..cancel();
      await tester.pump(resumeSaveDelay * 2);
      expect(saved, isEmpty);
      expect(recorder.hasPending, isFalse);
    });
  });

  group('saving the position', () {
    testWidgets('the current ayah is saved once it rests for the delay', (
      tester,
    ) async {
      final c = await launch(tester);
      // pumpAndSettle has already passed some time; check from a fresh
      // change instead.
      await go(tester, c, AppRoutes.mushafAyah(AyahRef(2, 255)));
      await rest(tester);
      expect(await storedLastAyah(), idOf('2:255'));

      final controller = c.read(readerControllerProvider.notifier);
      controller.setCurrentAyah(idOf('2:256'));
      await tester.pump(lessThanDelay);
      controller.setCurrentAyah(idOf('2:257'));
      await tester.pump(lessThanDelay);
      expect(
        await storedLastAyah(),
        idOf('2:255'),
        reason: 'debounced: nothing is written while the ayah keeps moving',
      );

      await tester.pump(resumeSaveDelay);
      expect(await storedLastAyah(), idOf('2:257'));
    });

    testWidgets('turning a page saves the first ayah that starts on it', (
      tester,
    ) async {
      final c = await launch(tester);
      await go(tester, c, AppRoutes.mushafPage(50));
      await rest(tester);

      c.read(readerControllerProvider.notifier).showPage(51);
      await rest(tester);
      expect(
        await storedLastAyah(),
        c.read(readerControllerProvider).currentAyahId,
      );
      expect(repository.pageOf((await storedLastAyah())!), 51);
    });

    testWidgets('pausing the app saves at once, before the delay', (
      tester,
    ) async {
      final c = await launch(tester);
      await go(tester, c, AppRoutes.mushafAyah(AyahRef(18, 1)));
      await rest(tester);

      c.read(readerControllerProvider.notifier).setCurrentAyah(idOf('18:10'));
      await tester.pump();
      expect(await storedLastAyah(), idOf('18:1'));

      for (final state in <AppLifecycleState>[
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pump();
      expect(await storedLastAyah(), idOf('18:10'));

      for (final state in <AppLifecycleState>[
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await rest(tester);
      expect(await storedLastAyah(), idOf('18:10'));
    });

    testWidgets('leaving the reader saves a pending position', (tester) async {
      final c = await launch(tester);
      await go(tester, c, AppRoutes.mushafAyah(AyahRef(3, 1)));
      await rest(tester);

      c.read(readerControllerProvider.notifier).setCurrentAyah(idOf('3:5'));
      await tester.pump();
      await go(tester, c, AppRoutes.index);
      expect(await storedLastAyah(), idOf('3:5'));
    });

    testWidgets('the index alone saves nothing', (tester) async {
      await launch(tester);
      await rest(tester);
      expect(await storedLastAyah(), isNull);
    });
  });

  group('launch', () {
    testWidgets('first launch opens the index', (tester) async {
      final c = await launch(tester);
      expect(location(c).path, AppRoutes.index);
      expect(find.byType(IndexScreen), findsOneWidget);
      expect(find.byType(ReaderScreen), findsNothing);
    });

    testWidgets('the position and the view survive a restart', (tester) async {
      // First run: read in the continuous view and stop on 36:12.
      var c = await launch(tester);
      await go(tester, c, AppRoutes.mushafAyah(AyahRef(36, 1)));
      await tester.tap(find.byKey(readerModeToggleKey));
      await tester.pumpAndSettle();
      c.read(readerControllerProvider.notifier).setCurrentAyah(idOf('36:12'));
      await rest(tester);
      final saved = await storedPreferences();
      expect(saved[SettingsRepository.lastAyahIdKey], idOf('36:12'));

      // Restart: a new tree and a new container over the same values.
      await tester.pumpWidget(const SizedBox());
      c = await launch(tester, preferences: saved);

      expect(location(c).path, AppRoutes.mushaf);
      expect(location(c).queryParameters['ayah'], '36:12');
      final state = c.read(readerControllerProvider);
      expect(state.currentAyahId, idOf('36:12'));
      expect(state.mode, ReadingMode.continuous);
      expect(find.byType(ContinuousView), findsOneWidget);
    });

    testWidgets('a restart in the page view opens the page of the ayah', (
      tester,
    ) async {
      var c = await launch(tester);
      await go(tester, c, AppRoutes.mushafPage(200));
      await rest(tester);
      final ayah = c.read(readerControllerProvider).currentAyahId;
      final saved = await storedPreferences();

      await tester.pumpWidget(const SizedBox());
      c = await launch(tester, preferences: saved);

      final state = c.read(readerControllerProvider);
      expect(state.currentAyahId, ayah);
      expect(state.page, 200);
      expect(state.mode, ReadingMode.pages);
      expect(find.byType(MushafPageView), findsOneWidget);
      final view = tester.widget<PageView>(find.byType(PageView));
      expect(view.controller!.page!.round() + 1, 200);
    });

    testWidgets('an out-of-range saved id is ignored: the index opens', (
      tester,
    ) async {
      final c = await launch(
        tester,
        preferences: <String, Object>{SettingsRepository.lastAyahIdKey: 6237},
      );
      expect(location(c).path, AppRoutes.index);
    });
  });

  group('app bar', () {
    testWidgets('the index and search are one tap away, go-to is in the menu', (
      tester,
    ) async {
      final c = await launch(tester);
      await go(tester, c, AppRoutes.mushafPage(1));
      expect(find.byTooltip(ar.screenIndex), findsOneWidget);
      expect(find.byTooltip(ar.screenSearch), findsOneWidget);
      await tester.tap(find.byKey(readerMoreKey));
      await tester.pumpAndSettle();
      expect(find.byKey(readerGoToKey), findsOneWidget);
      await tester.tapAt(Offset.zero);
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip(ar.screenIndex));
      await tester.pumpAndSettle();
      expect(location(c).path, AppRoutes.index);
    });
  });

  group('go-to', () {
    Future<void> openSheet(WidgetTester tester) async {
      await tester.tap(find.byKey(readerMoreKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(readerGoToKey));
      await tester.pumpAndSettle();
      expect(find.byType(GoToSheet), findsOneWidget);
    }

    Future<void> submit(WidgetTester tester) async {
      await tester.tap(find.byKey(goToSubmitKey));
      await tester.pumpAndSettle();
    }

    Finder surahText() => find.descendant(
      of: find.byKey(goToSurahFieldKey),
      matching: find.byType(TextField),
    );

    test('numbers in Western and Arabic-Indic digits', () {
      expect(parseGoToNumber('604'), 604);
      expect(parseGoToNumber(' 12 '), 12);
      expect(parseGoToNumber('\u0663\u0660\u0660'), 300);
      expect(parseGoToNumber('\u06F2\u06F5'), 25);
      expect(parseGoToNumber(''), isNull);
      expect(parseGoToNumber('1a'), isNull);
      expect(parseGoToNumber('-1'), isNull);
      expect(parseGoToNumber('1234567'), isNull);
    });

    testWidgets('the fields start at the current position', (tester) async {
      final c = await launch(tester);
      await go(tester, c, AppRoutes.mushafAyah(AyahRef(2, 255)));
      await openSheet(tester);

      final page = tester.widget<TextField>(find.byKey(goToPageFieldKey));
      expect(page.controller!.text, '${repository.pageOf(idOf('2:255'))}');

      await tester.tap(find.byKey(goToBySurahKey));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(surahText()).controller!.text,
        startsWith('2.'),
      );
      final ayah = tester.widget<TextField>(find.byKey(goToAyahFieldKey));
      expect(ayah.controller!.text, '255');
      expect(find.text(ar.goToRange(286)), findsOneWidget);
    });

    testWidgets('a page out of range is refused with a message', (
      tester,
    ) async {
      final c = await launch(tester);
      await go(tester, c, AppRoutes.mushafPage(1));
      await openSheet(tester);
      expect(find.text(ar.goToRange(pageCount)), findsOneWidget);

      for (final input in <String>['0', '605', '']) {
        await tester.enterText(find.byKey(goToPageFieldKey), input);
        await submit(tester);
        expect(find.text(ar.goToPageOutOfRange(pageCount)), findsOneWidget);
        expect(find.byType(GoToSheet), findsOneWidget);
        expect(location(c).queryParameters['page'], '1');
      }

      // Typing clears the message.
      await tester.enterText(find.byKey(goToPageFieldKey), '6');
      await tester.pumpAndSettle();
      expect(find.text(ar.goToPageOutOfRange(pageCount)), findsNothing);
    });

    testWidgets('a page in range opens the Mushaf there', (tester) async {
      final c = await launch(tester);
      await go(tester, c, AppRoutes.mushafPage(1));
      await openSheet(tester);

      await tester.enterText(find.byKey(goToPageFieldKey), '300');
      await submit(tester);

      expect(find.byType(GoToSheet), findsNothing);
      expect(location(c).path, AppRoutes.mushaf);
      expect(location(c).queryParameters['page'], '300');
      expect(c.read(readerControllerProvider).page, 300);
      final view = tester.widget<PageView>(find.byType(PageView));
      expect(view.controller!.page!.round() + 1, 300);

      await rest(tester);
      expect(repository.pageOf((await storedLastAyah())!), 300);
    });

    testWidgets('pages 1 and 604 are accepted, also in Arabic-Indic digits', (
      tester,
    ) async {
      final c = await launch(tester);
      await go(tester, c, AppRoutes.mushafPage(10));

      await openSheet(tester);
      await tester.enterText(find.byKey(goToPageFieldKey), '604');
      await submit(tester);
      expect(c.read(readerControllerProvider).page, 604);

      await openSheet(tester);
      await tester.enterText(find.byKey(goToPageFieldKey), '\u0661');
      await submit(tester);
      expect(location(c).queryParameters['page'], '1');
      expect(c.read(readerControllerProvider).page, 1);
    });

    testWidgets('going to the page the route already names still moves', (
      tester,
    ) async {
      final c = await launch(tester);
      await go(tester, c, AppRoutes.mushafPage(1));
      c.read(readerControllerProvider.notifier).showPage(5);
      await tester.pumpAndSettle();

      await openSheet(tester);
      await tester.enterText(find.byKey(goToPageFieldKey), '1');
      await submit(tester);
      expect(location(c).queryParameters['page'], '1');
      expect(c.read(readerControllerProvider).page, 1);
    });

    testWidgets('a surah and ayah open the Mushaf at that ayah', (
      tester,
    ) async {
      final c = await launch(tester);
      await go(tester, c, AppRoutes.mushafPage(1));
      await openSheet(tester);
      await tester.tap(find.byKey(goToBySurahKey));
      await tester.pumpAndSettle();

      // Pick surah 2 from the list of names from the database.
      await tester.tap(surahText());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(goToSurahEntryKey(2)).last);
      await tester.pumpAndSettle();
      expect(find.text(ar.goToRange(286)), findsOneWidget);

      await tester.enterText(find.byKey(goToAyahFieldKey), '255');
      await submit(tester);

      expect(find.byType(GoToSheet), findsNothing);
      expect(location(c).path, AppRoutes.mushaf);
      expect(location(c).queryParameters['ayah'], '2:255');
      final state = c.read(readerControllerProvider);
      expect(state.currentAyahId, idOf('2:255'));
      expect(state.page, repository.pageOf(idOf('2:255')));
      expect(state.highlightedAyahId, idOf('2:255'));
    });

    testWidgets('an ayah beyond the surah is refused with its count', (
      tester,
    ) async {
      final c = await launch(tester);
      await go(tester, c, AppRoutes.mushafPage(1));
      await openSheet(tester);
      await tester.tap(find.byKey(goToBySurahKey));
      await tester.pumpAndSettle();

      // A surah number typed into the picker selects that surah.
      await tester.enterText(surahText(), '114');
      await tester.pumpAndSettle();
      final count = repository.surah(114).ayahCount;
      expect(find.text(ar.goToRange(count)), findsOneWidget);

      for (final input in <String>['0', '${count + 1}', '']) {
        await tester.enterText(find.byKey(goToAyahFieldKey), input);
        await submit(tester);
        expect(find.text(ar.goToAyahOutOfRange(count)), findsOneWidget);
        expect(find.byType(GoToSheet), findsOneWidget);
      }

      await tester.enterText(find.byKey(goToAyahFieldKey), '$count');
      await submit(tester);
      expect(location(c).queryParameters['ayah'], '114:$count');
      expect(
        c.read(readerControllerProvider).currentAyahId,
        SettingsRepository.maxAyahId,
      );
    });

    testWidgets('a surah the picker does not know is refused', (tester) async {
      final c = await launch(tester);
      await go(tester, c, AppRoutes.mushafPage(1));
      await openSheet(tester);
      await tester.tap(find.byKey(goToBySurahKey));
      await tester.pumpAndSettle();

      for (final input in <String>['0', '115', 'x']) {
        await tester.enterText(surahText(), input);
        await tester.pumpAndSettle();
        // Close the filtered list.
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        await submit(tester);
        expect(find.text(ar.goToSurahMissing), findsOneWidget);
        expect(find.byType(GoToSheet), findsOneWidget);
      }
      expect(location(c).queryParameters['page'], '1');
    });

    testWidgets('go-to keeps the continuous view', (tester) async {
      final c = await launch(
        tester,
        preferences: <String, Object>{
          SettingsRepository.readingModeKey: 'continuous',
        },
      );
      await go(tester, c, AppRoutes.mushafAyah(AyahRef(1, 1)));
      await openSheet(tester);
      await tester.tap(find.byKey(goToBySurahKey));
      await tester.pumpAndSettle();
      await tester.enterText(surahText(), '18');
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(goToAyahFieldKey), '10');
      await submit(tester);

      final state = c.read(readerControllerProvider);
      expect(state.mode, ReadingMode.continuous);
      expect(state.currentAyahId, idOf('18:10'));
      expect(find.byType(ContinuousView), findsOneWidget);
    });

    testWidgets('dismissing the sheet leaves the reader where it was', (
      tester,
    ) async {
      final c = await launch(tester);
      await go(tester, c, AppRoutes.mushafPage(42));
      await openSheet(tester);
      await tester.enterText(find.byKey(goToPageFieldKey), '100');
      await tester.tapAt(const Offset(200, 100));
      await tester.pumpAndSettle();

      expect(find.byType(GoToSheet), findsNothing);
      expect(location(c).queryParameters['page'], '42');
      expect(c.read(readerControllerProvider).page, 42);
    });
  });
}
