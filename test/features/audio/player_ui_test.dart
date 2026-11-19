import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:muslim/core/l10n/generated/app_localizations.dart';
import 'package:muslim/core/routing/app_router.dart';
import 'package:muslim/core/settings/settings_providers.dart';
import 'package:muslim/core/settings/settings_repository.dart';
import 'package:muslim/data/models/ayah_ref.dart';
import 'package:muslim/data/models/reciter.dart';
import 'package:muslim/data/quran_repository.dart';
import 'package:muslim/data/reciter_repository.dart';
import 'package:muslim/features/audio/playback_state.dart';
import 'package:muslim/features/audio/player_bar.dart';
import 'package:muslim/features/audio/recitation_controller.dart';
import 'package:muslim/features/audio/reciter_picker.dart';
import 'package:muslim/features/mushaf/reader_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_audio.dart';
import '../../helpers/fonts.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/quran_database.dart';

// The player bar, the reciter picker and the reader following playback
// (T016). The audio player and the wake lock are fakes; nothing reaches the
// network. Assertions compare ids, keys, numbers and values read from the
// bundled database; no Quran text, surah name or reciter name appears here.

final AppLocalizations ar = lookupAppLocalizations(const Locale('ar'));

const Size phone = Size(400, 800);

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
  late FakeWakeLock wakeLock;

  setUp(() {
    player = FakeAudioPlayer();
    wakeLock = FakeWakeLock();
  });

  Reciter reciterWithId(int id) => reciters.firstWhere((r) => r.id == id);

  /// Opens the reader on [page] with the fakes.
  Future<ProviderContainer> openReader(
    WidgetTester tester,
    int page, {
    Map<String, Object> preferences = const <String, Object>{},
  }) async {
    final container = await pumpApp(
      tester,
      size: phone,
      preferences: preferences,
      audioPlayer: player,
      wakeLock: wakeLock,
    );
    container.read(appRouterProvider).go(AppRoutes.mushafPage(page));
    await tester.pumpAndSettle();
    return container;
  }

  int shownPage(WidgetTester tester) {
    final view = tester.widget<PageView>(find.byType(PageView));
    return view.controller!.page!.round() + 1;
  }

  String? textOf(WidgetTester tester, Key key) =>
      tester.widget<Text>(find.byKey(key)).data;

  Future<void> tap(WidgetTester tester, Key key) async {
    await tester.tap(find.byKey(key));
    await tester.pumpAndSettle();
  }

  /// The id of an ayah that is the last to start on its page and whose
  /// next ayah, in the same surah, starts on the next page.
  int lastAyahBeforePageBreak() {
    for (var page = 50; page < 600; page++) {
      final next = firstAyahStartingOn(quran.page(page + 1));
      final before = next - 1;
      if (quran.refOf(next).ayah > 1 &&
          quran.pageOf(before) == page &&
          quran.pageOf(next) == page + 1) {
        return before;
      }
    }
    throw StateError('No page break inside a surah found');
  }

  group('play control', () {
    testWidgets('is in the reader and starts from the current ayah', (
      tester,
    ) async {
      const page = 50;
      final container = await openReader(tester, page);
      expect(find.byKey(playerBarKey), findsNothing);
      final current = container.read(readerControllerProvider).currentAyahId;
      final from = quran.refOf(current);

      await tap(tester, playFromHereKey);

      final state = container.read(recitationControllerProvider);
      expect(state.status, PlaybackStatus.playing);
      expect(state.ayah, from);
      expect(state.mode, PlaybackMode.surah);

      // The playlist is the whole surah with the default reciter, starting
      // at the current ayah.
      final reciter = reciterWithId(SettingsRepository.defaultReciterId);
      final load = player.loads.single;
      expect(load.initialIndex, from.ayah - 1);
      expect(load.uris, <Uri>[
        for (var a = 1; a <= quran.ayahCounts[from.surah - 1]; a++)
          reciter.audioUrl(AyahRef(from.surah, a)),
      ]);
      expect(player.commands.last, 'play');
      expect(wakeLock.held, isTrue);

      // The bar names the reciter, the surah and the ayah, from the
      // database.
      expect(find.byKey(playerBarKey), findsOneWidget);
      expect(textOf(tester, playerReciterNameKey), reciter.nameAr);
      expect(
        textOf(tester, playerPositionKey),
        ar.playerPosition(quran.surah(from.surah).nameAr, from.ayah),
      );

      // The ayah being recited is highlighted on the page shown.
      final reader = container.read(readerControllerProvider);
      expect(reader.highlightedAyahId, current);
      expect(reader.currentAyahId, current);
      expect(shownPage(tester), page);
    });

    testWidgets('starts from the ayah the reader turned to', (tester) async {
      final container = await openReader(tester, 100);
      await tap(tester, playFromHereKey);
      await tap(tester, playerStopKey);

      // Turn one page by dragging, then play again.
      await tester.drag(find.byType(PageView), const Offset(300, 0));
      await tester.pumpAndSettle();
      expect(shownPage(tester), 101);
      final current = container.read(readerControllerProvider).currentAyahId;
      expect(current, firstAyahStartingOn(quran.page(101)));

      await tap(tester, playFromHereKey);

      expect(
        container.read(recitationControllerProvider).ayah,
        quran.refOf(current),
      );
      expect(player.loads.last.initialIndex, quran.refOf(current).ayah - 1);
    });
  });

  group('the reader follows playback', () {
    testWidgets('highlight and page follow an ayah change across a page '
        'boundary', (tester) async {
      final before = lastAyahBeforePageBreak();
      final after = before + 1;
      final page = quran.pageOf(before);
      final container = await openReader(tester, page);
      container.read(readerControllerProvider.notifier).goToAyah(before);
      await tester.pumpAndSettle();

      await tap(tester, playFromHereKey);
      expect(
        container.read(recitationControllerProvider).ayah,
        quran.refOf(before),
      );
      expect(
        container.read(readerControllerProvider).highlightedAyahId,
        before,
      );
      expect(shownPage(tester), page);

      // The player moves on to the next ayah by itself.
      player.advanceTo(quran.refOf(after).ayah - 1);
      await tester.pumpAndSettle();

      final reader = container.read(readerControllerProvider);
      expect(reader.highlightedAyahId, after);
      expect(reader.currentAyahId, after);
      expect(reader.page, page + 1);
      expect(shownPage(tester), page + 1);
      expect(
        textOf(tester, playerPositionKey),
        ar.playerPosition(
          quran.surah(quran.refOf(after).surah).nameAr,
          quran.refOf(after).ayah,
        ),
      );

      // Previous goes back across the boundary too.
      await tap(tester, playerPreviousKey);
      expect(player.commands.last, 'seek:${quran.refOf(before).ayah - 1}');
      expect(
        container.read(readerControllerProvider).highlightedAyahId,
        before,
      );
      expect(shownPage(tester), page);

      // And next forward again.
      await tap(tester, playerNextKey);
      expect(container.read(readerControllerProvider).highlightedAyahId, after);
      expect(shownPage(tester), page + 1);
    });

    testWidgets('the continuous view follows the current ayah', (tester) async {
      final before = lastAyahBeforePageBreak();
      final container = await openReader(
        tester,
        quran.pageOf(before),
        preferences: <String, Object>{
          SettingsRepository.readingModeKey: ReadingMode.continuous.name,
        },
      );
      expect(find.byType(PageView), findsNothing);
      container.read(readerControllerProvider.notifier).goToAyah(before);
      await tester.pumpAndSettle();

      await tap(tester, playFromHereKey);
      player.advanceTo(quran.refOf(before + 1).ayah - 1);
      await tester.pumpAndSettle();

      final reader = container.read(readerControllerProvider);
      expect(reader.currentAyahId, before + 1);
      expect(reader.highlightedAyahId, before + 1);
    });

    testWidgets('pause and resume keep the highlight; stop clears it and '
        'leaves the reader on the last ayah', (tester) async {
      final container = await openReader(tester, 60);
      await tap(tester, playFromHereKey);
      final current = container.read(readerControllerProvider).currentAyahId;

      await tap(tester, playerPlayPauseKey);
      expect(
        container.read(recitationControllerProvider).status,
        PlaybackStatus.paused,
      );
      expect(player.commands.last, 'pause');
      expect(wakeLock.held, isFalse);
      expect(
        container.read(readerControllerProvider).highlightedAyahId,
        current,
      );

      await tap(tester, playerPlayPauseKey);
      expect(
        container.read(recitationControllerProvider).status,
        PlaybackStatus.playing,
      );
      expect(player.commands.last, 'play');
      expect(wakeLock.held, isTrue);

      await tap(tester, playerStopKey);
      expect(container.read(recitationControllerProvider).isActive, isFalse);
      expect(find.byKey(playerBarKey), findsNothing);
      final reader = container.read(readerControllerProvider);
      expect(reader.highlightedAyahId, isNull);
      expect(reader.currentAyahId, current);
      expect(shownPage(tester), 60);
      expect(wakeLock.held, isFalse);
    });

    testWidgets('previous is disabled on the first ayah of the surah', (
      tester,
    ) async {
      final surah = quran.surah(2);
      final container = await openReader(tester, surah.pageStart);
      container
          .read(readerControllerProvider.notifier)
          .goToAyah(quran.ayahIdOf(AyahRef(2, 1)));
      await tester.pumpAndSettle();
      await tap(tester, playFromHereKey);

      expect(
        tester.widget<IconButton>(find.byKey(playerPreviousKey)).onPressed,
        isNull,
      );
      expect(
        tester.widget<IconButton>(find.byKey(playerNextKey)).onPressed,
        isNotNull,
      );
    });
  });

  group('reciter picker', () {
    testWidgets('lists every reciter with its style and persists the choice', (
      tester,
    ) async {
      final container = await openReader(tester, 70);
      await tap(tester, playFromHereKey);
      final from = container.read(recitationControllerProvider).ayah!;

      await tap(tester, playerReciterKey);
      expect(find.byType(ReciterPicker), findsOneWidget);
      expect(reciters.length, greaterThanOrEqualTo(5));
      for (final reciter in reciters) {
        final tile = find.byKey(ReciterTileKey(reciter.id));
        await tester.ensureVisible(tile);
        expect(tile, findsOneWidget);
        final listTile = tester.widget<ListTile>(tile);
        expect((listTile.title! as Text).data, reciter.nameAr);
        final style = (listTile.subtitle as Text?)?.data;
        expect(style, switch (reciter.style) {
          null => isNull,
          ReciterStyle.murattal => ar.reciterStyleMurattal,
          ReciterStyle.mujawwad => ar.reciterStyleMujawwad,
          ReciterStyle.muallim => ar.reciterStyleMuallim,
        });
        expect(
          listTile.selected,
          reciter.id == SettingsRepository.defaultReciterId,
        );
      }
      expect(
        reciters.where((r) => r.style == ReciterStyle.muallim),
        isNotEmpty,
      );

      final chosen = reciters.firstWhere(
        (r) => r.id != SettingsRepository.defaultReciterId,
      );
      await tester.ensureVisible(find.byKey(ReciterTileKey(chosen.id)));
      await tap(tester, ReciterTileKey(chosen.id));

      // The sheet closes; the choice is saved and the recitation continues
      // from the same ayah with the new reciter.
      expect(find.byType(ReciterPicker), findsNothing);
      expect(container.read(reciterIdProvider), chosen.id);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(SettingsRepository.reciterIdKey), chosen.id);
      final state = container.read(recitationControllerProvider);
      expect(state.reciterId, chosen.id);
      expect(state.ayah, from);
      expect(
        player.loads.last.uris[player.loads.last.initialIndex],
        chosen.audioUrl(from),
      );
      expect(textOf(tester, playerReciterNameKey), chosen.nameAr);
    });

    testWidgets('a saved choice is used after a restart', (tester) async {
      final chosen = reciters.last;
      final container = await openReader(
        tester,
        80,
        preferences: <String, Object>{
          SettingsRepository.reciterIdKey: chosen.id,
        },
      );
      await tap(tester, playFromHereKey);
      final from = container.read(recitationControllerProvider).ayah!;
      expect(container.read(recitationControllerProvider).reciterId, chosen.id);
      expect(player.loads.single.uris[from.ayah - 1], chosen.audioUrl(from));

      await tap(tester, playerReciterKey);
      expect(
        tester.widget<ListTile>(find.byKey(ReciterTileKey(chosen.id))).selected,
        isTrue,
      );
    });
  });

  group('offline', () {
    testWidgets('a load failure shows the offline state with retry, and '
        'reading continues', (tester) async {
      final container = await openReader(tester, 90);
      final current = container.read(readerControllerProvider).currentAyahId;
      player.failNextLoad = const SocketException('offline');

      await tap(tester, playFromHereKey);

      expect(
        container.read(recitationControllerProvider).status,
        PlaybackStatus.error,
      );
      expect(find.byKey(playerOfflineKey), findsOneWidget);
      expect(find.byKey(playerRetryKey), findsOneWidget);
      expect(find.text(ar.playerOfflineMessage), findsOneWidget);
      expect(find.byKey(playerPlayPauseKey), findsNothing);
      expect(wakeLock.held, isFalse);
      // The failed ayah stays marked; retry continues from there.
      expect(
        container.read(readerControllerProvider).highlightedAyahId,
        current,
      );

      // Reading is unaffected: the page still turns.
      await tester.drag(find.byType(PageView), const Offset(300, 0));
      await tester.pumpAndSettle();
      expect(shownPage(tester), 91);
      expect(container.read(readerControllerProvider).page, 91);

      await tap(tester, playerRetryKey);

      final state = container.read(recitationControllerProvider);
      expect(state.status, PlaybackStatus.playing);
      expect(state.ayah, quran.refOf(current));
      expect(player.loads, hasLength(2));
      expect(player.loads.last.initialIndex, quran.refOf(current).ayah - 1);
      expect(find.byKey(playerOfflineKey), findsNothing);
      expect(find.byKey(playerPlayPauseKey), findsOneWidget);
      // The reader returns to the ayah being recited.
      expect(shownPage(tester), 90);
      expect(wakeLock.held, isTrue);
    });

    testWidgets('a failure during playback shows the offline state', (
      tester,
    ) async {
      final container = await openReader(tester, 95);
      await tap(tester, playFromHereKey);

      player.fail();
      await tester.pumpAndSettle();

      expect(
        container.read(recitationControllerProvider).status,
        PlaybackStatus.error,
      );
      expect(find.byKey(playerOfflineKey), findsOneWidget);

      await tap(tester, playerStopKey);
      expect(find.byKey(playerBarKey), findsNothing);
      expect(
        container.read(readerControllerProvider).highlightedAyahId,
        isNull,
      );
    });
  });

  testWidgets('the player bar in the light theme', (tester) async {
    final container = await openReader(tester, 50);
    await tap(tester, playFromHereKey);
    expect(container.read(recitationControllerProvider).isActive, isTrue);

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../goldens/audio/player_bar_light.png'),
    );
  });
}
