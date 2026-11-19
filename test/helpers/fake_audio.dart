import 'dart:async';

import 'package:muslim/features/audio/audio_player_port.dart';
import 'package:muslim/features/audio/wake_lock.dart';

/// An [AudioPlayerPort] with no audio and no network: it records the
/// playlists it is given and lets a test drive the events of a real
/// player. App tests use it by default (see `appTestOverrides`), so that no
/// test reaches `just_audio`.
class FakeAudioPlayer implements AudioPlayerPort {
  final _index = StreamController<int?>.broadcast();
  final _state = StreamController<AudioPlayerPortState>.broadcast();
  final _errors = StreamController<Object>.broadcast();

  /// Every playlist loaded, in order.
  final List<({List<Uri> uris, int initialIndex})> loads =
      <({List<Uri> uris, int initialIndex})>[];

  /// Every command received, such as `play`, `pause` or `seek:3`.
  final List<String> commands = <String>[];

  /// When set, the next [setPlaylist] throws it, as when there is no
  /// network.
  Object? failNextLoad;

  bool _playing = false;
  AudioProcessing _processing = AudioProcessing.idle;

  void _emitState() => _state.add(
    AudioPlayerPortState(playing: _playing, processing: _processing),
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
    _processing = AudioProcessing.loading;
    _emitState();
    final failure = failNextLoad;
    if (failure != null) {
      failNextLoad = null;
      _processing = AudioProcessing.idle;
      _emitState();
      throw failure;
    }
    _index.add(initialIndex);
    _processing = AudioProcessing.ready;
    _emitState();
  }

  @override
  Future<void> play() async {
    commands.add('play');
    _playing = true;
    _emitState();
  }

  @override
  Future<void> pause() async {
    commands.add('pause');
    _playing = false;
    _emitState();
  }

  @override
  Future<void> seekToIndex(int index) async {
    commands.add('seek:$index');
    _index.add(index);
  }

  @override
  Future<void> stop() async {
    commands.add('stop');
    _playing = false;
    _processing = AudioProcessing.idle;
    _emitState();
  }

  @override
  Future<void> dispose() async {
    await _index.close();
    await _state.close();
    await _errors.close();
  }

  /// The player moved on to the playlist item at [index] by itself.
  void advanceTo(int index) => _index.add(index);

  /// A playback failure, such as a dropped network.
  void fail() => _errors.add(Exception('network'));
}

/// A [WakeLock] that records whether it is held.
class FakeWakeLock implements WakeLock {
  bool held = false;

  @override
  Future<void> enable() async => held = true;

  @override
  Future<void> disable() async => held = false;
}
