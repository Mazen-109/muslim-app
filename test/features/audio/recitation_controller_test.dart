import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muslim/core/settings/settings_providers.dart';
import 'package:muslim/data/models/ayah_ref.dart';
import 'package:muslim/data/quran_database.dart';
import 'package:muslim/data/quran_repository.dart';
import 'package:muslim/features/audio/audio_player_port.dart';
import 'package:muslim/features/audio/playback_state.dart';
import 'package:muslim/features/audio/recitation_controller.dart';
import 'package:muslim/features/audio/wake_lock.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A playlist handed to the fake player.
typedef Loaded = ({List<Uri> uris, int initialIndex});

/// An [AudioPlayerPort] that records commands and lets the test drive the
/// player's events. Streams are asynchronous, as with just_audio.
class FakePlayer implements AudioPlayerPort {
  final _index = StreamController<int?>.broadcast();
  final _state = StreamController<AudioPlayerPortState>.broadcast();
  final _errors = StreamController<Object>.broadcast();

  final List<Loaded> loads = <Loaded>[];
  final List<String> commands = <String>[];

  /// When set, [setPlaylist] throws it once.
  Object? failNextLoad;

  /// When set, [setPlaylist] waits for it before finishing.
  Completer<void>? loadGate;

  bool playing = false;
  AudioProcessing processing = AudioProcessing.idle;
  int? index;

  void _emitState() => _state.add(
    AudioPlayerPortState(playing: playing, processing: processing),
  );

  @override
  Stream<int?> get currentIndexStream => _index.stream;

  @override
  Stream<AudioPlayerPortState> get stateStream => _state.stream;

  @override
  Stream<Object> get errorStream => _errors.stream;

  @override
  Future<void> setPlaylist(List<Uri> uris, {int initialIndex = 0}) async {
    commands.add('setPlaylist');
    loads.add((uris: List<Uri>.of(uris), initialIndex: initialIndex));
    processing = AudioProcessing.loading;
    _emitState();
    final gate = loadGate;
    if (gate != null) await gate.future;
    final failure = failNextLoad;
    if (failure != null) {
      failNextLoad = null;
      processing = AudioProcessing.idle;
      _emitState();
      throw failure;
    }
    index = initialIndex;
    _index.add(index);
    processing = AudioProcessing.ready;
    _emitState();
  }

  @override
  Future<void> play() async {
    commands.add('play');
    playing = true;
    _emitState();
  }

  @override
  Future<void> pause() async {
    commands.add('pause');
    playing = false;
    _emitState();
  }

  @override
  Future<void> seekToIndex(int index) async {
    commands.add('seek:$index');
    this.index = index;
    _index.add(index);
  }

  @override
  Future<void> stop() async {
    commands.add('stop');
    playing = false;
    processing = AudioProcessing.idle;
    index = null;
    _emitState();
  }

  @override
  Future<void> dispose() async {
    await _index.close();
    await _state.close();
    await _errors.close();
  }

  // Events of a real player.

  /// The player moved on to the item at [i] by itself.
  void advanceTo(int i) {
    index = i;
    _index.add(i);
  }

  /// The last item finished.
  void complete() {
    processing = AudioProcessing.completed;
    _emitState();
  }

  /// A load or playback failure, such as a dropped network.
  void fail() {
    _errors.add(Exception('network'));
  }

  /// The system paused (true) or resumed (false) playback.
  void interrupt({required bool begins}) {
    playing = !begins;
    _emitState();
  }
}

/// A [WakeLock] that records whether it is held.
class FakeWakeLock implements WakeLock {
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

const String husaryMuallim =
    'https://everyayah.com/data/Husary_Muallim_128kbps/';
const String alafasy = 'https://verses.quran.com/Alafasy/mp3/';

String url(String prefix, int surah, int ayah) =>
    '$prefix${surah.toString().padLeft(3, '0')}'
    '${ayah.toString().padLeft(3, '0')}.mp3';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late QuranDatabase database;
  late List<int> ayahCounts;
  late FakePlayer player;
  late FakeWakeLock wakeLock;
  late ProviderContainer container;
  late List<PlaybackState> states;

  setUpAll(() {
    database = QuranDatabase.openFile(QuranDatabase.assetKey);
    ayahCounts = QuranRepository(database).ayahCounts;
  });

