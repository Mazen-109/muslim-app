import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:muslim/core/routing/app_router.dart';
import 'package:muslim/core/routing/modal_observer.dart';
import 'package:muslim/core/settings/settings_repository.dart';
import 'package:muslim/data/models/ayah_ref.dart';
import 'package:muslim/data/quran_repository.dart';
import 'package:muslim/features/audio/player_bar.dart';
import 'package:muslim/features/audio/wake_lock.dart';
import 'package:muslim/features/autoscroll/autoscroll_controller.dart';
import 'package:muslim/features/autoscroll/autoscroll_controls.dart';
import 'package:muslim/features/mushaf/continuous/ayah_paragraph.dart';
import 'package:muslim/features/mushaf/continuous/continuous_view.dart';
import 'package:muslim/features/mushaf/page_view/mushaf_page_view.dart';
import 'package:muslim/features/mushaf/reader_controller.dart';
import 'package:muslim/features/mushaf/reader_screen.dart';
import 'package:muslim/features/tafsir/tafsir_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_audio.dart';
import '../../helpers/fonts.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/quran_database.dart';

// Auto-scroll (T021, US8). The frames are driven by the test binding's
// clock, so every pump of a duration is one controllable tick of the
// scroller. Assertions are on states, keys, scroll offsets and the wake
// lock; no Quran text appears here.

const Size phone = Size(400, 800);

/// A [WakeLock] that records its calls.
class RecordingWakeLock implements WakeLock {
  bool held = false;
  final List<bool> calls = <bool>[];

  @override
  Future<void> enable() async {
    held = true;
    calls.add(true);
  }

  @override
  Future<void> disable() async {
    held = false;
    calls.add(false);
  }
}

/// One frame step.
const Duration frame = Duration(milliseconds: 100);

