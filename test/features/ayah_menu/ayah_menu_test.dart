import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:muslim/core/l10n/generated/app_localizations.dart';
import 'package:muslim/core/routing/app_router.dart';
import 'package:muslim/core/routing/modal_observer.dart';
import 'package:muslim/core/settings/settings_providers.dart';
import 'package:muslim/core/settings/settings_repository.dart';
import 'package:muslim/data/bookmark_repository.dart';
import 'package:muslim/data/models/ayah_ref.dart';
import 'package:muslim/data/models/mushaf_page.dart';
import 'package:muslim/data/models/reciter.dart';
import 'package:muslim/data/quran_repository.dart';
import 'package:muslim/data/reciter_repository.dart';
import 'package:muslim/features/audio/playback_state.dart';
import 'package:muslim/features/audio/player_bar.dart';
import 'package:muslim/features/audio/recitation_controller.dart';
import 'package:muslim/features/audio/reciter_picker.dart';
import 'package:muslim/features/ayah_menu/ayah_actions.dart';
import 'package:muslim/features/ayah_menu/ayah_menu_sheet.dart';
import 'package:muslim/features/ayah_menu/repeat_picker.dart';
import 'package:muslim/features/mushaf/continuous/ayah_paragraph.dart';
import 'package:muslim/features/mushaf/page_view/page_line_widgets.dart';
import 'package:muslim/features/mushaf/reader_controller.dart';
import 'package:muslim/features/stories/catalog/catalog_models.dart';
import 'package:muslim/features/stories/catalog/catalog_repository.dart';
import 'package:muslim/features/tafsir/tafsir_sheet.dart';

import '../../helpers/fake_audio.dart';
import '../../helpers/fonts.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/quran_database.dart';

// The ayah menu (T017). The audio player, the share sheet and the catalog
// are fakes; nothing reaches the network. Assertions compare keys, ids,
// controller and repository state, and values read from the bundled
// database; no Quran text, surah name or story content appears here.

final AppLocalizations ar = lookupAppLocalizations(const Locale('ar'));
final AppLocalizations en = lookupAppLocalizations(const Locale('en'));

const Size phone = Size(400, 800);

/// Records the text handed to the share sheet.
class _FakeSharePort implements SharePort {
  final List<String> shared = <String>[];
  final List<Rect?> origins = <Rect?>[];

  @override
  Future<void> shareText(String text, {Rect? origin}) async {
    shared.add(text);
    origins.add(origin);
  }
}

/// A catalog with a playable story for [surah] only; structure, no content.
class _FixedCatalog extends CatalogNotifier {
  _FixedCatalog(this.surah);

  final int surah;

  @override
  Future<Catalog> build() async => Catalog(
    schemaVersion: Catalog.supportedSchemaVersion,
    updatedAt: DateTime.utc(2026),
    surahStories: <SurahStory>[
      SurahStory(
        id: 'surah-$surah',
        surah: surah,
        review: Review(
          status: ReviewStatus.approved,
          reviewer: 'Reviewer A',
          approvedAt: DateTime.utc(2026),
        ),
        noProphetDepiction: true,
        media: StreamMedia(
          url: Uri.parse('https://media.example.com/item.m3u8'),
        ),
      ),
    ],
    prophetSeries: <ProphetStory>[],
  );
}