  tearDownAll(() => database.close());

  Future<void> settle() => pumpEventQueue();

  Future<void> setUpContainer([
    Map<String, Object> settings = const <String, Object>{},
  ]) async {
    SharedPreferences.setMockInitialValues(settings);
    final prefs = await SharedPreferences.getInstance();
    player = FakePlayer();
    wakeLock = FakeWakeLock();
    container = ProviderContainer.test(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        quranDatabaseProvider.overrideWith((ref) async => database),
        audioPlayerPortProvider.overrideWithValue(player),
        wakeLockProvider.overrideWithValue(wakeLock),
      ],
    );
    states = <PlaybackState>[];
    container.listen<PlaybackState>(
      recitationControllerProvider,
      (_, next) => states.add(next),
      fireImmediately: true,
    );
  }

  setUp(setUpContainer);

  RecitationController controller() =>
      container.read(recitationControllerProvider.notifier);
  PlaybackState state() => container.read(recitationControllerProvider);
  List<PlaybackStatus> statuses() => <PlaybackStatus>[
    for (final s in states) s.status,
  ];

  /// Clears the recorded history, keeping the current state.
  void mark() {
    states
      ..clear()
      ..add(state());
    player.commands.clear();
    wakeLock.calls.clear();
  }

  Future<void> playFrom(AyahRef ayah) async {
    await controller().playFrom(ayah);
    await settle();
  }

  group('play to the end of the surah', () {
    test('starts idle without the wake lock', () {
      expect(state(), PlaybackState.idle);
      expect(state().isActive, isFalse);
      expect(wakeLock.held, isFalse);
      expect(player.loads, isEmpty);
    });

    test('idle to loading to playing from the ayah with the reciter', () async {
      await playFrom(AyahRef(2, 255));

      expect(statuses(), <PlaybackStatus>[
        PlaybackStatus.idle,
        PlaybackStatus.loading,
        PlaybackStatus.playing,
      ]);
      expect(states[1].ayah, AyahRef(2, 255));
      expect(states[1].reciterId, 12);
      expect(
        state(),
        PlaybackState(
          status: PlaybackStatus.playing,
          ayah: AyahRef(2, 255),
          reciterId: 12,
        ),
      );
      final load = player.loads.single;
      expect(load.uris, hasLength(ayahCounts[1]));
      expect(load.uris.first.toString(), url(husaryMuallim, 2, 1));
      expect(load.uris.last.toString(), url(husaryMuallim, 2, ayahCounts[1]));
      expect(
        load.uris[load.initialIndex].toString(),
        url(husaryMuallim, 2, 255),
      );
      expect(player.commands, <String>['setPlaylist', 'play']);
      expect(wakeLock.held, isTrue);
    });

    test('stays loading until the first ayah is loaded', () async {
      player.loadGate = Completer<void>();
      unawaited(controller().playFrom(AyahRef(3, 1)));
      await settle();

      expect(state().status, PlaybackStatus.loading);
      expect(state().ayah, AyahRef(3, 1));
      expect(player.commands, <String>['setPlaylist']);
      expect(wakeLock.held, isFalse);

      player.loadGate!.complete();
      await settle();
      expect(state().status, PlaybackStatus.playing);
      expect(wakeLock.held, isTrue);
    });

    test('playing to playing as the recitation moves on', () async {
      await playFrom(AyahRef(2, 255));
      mark();

      player.advanceTo(255);
      await settle();
      player.advanceTo(256);
      await settle();

      expect(statuses(), <PlaybackStatus>[
        PlaybackStatus.playing,
        PlaybackStatus.playing,
        PlaybackStatus.playing,
      ]);
      expect(states[1].ayah, AyahRef(2, 256));
      expect(states[2].ayah, AyahRef(2, 257));
      expect(wakeLock.calls, isEmpty);
    });

    test('stops at the end of the surah', () async {
      final last = ayahCounts[0];
      await playFrom(AyahRef(1, last - 1));
      player.advanceTo(last - 1);
      await settle();
      expect(state().ayah, AyahRef(1, last));
      mark();

      player.complete();
      await settle();

      expect(state(), PlaybackState.idle);
      expect(player.commands, <String>['stop']);
      expect(wakeLock.held, isFalse);
      expect(wakeLock.calls, <bool>[false]);
    });

    test('rejects an ayah the surah does not have', () async {
      await expectLater(
        controller().playFrom(AyahRef(1, ayahCounts[0] + 1)),
        throwsRangeError,
      );
      expect(state(), PlaybackState.idle);
      expect(player.loads, isEmpty);
    });

    test('a new play replaces the current recitation', () async {
      await playFrom(AyahRef(2, 255));
      await playFrom(AyahRef(36, 1));

      expect(state().ayah, AyahRef(36, 1));
      expect(state().status, PlaybackStatus.playing);
      expect(player.loads, hasLength(2));
      expect(
        player.loads.last.uris[player.loads.last.initialIndex].toString(),
        url(husaryMuallim, 36, 1),
      );
      expect(wakeLock.held, isTrue);
    });
  });

  group('pause, resume and stop', () {
    test('playing and paused switch, holding the wake lock only while '
        'playing', () async {
      await playFrom(AyahRef(2, 255));
      mark();

      await controller().pause();
      await settle();
      expect(state().status, PlaybackStatus.paused);
      expect(state().ayah, AyahRef(2, 255));
      expect(wakeLock.held, isFalse);

      await controller().resume();
      await settle();
      expect(state().status, PlaybackStatus.playing);
      expect(state().ayah, AyahRef(2, 255));
      expect(wakeLock.held, isTrue);

      expect(statuses(), <PlaybackStatus>[
        PlaybackStatus.playing,
        PlaybackStatus.paused,
        PlaybackStatus.playing,
      ]);
      expect(player.commands, <String>['pause', 'play']);
      expect(wakeLock.calls, <bool>[false, true]);
    });

    test('pause and resume do nothing in other states', () async {
      await controller().pause();
      await controller().resume();
      expect(state(), PlaybackState.idle);

      await playFrom(AyahRef(2, 255));
      mark();
      await controller().resume();
      await settle();
      expect(state().status, PlaybackStatus.playing);
      expect(player.commands, isEmpty);
    });

    test('stop from playing goes to idle and releases the wake lock', () async {
      await playFrom(AyahRef(2, 255));
      mark();

      await controller().stop();
      await settle();

      expect(statuses(), <PlaybackStatus>[
        PlaybackStatus.playing,
        PlaybackStatus.idle,
      ]);
      expect(state(), PlaybackState.idle);
      expect(player.commands, <String>['stop']);
      expect(wakeLock.held, isFalse);
    });

    test('stop from paused goes to idle', () async {
      await playFrom(AyahRef(2, 255));
      await controller().pause();
      await controller().stop();
      await settle();
      expect(state(), PlaybackState.idle);
      expect(wakeLock.held, isFalse);
    });

    test('stop while loading abandons the load', () async {
      player.loadGate = Completer<void>();
      unawaited(controller().playFrom(AyahRef(2, 255)));
      await settle();
      expect(state().status, PlaybackStatus.loading);

      await controller().stop();
      player.loadGate!.complete();
      await settle();

      expect(state(), PlaybackState.idle);
      expect(player.commands, isNot(contains('play')));
      expect(wakeLock.held, isFalse);
      expect(wakeLock.calls, isEmpty);
    });

    test('stop does nothing when idle', () async {
      await controller().stop();
      expect(player.commands, isEmpty);
    });

    test('a system interruption pauses and its end resumes', () async {
      await playFrom(AyahRef(2, 255));
      mark();

      player.interrupt(begins: true);
      await settle();
      expect(state().status, PlaybackStatus.paused);
      expect(wakeLock.held, isFalse);

      player.interrupt(begins: false);
      await settle();
      expect(state().status, PlaybackStatus.playing);
      expect(wakeLock.held, isTrue);
      expect(player.commands, isEmpty);
    });

    test('disposing the controller releases the wake lock', () async {
      await playFrom(AyahRef(2, 255));
      expect(wakeLock.held, isTrue);

      container.dispose();
      await settle();

      expect(wakeLock.held, isFalse);
      expect(player.commands.last, 'stop');
    });
  });

  group('next and previous', () {
    test('move within the surah while playing', () async {
      await playFrom(AyahRef(2, 255));
      mark();

      await controller().next();
      await settle();
      expect(state().ayah, AyahRef(2, 256));
      expect(state().status, PlaybackStatus.playing);

      await controller().previous();
      await controller().previous();
      await settle();
      expect(state().ayah, AyahRef(2, 254));
      expect(state().status, PlaybackStatus.playing);

      expect(player.commands, <String>['seek:255', 'seek:254', 'seek:253']);
      expect(player.loads, hasLength(1));
      expect(wakeLock.calls, isEmpty);
    });

    test('move while paused and stay paused', () async {
      await playFrom(AyahRef(2, 255));
      await controller().pause();
      mark();

      await controller().next();
      await settle();
      expect(state().status, PlaybackStatus.paused);
      expect(state().ayah, AyahRef(2, 256));
      expect(player.commands, <String>['seek:255']);
      expect(wakeLock.held, isFalse);
    });

    test('do nothing at the bounds of the surah', () async {
      final last = ayahCounts[1];
      await playFrom(AyahRef(2, last));
      mark();
      await controller().next();
      await settle();
      expect(state().ayah, AyahRef(2, last));

      await playFrom(AyahRef(2, 1));
      mark();
      await controller().previous();
      await settle();
      expect(state().ayah, AyahRef(2, 1));
      expect(player.commands, isEmpty);
    });

    test('do nothing when idle or in error', () async {
      await controller().next();
      await controller().previous();
      expect(state(), PlaybackState.idle);

      player.failNextLoad = Exception('offline');
      await playFrom(AyahRef(2, 255));
      expect(state().status, PlaybackStatus.error);
      mark();
      await controller().next();
      expect(state().ayah, AyahRef(2, 255));
      expect(player.commands, isEmpty);
    });

    test('in single mode, move to the adjacent ayah alone', () async {
      await controller().playAyah(AyahRef(2, 255));
      await settle();
      mark();

      await controller().next();
      await settle();

      expect(statuses(), <PlaybackStatus>[
        PlaybackStatus.playing,
        PlaybackStatus.playing,
        PlaybackStatus.loading,
        PlaybackStatus.playing,
      ]);
      expect(state().ayah, AyahRef(2, 256));
      expect(state().mode, PlaybackMode.single);
      expect(player.loads.last.uris.map((u) => u.toString()), <String>[
        url(husaryMuallim, 2, 256),
      ]);
    });

    test('in single mode while paused, reload on resume', () async {
      await controller().playAyah(AyahRef(2, 255));
      await settle();
      await controller().pause();
      mark();

      await controller().previous();
      await settle();
      expect(state().status, PlaybackStatus.paused);
      expect(state().ayah, AyahRef(2, 254));
      expect(player.commands, isEmpty);

      await controller().resume();
      await settle();
      expect(state().status, PlaybackStatus.playing);
      expect(
        player.loads.last.uris.single.toString(),
        url(husaryMuallim, 2, 254),
      );
    });
  });

  group('single ayah and repeat', () {
    test('single mode recites one ayah, then goes idle', () async {
      await controller().playAyah(AyahRef(2, 255));
      await settle();

      expect(
        state(),
        PlaybackState(
          status: PlaybackStatus.playing,
          ayah: AyahRef(2, 255),
          reciterId: 12,
          mode: PlaybackMode.single,
        ),
      );
      final load = player.loads.single;
      expect(load.uris.map((u) => u.toString()), <String>[
        url(husaryMuallim, 2, 255),
      ]);
      expect(load.initialIndex, 0);

      player.complete();
      await settle();
      expect(state(), PlaybackState.idle);
      expect(wakeLock.held, isFalse);
    });

    test('repeat mode counts down the remaining recitations', () async {
      await controller().repeatAyah(AyahRef(2, 255), 3);
      await settle();

      expect(
        state(),
        PlaybackState(
          status: PlaybackStatus.playing,
          ayah: AyahRef(2, 255),
          reciterId: 12,
          mode: PlaybackMode.repeat,
          repeatCount: 3,
          remainingRepeats: 3,
        ),
      );
      final load = player.loads.single;
      expect(load.uris, hasLength(3));
      expect(load.uris.toSet().map((u) => u.toString()), <String>{
        url(husaryMuallim, 2, 255),
      });

      player.advanceTo(1);
      await settle();
      expect(state().remainingRepeats, 2);
      expect(state().status, PlaybackStatus.playing);

      player.advanceTo(2);
      await settle();
      expect(state().remainingRepeats, 1);
      expect(state().ayah, AyahRef(2, 255));

      player.complete();
      await settle();
      expect(state(), PlaybackState.idle);
      expect(wakeLock.held, isFalse);
    });

    test('repeat count must be 2 to 20', () async {
      expect(
        () => controller().repeatAyah(AyahRef(2, 255), 1),
        throwsRangeError,
      );
      expect(
        () => controller().repeatAyah(AyahRef(2, 255), 21),
        throwsRangeError,
      );
      expect(state(), PlaybackState.idle);

      await controller().repeatAyah(AyahRef(2, 255), 2);
      await settle();
      expect(player.loads.last.uris, hasLength(2));

      await controller().repeatAyah(AyahRef(2, 255), 20);
      await settle();
      expect(player.loads.last.uris, hasLength(20));
      expect(state().remainingRepeats, 20);
    });

    test('next in repeat mode restarts the count on the next ayah', () async {
      await controller().repeatAyah(AyahRef(2, 255), 4);
      await settle();
      player.advanceTo(2);
      await settle();
      expect(state().remainingRepeats, 2);

      await controller().next();
      await settle();

      expect(state().ayah, AyahRef(2, 256));
      expect(state().remainingRepeats, 4);
      expect(state().status, PlaybackStatus.playing);
      expect(player.loads.last.uris, hasLength(4));
      expect(
        player.loads.last.uris.first.toString(),
        url(husaryMuallim, 2, 256),
      );
    });
  });

  group('reciter change', () {
    Future<void> selectReciter(int id) async {
      await container.read(reciterIdProvider.notifier).set(id);
      await settle();
    }

    test('uses the selected reciter', () async {
      await setUpContainer(<String, Object>{'reciter_id': 7});
      await playFrom(AyahRef(2, 255));
      expect(state().reciterId, 7);
      final load = player.loads.single;
      expect(load.uris[load.initialIndex].toString(), url(alafasy, 2, 255));
    });

    test('an unknown reciter falls back to the first one', () async {
      await setUpContainer(<String, Object>{'reciter_id': 999});
      await playFrom(AyahRef(2, 255));
      expect(state().reciterId, 12);
      expect(state().status, PlaybackStatus.playing);
    });

    test('while playing continues from the current ayah', () async {
      await playFrom(AyahRef(2, 255));
      player.advanceTo(256);
      await settle();
      mark();

      await selectReciter(7);

      expect(statuses(), <PlaybackStatus>[
        PlaybackStatus.playing,
        PlaybackStatus.loading,
        PlaybackStatus.playing,
      ]);
      expect(
        state(),
        PlaybackState(
          status: PlaybackStatus.playing,
          ayah: AyahRef(2, 257),
          reciterId: 7,
        ),
      );
      final load = player.loads.last;
      expect(load.uris, hasLength(ayahCounts[1]));
      expect(load.uris[load.initialIndex].toString(), url(alafasy, 2, 257));
      expect(wakeLock.held, isTrue);
    });

    test('while paused applies on resume', () async {
      await playFrom(AyahRef(2, 255));
      await controller().pause();
      mark();

      await selectReciter(7);
      expect(state().status, PlaybackStatus.paused);
      expect(state().reciterId, 7);
      expect(player.commands, isEmpty);

      await controller().next();
      await settle();
      expect(state().ayah, AyahRef(2, 256));
      expect(player.commands, isEmpty);

      await controller().resume();
      await settle();
      expect(statuses().skip(statuses().length - 2), <PlaybackStatus>[
        PlaybackStatus.loading,
        PlaybackStatus.playing,
      ]);
      final load = player.loads.last;
      expect(load.uris[load.initialIndex].toString(), url(alafasy, 2, 256));
    });

    test('in repeat mode keeps the remaining count', () async {
      await controller().repeatAyah(AyahRef(2, 255), 5);
      await settle();
      player.advanceTo(2);
      await settle();
      expect(state().remainingRepeats, 3);

      await selectReciter(7);

      expect(state().status, PlaybackStatus.playing);
      expect(state().remainingRepeats, 3);
      expect(state().repeatCount, 5);
      expect(player.loads.last.uris.map((u) => u.toString()), <String>[
        for (var i = 0; i < 3; i++) url(alafasy, 2, 255),
      ]);

      player.advanceTo(1);
      await settle();
      expect(state().remainingRepeats, 2);
    });

    test('when idle changes nothing', () async {
      await selectReciter(7);
      expect(state(), PlaybackState.idle);
      expect(player.loads, isEmpty);
    });
  });

  group('error and retry', () {
    test('a load failure keeps the ayah, and retry resumes from it', () async {
      player.failNextLoad = Exception('offline');
      await playFrom(AyahRef(2, 255));

      expect(statuses(), <PlaybackStatus>[
        PlaybackStatus.idle,
        PlaybackStatus.loading,
        PlaybackStatus.error,
      ]);
      expect(state().ayah, AyahRef(2, 255));
      expect(state().reciterId, 12);
      expect(wakeLock.calls, isEmpty);
      mark();

      await controller().retry();
      await settle();

      expect(statuses(), <PlaybackStatus>[
        PlaybackStatus.error,
        PlaybackStatus.loading,
        PlaybackStatus.playing,
      ]);
      final load = player.loads.last;
      expect(
        load.uris[load.initialIndex].toString(),
        url(husaryMuallim, 2, 255),
      );
      expect(wakeLock.held, isTrue);
    });

    test('a failure during playback stops on the failed ayah', () async {
      await playFrom(AyahRef(2, 255));
      player.advanceTo(256);
      await settle();
      mark();

      player.fail();
      await settle();

      expect(statuses(), <PlaybackStatus>[
        PlaybackStatus.playing,
        PlaybackStatus.error,
      ]);
      expect(state().ayah, AyahRef(2, 257));
      expect(player.commands, <String>['stop']);
      expect(wakeLock.held, isFalse);

      await controller().retry();
      await settle();
      expect(state().status, PlaybackStatus.playing);
      expect(state().ayah, AyahRef(2, 257));
      final load = player.loads.last;
      expect(
        load.uris[load.initialIndex].toString(),
        url(husaryMuallim, 2, 257),
      );
      expect(wakeLock.held, isTrue);
    });

    test('a failure while paused goes to error', () async {
      await playFrom(AyahRef(2, 255));
      await controller().pause();
      player.fail();
      await settle();
      expect(state().status, PlaybackStatus.error);
      expect(state().ayah, AyahRef(2, 255));
    });

    test('retry in repeat mode keeps the remaining count', () async {
      await controller().repeatAyah(AyahRef(2, 255), 4);
      await settle();
      player.advanceTo(1);
      await settle();
      player.fail();
      await settle();
      expect(state().status, PlaybackStatus.error);
      expect(state().remainingRepeats, 3);

      await controller().retry();
      await settle();
      expect(state().status, PlaybackStatus.playing);
      expect(state().remainingRepeats, 3);
      expect(player.loads.last.uris, hasLength(3));
    });

    test('a reciter chosen after the failure is used by retry', () async {
      player.failNextLoad = Exception('offline');
      await playFrom(AyahRef(2, 255));
      await container.read(reciterIdProvider.notifier).set(7);
      await settle();
      expect(state().status, PlaybackStatus.error);
      expect(state().reciterId, 7);
      expect(player.loads, hasLength(1));

      await controller().retry();
      await settle();
      final load = player.loads.last;
      expect(load.uris[load.initialIndex].toString(), url(alafasy, 2, 255));
    });

    test('a failed retry returns to error', () async {
      player.failNextLoad = Exception('offline');
      await playFrom(AyahRef(2, 255));
      player.failNextLoad = Exception('still offline');
      mark();

      await controller().retry();
      await settle();
      expect(statuses(), <PlaybackStatus>[
        PlaybackStatus.error,
        PlaybackStatus.loading,
        PlaybackStatus.error,
      ]);
      expect(wakeLock.calls, isEmpty);
    });

    test('retry does nothing unless in error', () async {
      await controller().retry();
      expect(state(), PlaybackState.idle);
      await playFrom(AyahRef(2, 255));
      mark();
      await controller().retry();
      expect(player.commands, isEmpty);
    });

    test('stop from error goes to idle', () async {
      player.failNextLoad = Exception('offline');
      await playFrom(AyahRef(2, 255));
      await controller().stop();
      expect(state(), PlaybackState.idle);
    });
  });
}