void main() {
  late QuranRepository repository;
  late void Function() closeRepository;

  setUpAll(() async {
    await loadAppFonts();
    (repository, closeRepository) = openBundledQuranRepository();
  });
  tearDownAll(() => closeRepository());

  group('wake lock service', () {
    test('counts holds: the platform lock follows the first and the last', () {
      final lock = RecordingWakeLock();
      final service = WakeLockService(lock);
      expect(service.isHeld, isFalse);

      service.acquire();
      service.acquire();
      expect(service.holds, 2);
      expect(lock.calls, <bool>[true]);

      service.release();
      expect(service.isHeld, isTrue);
      expect(lock.held, isTrue);

      service.release();
      expect(service.isHeld, isFalse);
      expect(lock.calls, <bool>[true, false]);

      expect(service.release, throwsStateError);
    });

    test('dispose lets the screen sleep', () {
      final lock = RecordingWakeLock();
      final service = WakeLockService(lock)..acquire();
      service.dispose();
      expect(lock.calls, <bool>[true, false]);
      service.release();
      expect(lock.calls, <bool>[true, false]);
    });
  });

  group('reader', () {
    late RecordingWakeLock wakeLock;
    late FakeAudioPlayer player;

    setUp(() {
      wakeLock = RecordingWakeLock();
      player = FakeAudioPlayer();
    });

    Future<ProviderContainer> openReader(
      WidgetTester tester,
      String key, {
      String mode = 'continuous',
      double? speed,
    }) async {
      final container = await pumpApp(
        tester,
        size: phone,
        wakeLock: wakeLock,
        audioPlayer: player,
        preferences: <String, Object>{
          SettingsRepository.readingModeKey: mode,
          SettingsRepository.autoscrollSpeedKey: ?speed,
        },
      );
      container
          .read(appRouterProvider)
          .go(AppRoutes.mushafAyah(AyahRef.parse(key)));
      await tester.pumpAndSettle();
      return container;
    }

    AutoscrollStatus status(ProviderContainer c) =>
        c.read(autoscrollControllerProvider);

    int holds(ProviderContainer c) => c.read(wakeLockServiceProvider).holds;

    ScrollPosition position(WidgetTester tester) => tester
        .state<ScrollableState>(
          find.descendant(
            of: find.byKey(continuousScrollKey),
            matching: find.byType(Scrollable),
          ),
        )
        .position;

    /// Pumps [count] frames of [frame] each.
    Future<void> run(WidgetTester tester, int count) async {
      for (var i = 0; i < count; i++) {
        await tester.pump(frame);
      }
    }

    /// Starts auto-scroll from the reader's menu, then pumps the first
    /// frame, which starts the clock.
    Future<void> startFromMenu(WidgetTester tester) async {
      await tester.tap(find.byKey(readerMoreKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(readerAutoscrollKey));
      await tester.pump();
      await tester.pump(frame);
    }

    /// Lets the bar finish sliding in, measured in frames that also move
    /// the text, so it is done before a measurement.
    Future<void> settleBar(WidgetTester tester) => run(tester, 4);

    testWidgets('scrolls the distance that the speed and the time give, and '
        'keeps the screen awake', (tester) async {
      final c = await openReader(tester, '2:1');
      expect(status(c), AutoscrollStatus.off);
      expect(find.byKey(autoscrollBarKey), findsNothing);

      await startFromMenu(tester);
      expect(status(c), AutoscrollStatus.running);
      expect(find.byKey(autoscrollBarKey), findsOneWidget);
      expect(wakeLock.held, isTrue);
      expect(holds(c), 1);
      await settleBar(tester);

      final from = position(tester).pixels;
      await run(tester, 20);
      // The default speed, 30 logical pixels per second, for 2 seconds.
      expect(position(tester).pixels - from, closeTo(60, 0.01));

      // The reader's position follows the text.
      final top = c.read(readerControllerProvider).currentAyahId;
      await run(tester, 200);
      expect(c.read(readerControllerProvider).currentAyahId, greaterThan(top));
    });

    testWidgets('runs at the stored speed', (tester) async {
      final c = await openReader(tester, '2:1', speed: 90);
      await startFromMenu(tester);
      await settleBar(tester);
      expect(status(c), AutoscrollStatus.running);

      final from = position(tester).pixels;
      await run(tester, 10);
      expect(position(tester).pixels - from, closeTo(90, 0.01));
    });

    testWidgets('a tap on the text pauses and a second resumes', (
      tester,
    ) async {
      final c = await openReader(tester, '2:1');
      await startFromMenu(tester);
      await settleBar(tester);

      await tester.tap(find.byKey(continuousScrollKey));
      await tester.pump();
      expect(status(c), AutoscrollStatus.paused);
      expect(wakeLock.held, isFalse);
      // The tap did not open the tafsir sheet.
      expect(find.byType(BottomSheet), findsNothing);

      final held = position(tester).pixels;
      await run(tester, 10);
      expect(position(tester).pixels, held);

      await tester.tap(find.byKey(continuousScrollKey));
      await tester.pump();
      expect(status(c), AutoscrollStatus.running);
      expect(wakeLock.held, isTrue);
      // The frame of the tap started the clock again from zero.
      expect(position(tester).pixels, held);
      await run(tester, 10);
      expect(position(tester).pixels - held, closeTo(30, 0.01));

      // The bar's button does the same.
      await tester.tap(find.byKey(autoscrollPauseKey));
      await tester.pump();
      expect(status(c), AutoscrollStatus.paused);
      await tester.tap(find.byKey(autoscrollPauseKey));
      await tester.pump();
      expect(status(c), AutoscrollStatus.running);
    });

    testWidgets('a speed change applies at once and is remembered', (
      tester,
    ) async {
      final c = await openReader(tester, '2:1');
      await startFromMenu(tester);
      await settleBar(tester);

      final slider = tester.widget<Slider>(find.byKey(autoscrollSpeedKey));
      expect(slider.min, SettingsRepository.minAutoscrollSpeed);
      expect(slider.max, SettingsRepository.maxAutoscrollSpeed);
      expect(slider.value, SettingsRepository.defaultAutoscrollSpeed);

      slider.onChanged!(120);
      await tester.pump(frame);
      var from = position(tester).pixels;
      await run(tester, 10);
      expect(position(tester).pixels - from, closeTo(120, 0.01));

      slider.onChanged!(10);
      slider.onChangeEnd!(10);
      await tester.pump(frame);
      from = position(tester).pixels;
      await run(tester, 10);
      expect(position(tester).pixels - from, closeTo(10, 0.01));
      expect(status(c), AutoscrollStatus.running);
      expect(tester.widget<Slider>(find.byKey(autoscrollSpeedKey)).value, 10);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble(SettingsRepository.autoscrollSpeedKey), 10);
    });

    testWidgets('hands over to the recitation while it plays and back when '
        'it stops', (tester) async {
      final c = await openReader(tester, '2:1');
      await startFromMenu(tester);
      await settleBar(tester);

      await tester.tap(find.byKey(playFromHereKey));
      await run(tester, 3);
      expect(status(c), AutoscrollStatus.followingAudio);
      expect(find.byKey(autoscrollFollowingKey), findsOneWidget);
      // Both features hold the one wake lock.
      expect(holds(c), 2);
      expect(wakeLock.calls, <bool>[true]);

      // The timer no longer moves the text; the recitation does.
      final held = position(tester).pixels;
      await run(tester, 10);
      expect(position(tester).pixels, held);
      final followed = c.read(readerControllerProvider).currentAyahId;
      player.advanceTo(9);
      await run(tester, 3);
      expect(
        c.read(readerControllerProvider).currentAyahId,
        repository.ayahIdOf(AyahRef(2, 10)),
      );
      expect(c.read(readerControllerProvider).currentAyahId, isNot(followed));

      // A tap on the text is not taken by auto-scroll while the recitation
      // leads.
      expect(status(c), AutoscrollStatus.followingAudio);

      await tester.tap(find.byKey(playerStopKey));
      await tester.pump();
      expect(status(c), AutoscrollStatus.running);
      expect(holds(c), 1);
      expect(wakeLock.held, isTrue);
      await run(tester, 4);
      final from = position(tester).pixels;
      await run(tester, 10);
      expect(position(tester).pixels - from, closeTo(30, 0.01));

      // A recitation paused by the reader no longer leads either.
      await tester.tap(find.byKey(playFromHereKey));
      await run(tester, 3);
      expect(status(c), AutoscrollStatus.followingAudio);
      await tester.tap(find.byKey(playerPlayPauseKey));
      await tester.pump();
      expect(status(c), AutoscrollStatus.running);
      expect(holds(c), 1);

      // Stopping auto-scroll keeps the screen awake while audio plays.
      await tester.tap(find.byKey(playerPlayPauseKey));
      await tester.pump();
      expect(status(c), AutoscrollStatus.followingAudio);
      await tester.tap(find.byKey(autoscrollStopKey));
      await tester.pump();
      expect(status(c), AutoscrollStatus.off);
      expect(holds(c), 1);
      expect(wakeLock.held, isTrue);
      await tester.tap(find.byKey(playerStopKey));
      await tester.pumpAndSettle();
      expect(holds(c), 0);
      expect(wakeLock.held, isFalse);
    });

    testWidgets('resuming while a recitation plays follows it', (tester) async {
      final c = await openReader(tester, '2:1');
      await startFromMenu(tester);
      c.read(autoscrollControllerProvider.notifier).pause();
      await tester.tap(find.byKey(playFromHereKey));
      await run(tester, 3);
      expect(status(c), AutoscrollStatus.paused);
      expect(holds(c), 1);

      c.read(autoscrollControllerProvider.notifier).resume();
      await tester.pump();
      expect(status(c), AutoscrollStatus.followingAudio);
      expect(holds(c), 2);
      await tester.tap(find.byKey(playerStopKey));
      await tester.tap(find.byKey(autoscrollStopKey));
      await tester.pumpAndSettle();
      expect(holds(c), 0);
    });

    testWidgets('stops at the end of the surah and lets the screen sleep', (
      tester,
    ) async {
      final c = await openReader(tester, '87:1', speed: 120);
      await startFromMenu(tester);
      await settleBar(tester);
      // Start near the end, so the test runs a few seconds of frames.
      final p = position(tester);
      p.jumpTo(p.maxScrollExtent - 150);
      await tester.pump(frame);

      var frames = 0;
      while (status(c) != AutoscrollStatus.off && frames < 100) {
        await tester.pump(frame);
        frames++;
      }
      expect(status(c), AutoscrollStatus.off);
      expect(frames, greaterThan(5));
      expect(position(tester).pixels, position(tester).maxScrollExtent);
      expect(holds(c), 0);
      expect(wakeLock.held, isFalse);
      // The last ayah of the surah is still on screen to finish reading.
      final last = repository.ayahIdOf(AyahRef(87, repository.ayahCounts[86]));
      final viewport = tester.renderObject<RenderBox>(
        find.byKey(continuousScrollKey),
      );
      final tops = <int, double>{
        for (final state in tester.stateList<AyahParagraphState>(
          find.byType(AyahParagraph),
        ))
          for (final (id, top) in state.ayahTops(viewport)) id: top,
      };
      expect(tops[last], isNotNull);
      expect(tops[last], inInclusiveRange(0, viewport.size.height));
      await tester.pumpAndSettle();
      expect(find.byKey(autoscrollBarKey), findsNothing);
    });

    testWidgets('in the page view it offers the continuous view', (
      tester,
    ) async {
      final c = await openReader(tester, '2:1', mode: 'pages');
      expect(find.byType(MushafPageView), findsOneWidget);

      // Declined: the page view stays and auto-scroll stays off.
      await tester.tap(find.byKey(readerMoreKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(readerAutoscrollKey));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.byType(TextButton).last);
      await tester.pumpAndSettle();
      expect(find.byType(MushafPageView), findsOneWidget);
      expect(status(c), AutoscrollStatus.off);
      expect(c.read(readerControllerProvider).mode, ReadingMode.pages);

      // Accepted: the continuous view, running.
      await tester.tap(find.byKey(readerMoreKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(readerAutoscrollKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(autoscrollSwitchKey));
      await tester.pump();
      await tester.pump(frame);
      expect(c.read(readerControllerProvider).mode, ReadingMode.continuous);
      expect(find.byType(ContinuousView), findsOneWidget);
      expect(status(c), AutoscrollStatus.running);
      expect(wakeLock.held, isTrue);

      // Starting auto-scroll from the controller alone does nothing in the
      // page view.
      await tester.tap(find.byKey(readerModeToggleKey));
      await tester.pumpAndSettle();
      c.read(autoscrollControllerProvider.notifier).start();
      expect(status(c), AutoscrollStatus.off);
    });

    testWidgets('leaving the continuous view turns it off', (tester) async {
      final c = await openReader(tester, '2:1');
      await startFromMenu(tester);
      await tester.tap(find.byKey(readerModeToggleKey));
      await tester.pumpAndSettle();
      expect(find.byType(MushafPageView), findsOneWidget);
      expect(status(c), AutoscrollStatus.off);
      expect(wakeLock.held, isFalse);
    });

    testWidgets('leaving the reader turns it off', (tester) async {
      final c = await openReader(tester, '2:1');
      await startFromMenu(tester);
      c.read(appRouterProvider).go(AppRoutes.index);
      await tester.pumpAndSettle();
      expect(find.byType(ReaderScreen), findsNothing);
      expect(status(c), AutoscrollStatus.off);
      expect(wakeLock.held, isFalse);
    });

    testWidgets('another tab turns it off', (tester) async {
      final c = await openReader(tester, '2:1');
      await startFromMenu(tester);
      c.read(appRouterProvider).go(AppRoutes.bookmarks);
      await tester.pumpAndSettle();
      expect(status(c), AutoscrollStatus.off);
      expect(wakeLock.held, isFalse);
    });

    testWidgets('the reader menu turns it off', (tester) async {
      final c = await openReader(tester, '2:1');
      await startFromMenu(tester);
      await tester.tap(find.byKey(readerMoreKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(readerAutoscrollKey));
      await tester.pumpAndSettle();
      expect(status(c), AutoscrollStatus.off);
      expect(wakeLock.held, isFalse);
    });

    group('sheets and menus', () {
      testWidgets('opening a menu or a sheet pauses, closing it resumes', (
        tester,
      ) async {
        final c = await openReader(tester, '2:1');
        await startFromMenu(tester);

        // The overflow menu.
        await tester.tap(find.byKey(readerMoreKey));
        await tester.pump();
        expect(c.read(openModalCountProvider), 1);
        expect(status(c), AutoscrollStatus.paused);
        expect(wakeLock.held, isFalse);

        // The text size sheet, from the menu.
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(readerTextSizeKey));
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsOneWidget);
        expect(status(c), AutoscrollStatus.paused);
        final held = position(tester).pixels;

        await tester.tapAt(const Offset(200, 40)); // The scrim.
        // The sheet slides away; it keeps running from then on, so the
        // test pumps frames instead of waiting to settle.
        await run(tester, 6);
        expect(c.read(openModalCountProvider), 0);
        expect(status(c), AutoscrollStatus.running);
        expect(wakeLock.held, isTrue);
        await run(tester, 5);
        expect(position(tester).pixels, greaterThan(held));
      });

      testWidgets('the tafsir sheet on the root navigator pauses too', (
        tester,
      ) async {
        final c = await openReader(tester, '2:1');
        await startFromMenu(tester);

        final context = tester.element(find.byType(ContinuousView));
        unawaited(showTafsirSheet(context, repository.ayahIdOf(AyahRef(2, 2))));
        await tester.pump();
        expect(status(c), AutoscrollStatus.paused);
        await tester.pumpAndSettle();

        Navigator.of(context, rootNavigator: true).pop();
        await run(tester, 6);
        expect(status(c), AutoscrollStatus.running);
        c.read(autoscrollControllerProvider.notifier).stop();
      });

      testWidgets('a pause by the reader outlasts a sheet', (tester) async {
        final c = await openReader(tester, '2:1');
        await startFromMenu(tester);
        await tester.tap(find.byKey(autoscrollPauseKey));
        await tester.pump();
        expect(status(c), AutoscrollStatus.paused);

        await tester.tap(find.byKey(readerMoreKey));
        await tester.pumpAndSettle();
        await tester.tapAt(const Offset(200, 700));
        await tester.pumpAndSettle();
        expect(c.read(openModalCountProvider), 0);
        expect(status(c), AutoscrollStatus.paused);
      });
    });
  });

  // Checked by eye against DESIGN.md: the bar sits on the ground under the
  // text with a hairline rule above it, like the player bar; one ink for
  // the slider; 48 dp targets; the app bar title keeps its room.
  testWidgets('golden: the auto-scroll bar, paused, light theme, phone', (
    tester,
  ) async {
    final c = await pumpApp(
      tester,
      size: phone,
      preferences: <String, Object>{
        SettingsRepository.readingModeKey: 'continuous',
      },
    );
    c.read(appRouterProvider).go(AppRoutes.mushafAyah(AyahRef.parse('2:1')));
    await tester.pumpAndSettle();
    c.read(autoscrollControllerProvider.notifier)
      ..start()
      ..pause();
    await tester.pumpAndSettle();
    expect(find.byKey(autoscrollBarKey), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../goldens/autoscroll/reader_bar_light.png'),
    );
  });

  group('state machine', () {
    late ProviderContainer container;

    setUp(() async {
      final overrides = await appTestOverrides(
        preferences: <String, Object>{
          SettingsRepository.readingModeKey: 'continuous',
        },
      );
      container = ProviderContainer.test(overrides: overrides);
    });

    AutoscrollController controller() =>
        container.read(autoscrollControllerProvider.notifier);
    AutoscrollStatus state() => container.read(autoscrollControllerProvider);

    test('off, running, paused and back, and off from any state', () {
      final states = <AutoscrollStatus>[];
      container.listen<AutoscrollStatus>(
        autoscrollControllerProvider,
        (_, next) => states.add(next),
      );
      controller()
        ..pause()
        ..resume()
        ..togglePause();
      expect(state(), AutoscrollStatus.off);

      controller().start();
      controller().start();
      controller().togglePause();
      controller().togglePause();
      controller().pause();
      controller().stop();
      controller().start();
      controller().reachedEnd();
      expect(states, <AutoscrollStatus>[
        AutoscrollStatus.running,
        AutoscrollStatus.paused,
        AutoscrollStatus.running,
        AutoscrollStatus.paused,
        AutoscrollStatus.off,
        AutoscrollStatus.running,
        AutoscrollStatus.off,
      ]);
    });

    test('a modal opening pauses; the last closing resumes', () {
      final modals = container.read(openModalCountProvider.notifier);
      controller().start();
      modals.opened();
      expect(state(), AutoscrollStatus.paused);
      modals.opened();
      modals.closed();
      expect(state(), AutoscrollStatus.paused);
      modals.closed();
      expect(state(), AutoscrollStatus.running);

      // Started under a sheet, it waits for the sheet.
      controller().stop();
      modals.opened();
      controller().start();
      expect(state(), AutoscrollStatus.paused);
      modals.closed();
      expect(state(), AutoscrollStatus.running);

      // Stopped under a sheet, it stays off.
      modals.opened();
      controller().stop();
      modals.closed();
      expect(state(), AutoscrollStatus.off);
    });
  });
}