void main() {
  late QuranRepository quran;
  late List<Reciter> reciters;
  late void Function() close;

  setUpAll(() async {
    await loadAppFonts();
    (quran, close) = openBundledQuranRepository();
    final database = openBundledQuranDatabase();
    reciters = ReciterRepository(database).reciters();
    database.close();
  });
  tearDownAll(() => close());

  late FakeAudioPlayer player;
  late _FakeSharePort share;

  setUp(() {
    player = FakeAudioPlayer();
    share = _FakeSharePort();
  });

  int idOf(String key) => quran.ayahIdOf(AyahRef.parse(key));

  /// Opens the reader on the page of [key] and long presses a word of it.
  Future<ProviderContainer> openMenu(
    WidgetTester tester,
    String key, {
    Map<String, Object> preferences = const <String, Object>{},
    List<Override> overrides = const <Override>[],
  }) async {
    final id = idOf(key);
    final page = quran.pageOf(id);
    final container = await pumpApp(
      tester,
      size: phone,
      preferences: preferences,
      audioPlayer: player,
      overrides: <Override>[
        sharePortProvider.overrideWithValue(share),
        ...overrides,
      ],
    );
    container.read(appRouterProvider).go(AppRoutes.mushafPage(page));
    await tester.pumpAndSettle();
    final word = quran
        .page(page)
        .lines
        .whereType<AyahLine>()
        .expand((l) => l.words)
        .firstWhere((w) => w.ayahId == id);
    await tester.longPress(find.byKey(MushafWordKey(word.id)));
    await tester.pumpAndSettle();
    return container;
  }

  Finder action(AyahAction a) => find.byKey(AyahActionKey(a));

  ListTile tile(WidgetTester tester, AyahAction a) =>
      tester.widget<ListTile>(action(a));

  Future<void> choose(WidgetTester tester, AyahAction a) async {
    await tester.tap(action(a));
    await tester.pumpAndSettle();
  }

  group('opening', () {
    testWidgets('a long press in the page view opens the menu on that ayah, '
        'highlighted, with its reference', (tester) async {
      final id = idOf('2:6');
      final container = await openMenu(tester, '2:6');

      expect(find.byKey(ayahMenuKey), findsOneWidget);
      expect(
        tester.widget<AyahMenuSheet>(find.byType(AyahMenuSheet)).ayahId,
        id,
      );
      final ayah = quran.ayah(id);
      expect(
        tester.widget<Text>(find.byKey(ayahMenuTitleKey)).data,
        ar.ayahMenuTitle(quran.surah(ayah.surahId).nameAr, ayah.ayahNumber),
      );
      expect(container.read(readerControllerProvider).highlightedAyahId, id);

      // Dismissing the menu removes the highlight it added.
      await tester.tapAt(const Offset(200, 40));
      await tester.pumpAndSettle();
      expect(find.byKey(ayahMenuKey), findsNothing);
      expect(container.read(readerControllerProvider).highlightedAyahId, null);
    });

    testWidgets('a long press in the continuous view opens the menu', (
      tester,
    ) async {
      final container = await pumpApp(
        tester,
        size: phone,
        audioPlayer: player,
        preferences: const <String, Object>{
          SettingsRepository.readingModeKey: 'continuous',
        },
      );
      container
          .read(appRouterProvider)
          .go(AppRoutes.mushafAyah(AyahRef.parse('2:1')));
      await tester.pumpAndSettle();
      final first = idOf('2:1');
      final paragraph = find.byWidgetPredicate(
        (w) => w is AyahParagraph && w.ayahs.first.id == first,
      );
      final rect = tester.getRect(paragraph);
      await tester.longPressAt(Offset(rect.right - 8, rect.top + 26));
      await tester.pumpAndSettle();

      expect(
        tester.widget<AyahMenuSheet>(find.byType(AyahMenuSheet)).ayahId,
        first,
      );
    });

    testWidgets('the actions are listed in the order of FR-017, and Report '
        'an error is hidden until a reporter is provided', (tester) async {
      await openMenu(tester, '2:6');
      final shown = AyahAction.values.where((a) => a != AyahAction.report);
      final tops = <double>[
        for (final a in shown) tester.getTopLeft(action(a)).dy,
      ];
      expect(tops, List<double>.of(tops)..sort());
      expect(tops.toSet(), hasLength(tops.length));
      expect(action(AyahAction.report), findsNothing);
    });

    testWidgets('the open menu counts as a modal, which pauses auto-scroll', (
      tester,
    ) async {
      final container = await openMenu(tester, '2:6');
      expect(container.read(openModalCountProvider), 1);
    });
  });

  group('actions', () {
    testWidgets('Listen recites only that ayah, once', (tester) async {
      final container = await openMenu(tester, '2:6');
      await choose(tester, AyahAction.listen);

      expect(find.byKey(ayahMenuKey), findsNothing);
      final state = container.read(recitationControllerProvider);
      expect(state.mode, PlaybackMode.single);
      expect(state.ayah, AyahRef.parse('2:6'));
      expect(player.loads.single.uris, hasLength(1));
    });

    testWidgets('the reciter shortcut opens the picker over the menu and '
        'saves the choice', (tester) async {
      final container = await openMenu(tester, '2:6');
      final other = reciters.firstWhere(
        (r) => r.id != container.read(reciterIdProvider),
      );
      await tester.tap(find.byKey(ayahMenuReciterKey));
      await tester.pumpAndSettle();
      expect(find.byType(ReciterPicker), findsOneWidget);

      await tester.tap(find.byKey(ReciterTileKey(other.id)));
      await tester.pumpAndSettle();
      expect(container.read(reciterIdProvider), other.id);
      expect(find.byType(ReciterPicker), findsNothing);
      expect(find.byKey(ayahMenuKey), findsOneWidget);

      await choose(tester, AyahAction.listen);
      expect(container.read(recitationControllerProvider).reciterId, other.id);
    });

    testWidgets('Repeat asks for a count starting at repeat_count, then '
        'repeats and the player bar shows the repeats left', (tester) async {
      final container = await openMenu(
        tester,
        '2:6',
        preferences: const <String, Object>{
          SettingsRepository.repeatCountKey: 7,
        },
      );
      await choose(tester, AyahAction.repeat);
      expect(find.byKey(ayahMenuKey), findsNothing);
      expect(find.byKey(repeatPickerKey), findsOneWidget);
      final picker = tester.state<RepeatPickerState>(find.byType(RepeatPicker));
      expect(picker.count, 7);

      await tester.tap(find.byKey(repeatPickerMoreKey));
      await tester.pump();
      expect(picker.count, 8);
      await tester.tap(find.byKey(repeatPickerStartKey));
      await tester.pumpAndSettle();

      final state = container.read(recitationControllerProvider);
      expect(state.mode, PlaybackMode.repeat);
      expect(state.ayah, AyahRef.parse('2:6'));
      expect(state.repeatCount, 8);
      expect(state.remainingRepeats, 8);
      expect(player.loads.single.uris, hasLength(8));
      expect(container.read(repeatCountProvider), 8);
      expect(find.byKey(playerRepeatsKey), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(playerRepeatsKey)).data,
        ar.playerRepeatsLeft(8),
      );
    });

    testWidgets('the repeat count stays within 2 to 20', (tester) async {
      await openMenu(tester, '2:6');
      await choose(tester, AyahAction.repeat);
      final picker = tester.state<RepeatPickerState>(find.byType(RepeatPicker));
      IconButton button(Key key) => tester.widget<IconButton>(find.byKey(key));

      for (var i = 0; i < 30; i++) {
        if (button(repeatPickerFewerKey).onPressed == null) break;
        await tester.tap(find.byKey(repeatPickerFewerKey));
        await tester.pump();
      }
      expect(picker.count, SettingsRepository.minRepeatCount);
      expect(button(repeatPickerFewerKey).onPressed, isNull);

      for (var i = 0; i < 30; i++) {
        if (button(repeatPickerMoreKey).onPressed == null) break;
        await tester.tap(find.byKey(repeatPickerMoreKey));
        await tester.pump();
      }
      expect(picker.count, SettingsRepository.maxRepeatCount);
      expect(button(repeatPickerMoreKey).onPressed, isNull);

      final slider = tester.widget<Slider>(find.byKey(repeatPickerSliderKey));
      expect(slider.min, SettingsRepository.minRepeatCount);
      expect(slider.max, SettingsRepository.maxRepeatCount);
    });

    testWidgets('dismissing the repeat picker starts nothing', (tester) async {
      final container = await openMenu(tester, '2:6');
      await choose(tester, AyahAction.repeat);
      await tester.tapAt(const Offset(200, 40));
      await tester.pumpAndSettle();
      expect(find.byKey(repeatPickerKey), findsNothing);
      expect(
        container.read(recitationControllerProvider).status,
        PlaybackStatus.idle,
      );
      expect(player.loads, isEmpty);
    });

    testWidgets('Tafsir opens the tafsir sheet on that ayah', (tester) async {
      final id = idOf('2:6');
      final container = await openMenu(tester, '2:6');
      await choose(tester, AyahAction.tafsir);

      expect(find.byKey(ayahMenuKey), findsNothing);
      expect(
        tester.state<TafsirSheetState>(find.byType(TafsirSheet)).ayahId,
        id,
      );
      expect(container.read(readerControllerProvider).highlightedAyahId, id);
    });

    testWidgets('Surah story is disabled when the surah has no playable '
        'story', (tester) async {
      final container = await openMenu(
        tester,
        '2:6',
        overrides: <Override>[
          catalogProvider.overrideWith(() => _FixedCatalog(112)),
        ],
      );
      expect(container.read(playableSurahStoryProvider(2)), isNull);
      expect(tile(tester, AyahAction.surahStory).enabled, isFalse);
      expect(
        find.descendant(
          of: action(AyahAction.surahStory),
          matching: find.text(ar.ayahMenuStoryUnavailable),
        ),
        findsOneWidget,
      );
      await tester.tap(action(AyahAction.surahStory));
      await tester.pumpAndSettle();
      expect(find.byKey(ayahMenuKey), findsOneWidget);
    });

    testWidgets('Surah story is disabled with the bundled catalog, which has '
        'no playable story for the surah', (tester) async {
      // The bundled file, read synchronously, and an empty cache directory,
      // so that loading needs no platform channel.
      final cache = Directory.systemTemp.createTempSync('catalog');
      addTearDown(() => cache.deleteSync(recursive: true));
      final container = await openMenu(
        tester,
        '112:1',
        overrides: <Override>[
          bundledCatalogLoaderProvider.overrideWithValue(
            () async => File(bundledCatalogAsset).readAsStringSync(),
          ),
          catalogCacheDirectoryProvider.overrideWithValue(() async => cache),
        ],
      );
      final catalog = container.read(catalogProvider);
      expect(catalog.hasValue, isTrue);
      expect(catalog.requireValue.playableStoryForSurah(112), isNull);
      expect(tile(tester, AyahAction.surahStory).enabled, isFalse);
    });

    testWidgets('Surah story opens the story route when the surah has a '
        'playable story', (tester) async {
      final container = await openMenu(
        tester,
        '112:1',
        overrides: <Override>[
          catalogProvider.overrideWith(() => _FixedCatalog(112)),
        ],
      );
      expect(tile(tester, AyahAction.surahStory).enabled, isTrue);
      await choose(tester, AyahAction.surahStory);

      expect(find.byKey(ayahMenuKey), findsNothing);
      expect(
        container
            .read(appRouterProvider)
            .routerDelegate
            .currentConfiguration
            .uri
            .toString(),
        AppRoutes.surahStory(112),
      );
    });

    testWidgets('Bookmark toggles the bookmark and the menu stays open', (
      tester,
    ) async {
      final id = idOf('2:6');
      final container = await openMenu(tester, '2:6');
      final bookmarks = await container.read(bookmarkRepositoryProvider.future);
      expect(bookmarks.isSet(id), isFalse);
      expect(
        find.descendant(
          of: action(AyahAction.bookmark),
          matching: find.text(ar.ayahMenuAddBookmark),
        ),
        findsOneWidget,
      );

      await choose(tester, AyahAction.bookmark);
      expect(bookmarks.isSet(id), isTrue);
      expect(find.byKey(ayahMenuKey), findsOneWidget);
      expect(
        find.descendant(
          of: action(AyahAction.bookmark),
          matching: find.text(ar.ayahMenuRemoveBookmark),
        ),
        findsOneWidget,
      );

      await choose(tester, AyahAction.bookmark);
      expect(bookmarks.isSet(id), isFalse);
      expect(bookmarks.list(), isEmpty);
    });

    testWidgets('Share hands the formatted ayah to the share sheet', (
      tester,
    ) async {
      final id = idOf('2:6');
      await openMenu(tester, '2:6');
      await choose(tester, AyahAction.share);

      expect(find.byKey(ayahMenuKey), findsNothing);
      final ayah = quran.ayah(id);
      expect(share.shared, <String>[
        formatAyahShareText(
          ayah: ayah,
          surah: quran.surah(ayah.surahId),
          l10n: ar,
        ),
      ]);
      // A non-empty anchor for the iPad share popover.
      expect(share.origins.single, isNotNull);
      expect(share.origins.single!.isEmpty, isFalse);
    });

    testWidgets('Report an error is listed last when a reporter is provided, '
        'and reports that ayah', (tester) async {
      final reported = <int>[];
      await openMenu(
        tester,
        '2:6',
        overrides: <Override>[
          ayahErrorReporterProvider.overrideWithValue(
            (context, ayahId) async => reported.add(ayahId),
          ),
        ],
      );
      final tops = <double>[
        for (final a in AyahAction.values) tester.getTopLeft(action(a)).dy,
      ];
      expect(tops, List<double>.of(tops)..sort());
      expect(tops.last, greaterThan(tops[tops.length - 2]));

      await choose(tester, AyahAction.report);
      expect(reported, <int>[idOf('2:6')]);
      expect(find.byKey(ayahMenuKey), findsNothing);
    });
  });

  group('share text', () {
    // Checked by structure against values read from the database: the
    // stored text first, then a blank line, then the reference line.
    for (final key in <String>['1:1', '2:255', '114:6']) {
      for (final l10n in <AppLocalizations>[ar, en]) {
        test('$key in ${l10n.localeName}', () {
          final ayah = quran.ayah(idOf(key));
          final surah = quran.surah(ayah.surahId);
          final name = l10n.localeName == 'ar' ? surah.nameAr : surah.nameEn;
          final text = formatAyahShareText(
            ayah: ayah,
            surah: surah,
            l10n: l10n,
          );
          final parts = text.split('\n\n');

          expect(ayah.textUthmani, isNotEmpty);
          expect(parts, hasLength(2));
          expect(parts.first, ayah.textUthmani);
          expect(parts.last, l10n.ayahShareReference(name, ayah.ayahNumber));
          expect(parts.last, contains(name));
          expect(parts.last, contains('${ayah.ayahNumber}'));
        });
      }
    }
  });
}
