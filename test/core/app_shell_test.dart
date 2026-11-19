import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:muslim/app.dart';
import 'package:muslim/core/l10n/generated/app_localizations.dart';
import 'package:muslim/core/routing/app_router.dart';
import 'package:muslim/core/settings/settings_providers.dart';
import 'package:muslim/core/settings/settings_repository.dart';
import 'package:muslim/core/theme/app_theme.dart';
import 'package:muslim/core/widgets/state_views.dart';
import 'package:muslim/data/models/ayah_ref.dart';
import 'package:muslim/data/quran_repository.dart';
import 'package:muslim/features/settings/settings_screen.dart';

import '../helpers/fonts.dart';
import '../helpers/pump_app.dart';
import '../helpers/quran_database.dart';

// The app shell: routes, launch rule, bottom navigation, locale, theme and
// the shared state views. Screens are placeholders here, so nothing in these
// tests renders Quran text; ayahs are named only by key.

final AppLocalizations ar = lookupAppLocalizations(const Locale('ar'));
final AppLocalizations en = lookupAppLocalizations(const Locale('en'));

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

Finder navLabel(String label) =>
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

void main() {
  late QuranRepository repository;
  late void Function() closeRepository;

  setUpAll(() async {
    await loadAppFonts();
    (repository, closeRepository) = openBundledQuranRepository();
  });
  tearDownAll(() => closeRepository());

  group('launch rule', () {
    testWidgets('opens the index when no ayah has been read', (tester) async {
      final container = await pumpApp(tester, size: phone);

      expect(location(container).path, AppRoutes.index);
      expect(find.text(ar.screenIndex), findsOneWidget);
    });

    testWidgets('opens the Mushaf at the last ayah read', (tester) async {
      final lastAyahId = repository.ayahIdOf(AyahRef(2, 255));
      final container = await pumpApp(
        tester,
        size: phone,
        preferences: <String, Object>{
          SettingsRepository.lastAyahIdKey: lastAyahId,
        },
      );

      expect(location(container).path, AppRoutes.mushaf);
      expect(location(container).queryParameters, <String, String>{
        'ayah': '2:255',
      });
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    test('falls back to the index when the database cannot be opened', () {
      expect(
        launchLocation(
          lastAyahId: 1,
          repository: () => Future<QuranRepository>.error(StateError('no db')),
        ),
        completion(AppRoutes.index),
      );
    });
  });

  group('bottom navigation', () {
    testWidgets('has the four destinations in order', (tester) async {
      await pumpApp(tester, size: phone);

      final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      final labels = bar.destinations
          .cast<NavigationDestination>()
          .map((d) => d.label)
          .toList();
      expect(labels, <String>[
        ar.navMushaf,
        ar.navStories,
        ar.navBookmarks,
        ar.navSettings,
      ]);
    });

    testWidgets('moves between the destinations', (tester) async {
      final container = await pumpApp(tester, size: phone);

      final steps = <(String, String, int)>[
        (ar.navStories, AppRoutes.stories, 1),
        (ar.navBookmarks, AppRoutes.bookmarks, 2),
        (ar.navSettings, AppRoutes.settings, 3),
        (ar.navMushaf, AppRoutes.index, 0),
      ];
      for (final (label, path, index) in steps) {
        await tester.tap(navLabel(label));
        await tester.pumpAndSettle();
        expect(location(container).path, path, reason: label);
        final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
        expect(bar.selectedIndex, index, reason: label);
      }
    });

    testWidgets('keeps each destination on its own stack', (tester) async {
      final container = await pumpApp(tester, size: phone);

      await tester.tap(navLabel(ar.navSettings));
      await tester.pumpAndSettle();
      // The sources row is at the end of the settings list.
      final sourcesRow = find.text(ar.screenSources);
      await tester.scrollUntilVisible(
        sourcesRow,
        200,
        scrollable: find
            .descendant(
              of: find.byType(SettingsScreen),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(sourcesRow);
      await tester.pumpAndSettle();
      expect(location(container).path, AppRoutes.sources);

      await tester.tap(navLabel(ar.navStories));
      await tester.pumpAndSettle();
      await tester.tap(navLabel(ar.navSettings));
      await tester.pumpAndSettle();
      expect(location(container).path, AppRoutes.sources);

      // Selecting the current destination again returns to its start.
      await tester.tap(navLabel(ar.navSettings));
      await tester.pumpAndSettle();
      expect(location(container).path, AppRoutes.settings);
    });

    testWidgets('the Mushaf destination resumes at the last ayah read', (
      tester,
    ) async {
      final container = await pumpApp(tester, size: phone);

      // No reader yet: the Mushaf start is the index.
      await go(tester, container, AppRoutes.search);
      await tester.tap(navLabel(ar.navMushaf));
      await tester.pumpAndSettle();
      expect(location(container).path, AppRoutes.index);

      // Once an ayah has been read, the Mushaf start is that ayah.
      await container
          .read(lastAyahIdProvider.notifier)
          .set(repository.ayahIdOf(AyahRef(36, 1)));
      await tester.tap(navLabel(ar.navMushaf));
      await tester.pumpAndSettle();
      expect(location(container).path, AppRoutes.mushaf);
      expect(location(container).queryParameters['ayah'], '36:1');
    });

    testWidgets('the Mushaf app bar opens the index and search', (
      tester,
    ) async {
      final container = await pumpApp(tester, size: phone);
      await go(tester, container, AppRoutes.mushafPage(1));

      await tester.tap(find.byTooltip(ar.screenSearch));
      await tester.pumpAndSettle();
      expect(location(container).path, AppRoutes.search);

      await go(tester, container, AppRoutes.mushafPage(1));
      await tester.tap(find.byTooltip(ar.screenIndex));
      await tester.pumpAndSettle();
      expect(location(container).path, AppRoutes.index);
    });

    testWidgets('becomes a rail on wide screens', (tester) async {
      await pumpApp(tester, size: const Size(900, 700));

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });
  });

  group('routes', () {
    testWidgets('every route in the contract opens its screen', (tester) async {
      final container = await pumpApp(tester, size: phone);

      final routes = <String, String>{
        '${AppRoutes.index}?tab=juz': ar.screenIndex,
        AppRoutes.mushafAyah(AyahRef(2, 255), highlight: true): ar.navMushaf,
        AppRoutes.mushafPage(604): ar.navMushaf,
        '${AppRoutes.search}?q=x': ar.screenSearch,
        AppRoutes.bookmarks: ar.navBookmarks,
        '${AppRoutes.stories}?tab=prophets': ar.navStories,
        AppRoutes.surahStory(114): ar.screenSurahStory,
        AppRoutes.prophetStory('story-a'): ar.screenEpisodes,
        AppRoutes.episode('story-a', 'episode-1'): ar.screenEpisode,
        AppRoutes.settings: ar.navSettings,
        AppRoutes.sources: ar.screenSources,
      };
      for (final MapEntry(key: path, value: title) in routes.entries) {
        await go(tester, container, path);
        expect(location(container).toString(), path, reason: path);
        expect(
          find.descendant(of: find.byType(AppBar), matching: find.text(title)),
          findsOneWidget,
          reason: path,
        );
      }
    });

    testWidgets('invalid /mushaf parameters redirect to /index', (
      tester,
    ) async {
      final container = await pumpApp(tester, size: phone);
      final pastLastAyahOfSurah1 = repository.ayahCounts[0] + 1;

      final invalid = <String>[
        AppRoutes.mushaf,
        '${AppRoutes.mushaf}?page=0',
        '${AppRoutes.mushaf}?page=605',
        '${AppRoutes.mushaf}?page=01',
        '${AppRoutes.mushaf}?page=x',
        '${AppRoutes.mushaf}?ayah=0:1',
        '${AppRoutes.mushaf}?ayah=115:1',
        '${AppRoutes.mushaf}?ayah=1:$pastLastAyahOfSurah1',
        '${AppRoutes.mushaf}?ayah=2',
        '${AppRoutes.mushaf}?ayah=2:255&page=42',
        '${AppRoutes.mushaf}?ayah=2:255&highlight=yes',
      ];
      for (final path in invalid) {
        await go(tester, container, AppRoutes.bookmarks);
        await go(tester, container, path);
        expect(location(container).path, AppRoutes.index, reason: path);
        expect(find.text(ar.invalidLink), findsOneWidget, reason: path);
        ScaffoldMessenger.of(tester.element(find.byType(NavigationBar)))
            .removeCurrentSnackBar();
        await tester.pumpAndSettle();
      }
    });

    testWidgets('an invalid surah story redirects to the stories home', (
      tester,
    ) async {
      final container = await pumpApp(tester, size: phone);

      for (final surah in <String>['0', '115', 'x']) {
        await go(tester, container, '${AppRoutes.stories}/surah/$surah');
        expect(location(container).path, AppRoutes.stories, reason: surah);
      }
    });

    test('a /mushaf ayah key is only checked for form without a database', () {
      Future<QuranRepository> missing() =>
          Future<QuranRepository>.error(StateError('no db'));
      expect(
        isValidMushafQuery(<String, String>{
          'ayah': '2:255',
        }, repository: missing),
        completion(isTrue),
      );
      expect(
        isValidMushafQuery(<String, String>{
          'ayah': '2-255',
        }, repository: missing),
        completion(isFalse),
      );
    });
  });

  group('locale and theme', () {
    testWidgets('Arabic by default, right to left', (tester) async {
      await pumpApp(tester, size: phone);

      final label = find.text(ar.navMushaf);
      expect(Localizations.localeOf(tester.element(label)), const Locale('ar'));
      expect(Directionality.of(tester.element(label)), TextDirection.rtl);
      // The first destination sits at the right edge.
      expect(
        tester.getCenter(navLabel(ar.navMushaf)).dx,
        greaterThan(tester.getCenter(navLabel(ar.navSettings)).dx),
      );
    });

    testWidgets('English from the settings, left to right', (tester) async {
      await pumpApp(
        tester,
        size: phone,
        preferences: <String, Object>{SettingsRepository.localeKey: 'en'},
      );

      final label = find.text(en.navMushaf);
      expect(label, findsOneWidget);
      expect(Directionality.of(tester.element(label)), TextDirection.ltr);
      expect(
        tester.getCenter(navLabel(en.navMushaf)).dx,
        lessThan(tester.getCenter(navLabel(en.navSettings)).dx),
      );
    });

    testWidgets('a locale change applies at once', (tester) async {
      final container = await pumpApp(tester, size: phone);

      await container.read(localeProvider.notifier).set(AppLocale.en);
      await tester.pumpAndSettle();

      expect(find.text(en.navSettings), findsOneWidget);
      expect(
        Directionality.of(tester.element(find.text(en.navSettings))),
        TextDirection.ltr,
      );
    });

    testWidgets('the theme comes from the settings and applies app-wide', (
      tester,
    ) async {
      final container = await pumpApp(tester, size: phone);
      ThemeData current() =>
          Theme.of(tester.element(find.byType(NavigationBar)));

      expect(current().colorScheme, AppTheme.light.colorScheme);

      for (final preference in ThemePreference.values) {
        await container.read(themeProvider.notifier).set(preference);
        await tester.pumpAndSettle();
        expect(
          current().colorScheme,
          AppTheme.of(preference).colorScheme,
          reason: preference.storageValue,
        );
        expect(
          Theme.of(tester.element(find.byType(AppBar))).colorScheme,
          AppTheme.of(preference).colorScheme,
        );
      }
    });
  });

  group('state views', () {
    Future<void> pumpState(WidgetTester tester, Widget view) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('ar'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: appLocalizationsDelegates,
          home: Scaffold(body: view),
        ),
      );
      await tester.pump();
    }

    testWidgets('error retries', (tester) async {
      var retries = 0;
      await pumpState(tester, ErrorStateView(onRetry: () => retries++));

      expect(find.text(ar.stateErrorTitle), findsOneWidget);
      await tester.tap(find.text(ar.retry));
      expect(retries, 1);
    });

    testWidgets('offline explains and retries', (tester) async {
      var retries = 0;
      await pumpState(tester, OfflineStateView(onRetry: () => retries++));

      expect(find.text(ar.stateOfflineTitle), findsOneWidget);
      expect(find.text(ar.stateOfflineMessage), findsOneWidget);
      await tester.tap(find.byType(RetryButton));
      expect(retries, 1);
    });

    testWidgets('error without retry has no button', (tester) async {
      await pumpState(tester, const ErrorStateView(message: 'detail'));

      expect(find.text('detail'), findsOneWidget);
      expect(find.byType(RetryButton), findsNothing);
    });

    testWidgets('empty shows its title and action', (tester) async {
      await pumpState(
        tester,
        EmptyStateView(
          icon: Icons.bookmark_border,
          title: 'title',
          message: 'message',
          action: TextButton(onPressed: () {}, child: const Text('action')),
        ),
      );

      expect(find.text('title'), findsOneWidget);
      expect(find.text('message'), findsOneWidget);
      expect(find.text('action'), findsOneWidget);
    });

    testWidgets('loading has a screen reader label', (tester) async {
      await pumpState(tester, const LoadingStateView());

      expect(find.bySemanticsLabel(ar.stateLoading), findsOneWidget);
    });
  });

  group('golden', () {
    for (final preference in ThemePreference.values) {
      testWidgets('the shell in the ${preference.storageValue} theme', (
        tester,
      ) async {
        final container = await pumpApp(
          tester,
          size: phone,
          preferences: <String, Object>{
            SettingsRepository.themeKey: preference.storageValue,
          },
        );
        await go(tester, container, AppRoutes.mushafPage(1));

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            '../goldens/app_shell_${preference.storageValue}.png',
          ),
        );
      });
    }
  });
}
