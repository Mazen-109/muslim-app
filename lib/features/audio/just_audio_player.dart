import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

import 'audio_player_port.dart';

/// The [AudioPlayerPort] of the app, backed by `just_audio`.
///
/// The audio session is configured for speech before the first playlist is
/// loaded. `just_audio` handles interruptions (calls, other apps, unplugged
/// headphones) by pausing and resuming the player, which shows on
/// [stateStream].
class JustAudioPlayer implements AudioPlayerPort {
  JustAudioPlayer({AudioPlayer? player}) : _player = player ?? AudioPlayer() {
    _errorSubscription = _player.errorStream.listen(_errors.add);
  }

  final AudioPlayer _player;
  final StreamController<Object> _errors = StreamController<Object>.broadcast();
  late final StreamSubscription<PlayerException> _errorSubscription;
  bool _sessionConfigured = false;

  @override
  Stream<int?> get currentIndexStream => _player.currentIndexStream;

  @override
  Stream<AudioPlayerPortState> get stateStream => _player.playerStateStream.map(
    (s) => AudioPlayerPortState(
      playing: s.playing,
      processing: _processing(s.processingState),
    ),
  );

  @override
  Stream<Object> get errorStream => _errors.stream;

  static AudioProcessing _processing(ProcessingState state) => switch (state) {
    ProcessingState.idle => AudioProcessing.idle,
    ProcessingState.loading => AudioProcessing.loading,
    ProcessingState.buffering => AudioProcessing.buffering,
    ProcessingState.ready => AudioProcessing.ready,
    ProcessingState.completed => AudioProcessing.completed,
  };

  /// Configures the audio session for speech. A failure is not fatal:
  /// playback works with the default session, and the next playlist tries
  /// again.
  Future<void> _configureSession() async {
    if (_sessionConfigured) return;
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.speech());
      _sessionConfigured = true;
    } on Object {
      _sessionConfigured = false;
    }
  }

  @override
  Future<void> setPlaylist(List<Uri> uris, {int initialIndex = 0}) async {
    await _configureSession();
    await _player.setAudioSources(
      <AudioSource>[for (final uri in uris) AudioSource.uri(uri)],
      initialIndex: initialIndex,
      initialPosition: Duration.zero,
    );
  }

  @override
  Future<void> play() async {
    // just_audio completes play() only when playback pauses or ends.
    unawaited(_player.play().catchError(_errors.add));
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seekToIndex(int index) =>
      _player.seek(Duration.zero, index: index);

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> dispose() async {
    await _errorSubscription.cancel();
    await _player.dispose();
    await _errors.close();
  }
}
