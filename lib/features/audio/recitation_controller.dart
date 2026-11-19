import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/settings/settings_providers.dart';
import '../../core/settings/settings_repository.dart';
import '../../data/models/ayah_ref.dart';
import '../../data/quran_repository.dart';
import '../../data/reciter_repository.dart';
import 'audio_player_port.dart';
import 'just_audio_player.dart';
import 'playback_state.dart';
import 'wake_lock.dart';

/// The audio player. Tests override it with a fake.
final audioPlayerPortProvider = Provider<AudioPlayerPort>((ref) {
  final player = JustAudioPlayer();
  ref.onDispose(() => unawaited(player.dispose()));
  return player;
});

/// The recitation: what is playing and the commands to control it.
final recitationControllerProvider =
    NotifierProvider<RecitationController, PlaybackState>(
      RecitationController.new,
    );

/// The playlist loaded in the player, to map its indexes back to ayahs.
class _Playlist {
  const _Playlist(this.mode, this.surah, this.firstAyah, this.repeats);

  final PlaybackMode mode;
  final int surah;

  /// The ayah of index 0 (in repeat and single mode, the only ayah).
  final int firstAyah;

  /// In repeat mode, the number of items (recitations left at load time).
  final int? repeats;

  AyahRef ayahAt(int index) => AyahRef(
    surah,
    mode == PlaybackMode.surah ? firstAyah + index : firstAyah,
  );

  int? remainingAt(int index) =>
      mode == PlaybackMode.repeat ? repeats! - index : null;

  int indexOf(AyahRef ayah) => ayah.ayah - firstAyah;
}

/// Plays per-ayah recitations and follows data-model.md section 6.
///
/// - `idle` to `loading` when play is pressed ([playFrom], [playAyah],
///   [repeatAyah]), then `playing` once the first ayah is loaded.
/// - `playing` to `playing` when the recitation moves to another ayah.
/// - `playing` and `paused` switch with [pause] and [resume], and when the
///   system interrupts playback (a call, unplugged headphones) and ends the
///   interruption.
/// - Any active status to `error` when audio fails to load or play; the
///   ayah is kept and [retry] goes back to `loading` from that ayah.
/// - Back to `idle` at the end of the surah, after the last repeat, after
///   the single ayah, and on [stop].
///
/// The reciter is the `reciter_id` setting. Changing it while a recitation
/// is active continues from the current ayah with the new reciter: at once
/// when playing or loading, on [resume] when paused, on [retry] after an
/// error.
///
/// A hold on the shared screen wake lock is taken exactly while the status
/// is `playing`.
class RecitationController extends Notifier<PlaybackState> {
  late AudioPlayerPort _player;
  late WakeLockService _wakeLock;

  /// Whether this controller holds the shared wake lock.
  bool _wakeLockHeld = false;

  /// Incremented whenever a pending load must be abandoned.
  int _generation = 0;

  /// The playlist in the player, or null when none is.
  _Playlist? _playlist;

  /// Whether the player's playlist no longer matches the state (the reciter
  /// or ayah changed while paused, or a failure) and must be reloaded
  /// before playing.
  bool _needsReload = false;

  /// The ayah count of the surah of the current recitation.
  int _surahLength = 0;

  /// The last state the player reported.
  bool _playerPlaying = false;
  AudioProcessing _playerProcessing = AudioProcessing.idle;

  @override
  PlaybackState build() {
    _player = ref.watch(audioPlayerPortProvider);
    _wakeLock = ref.watch(wakeLockServiceProvider);
    final subscriptions = <StreamSubscription<Object?>>[
      _player.currentIndexStream.listen(_onIndex),
      _player.stateStream.listen(_onPlayerState),
      _player.errorStream.listen(_onError),
    ];
    ref.listen<int>(reciterIdProvider, (_, id) => _onReciterChanged(id));
    ref.onDispose(() {
      _generation++;
      for (final subscription in subscriptions) {
        unawaited(subscription.cancel());
      }
      if (_wakeLockHeld) {
        _wakeLockHeld = false;
        _wakeLock.release();
      }
      unawaited(_quietly(_player.stop()));
    });
    return PlaybackState.idle;
  }

  // Commands

  /// Recites from [from] to the end of its surah. Throws [RangeError] when
  /// the surah has no such ayah.
  Future<void> playFrom(AyahRef from) => _begin(from, PlaybackMode.surah);

  /// Recites only [ayah], once. Throws [RangeError] when the surah has no
  /// such ayah.
  Future<void> playAyah(AyahRef ayah) => _begin(ayah, PlaybackMode.single);

  /// Recites [ayah] [count] times, 2 to 20. Throws [RangeError] for another
  /// count or when the surah has no such ayah.
  Future<void> repeatAyah(AyahRef ayah, int count) {
    RangeError.checkValueInInterval(
      count,
      SettingsRepository.minRepeatCount,
      SettingsRepository.maxRepeatCount,
      'count',
    );
    return _begin(ayah, PlaybackMode.repeat, count);
  }

  /// Pauses a playing recitation; does nothing otherwise.
  Future<void> pause() async {
    if (state.status != PlaybackStatus.playing) return;
    _emit(state.copyWith(status: PlaybackStatus.paused));
    await _guard(_player.pause);
  }

  /// Resumes a paused recitation; does nothing otherwise.
  Future<void> resume() async {
    if (state.status != PlaybackStatus.paused) return;
    if (_needsReload) {
      _emit(state.copyWith(status: PlaybackStatus.loading));
      await _load();
      return;
    }
    _emit(state.copyWith(status: PlaybackStatus.playing));
    await _guard(_player.play);
  }

  /// Ends the recitation from any status.
  Future<void> stop() async {
    if (!state.isActive) return;
    _end();
  }

  /// After an error, loads the failed ayah again and plays on from there;
  /// does nothing in another status.
  Future<void> retry() async {
    if (state.status != PlaybackStatus.error) return;
    _emit(state.copyWith(status: PlaybackStatus.loading));
    await _load();
  }

  /// Moves to the next ayah of the surah, in the current mode. Does nothing
  /// on the last ayah of the surah, or unless playing or paused.
  Future<void> next() => _step(1);

  /// Moves to the previous ayah of the surah, in the current mode. Does
  /// nothing on the first ayah of the surah, or unless playing or paused.
  Future<void> previous() => _step(-1);

  // Internals

  Future<void> _begin(AyahRef ayah, PlaybackMode mode, [int? count]) async {
    final generation = ++_generation;
    final quran = await ref.read(quranRepositoryProvider.future);
    if (!_isCurrent(generation)) return;
    quran.checkRef(ayah);
    _surahLength = quran.ayahCounts[ayah.surah - 1];
    _emit(
      PlaybackState(
        status: PlaybackStatus.loading,
        ayah: ayah,
        reciterId: ref.read(reciterIdProvider),
        mode: mode,
        repeatCount: count,
        remainingRepeats: count,
      ),
    );
    await _load();
  }

  /// Loads the playlist for the current state (from its ayah, with its
  /// reciter and remaining repeats) and plays it. The status must be
  /// `loading`.
  Future<void> _load() async {
    final generation = ++_generation;
    try {
      final reciters = await ref.read(reciterRepositoryProvider.future);
      if (!_isCurrent(generation)) return;
      final requested = state.reciterId!;
      final reciter = reciters.reciter(requested) ?? reciters.reciters().first;
      if (reciter.id != requested) {
        _emit(state.copyWith(reciterId: reciter.id));
      }
      final ayah = state.ayah!;
      final List<Uri> uris;
      final int initialIndex;
      final _Playlist playlist;
      switch (state.mode) {
        case PlaybackMode.surah:
          playlist = _Playlist(PlaybackMode.surah, ayah.surah, 1, null);
          uris = <Uri>[
            for (var a = 1; a <= _surahLength; a++)
              reciter.audioUrl(AyahRef(ayah.surah, a)),
          ];
          initialIndex = playlist.indexOf(ayah);
        case PlaybackMode.single:
          playlist = _Playlist(
            PlaybackMode.single,
            ayah.surah,
            ayah.ayah,
            null,
          );
          uris = <Uri>[reciter.audioUrl(ayah)];
          initialIndex = 0;
        case PlaybackMode.repeat:
          final repeats = state.remainingRepeats!;
          playlist = _Playlist(
            PlaybackMode.repeat,
            ayah.surah,
            ayah.ayah,
            repeats,
          );
          final uri = reciter.audioUrl(ayah);
          uris = List<Uri>.filled(repeats, uri);
          initialIndex = 0;
      }
      _playlist = playlist;
      _needsReload = false;
      await _player.setPlaylist(uris, initialIndex: initialIndex);
      if (!_isCurrent(generation)) return;
      _emit(state.copyWith(status: PlaybackStatus.playing));
      await _player.play();
    } on Object {
      if (_isCurrent(generation)) _fail();
    }
  }

  Future<void> _step(int delta) async {
    final current = state;
    if (current.status != PlaybackStatus.playing &&
        current.status != PlaybackStatus.paused) {
      return;
    }
    final number = current.ayah!.ayah + delta;
    if (number < 1 || number > _surahLength) return;
    final ayah = AyahRef(current.ayah!.surah, number);
    _emit(current.copyWith(ayah: ayah, remainingRepeats: current.repeatCount));
    final playlist = _playlist;
    if (current.mode == PlaybackMode.surah &&
        !_needsReload &&
        playlist != null) {
      await _guard(() => _player.seekToIndex(playlist.indexOf(ayah)));
      return;
    }
    if (current.status == PlaybackStatus.paused) {
      _needsReload = true;
      return;
    }
    _emit(state.copyWith(status: PlaybackStatus.loading));
    await _load();
  }

  void _onReciterChanged(int id) {
    switch (state.status) {
      case PlaybackStatus.idle:
        return;
      case PlaybackStatus.error:
        _emit(state.copyWith(reciterId: id));
      case PlaybackStatus.paused:
        _emit(state.copyWith(reciterId: id));
        _needsReload = true;
      case PlaybackStatus.loading:
      case PlaybackStatus.playing:
        _emit(state.copyWith(reciterId: id, status: PlaybackStatus.loading));
        unawaited(_load());
    }
  }

  void _onIndex(int? index) {
    final playlist = _playlist;
    if (index == null || playlist == null || _needsReload) return;
    if (state.status != PlaybackStatus.playing &&
        state.status != PlaybackStatus.paused) {
      return;
    }
    if (index < 0 || (playlist.repeats != null && index >= playlist.repeats!)) {
      return;
    }
    _emit(
      state.copyWith(
        ayah: playlist.ayahAt(index),
        remainingRepeats: playlist.remainingAt(index),
      ),
    );
  }

  void _onPlayerState(AudioPlayerPortState player) {
    final wasPlaying = _playerPlaying;
    final wasProcessing = _playerProcessing;
    _playerPlaying = player.playing;
    _playerProcessing = player.processing;
    final status = state.status;
    if (_needsReload ||
        (status != PlaybackStatus.playing && status != PlaybackStatus.paused)) {
      return;
    }
    if (player.processing == AudioProcessing.completed &&
        wasProcessing != AudioProcessing.completed) {
      _end();
    } else if (status == PlaybackStatus.playing &&
        wasPlaying &&
        !player.playing) {
      // The system paused playback, for example for a phone call.
      _emit(state.copyWith(status: PlaybackStatus.paused));
    } else if (status == PlaybackStatus.paused &&
        !wasPlaying &&
        player.playing) {
      // The interruption ended and the system resumed playback.
      _emit(state.copyWith(status: PlaybackStatus.playing));
    }
  }

  void _onError(Object error) {
    final status = state.status;
    if (status == PlaybackStatus.idle || status == PlaybackStatus.error) return;
    _fail();
  }

  /// Goes to `error`, keeping the ayah, and stops the player.
  void _fail() {
    _generation++;
    _needsReload = true;
    _emit(state.copyWith(status: PlaybackStatus.error));
    unawaited(_quietly(_player.stop()));
  }

  /// Goes to `idle` and stops the player.
  void _end() {
    _generation++;
    _playlist = null;
    _needsReload = false;
    _emit(PlaybackState.idle);
    unawaited(_quietly(_player.stop()));
  }

  /// Runs a player command; a failure moves to `error` unless the
  /// recitation has moved on meanwhile.
  Future<void> _guard(Future<void> Function() command) async {
    final generation = _generation;
    try {
      await command();
    } on Object {
      if (_isCurrent(generation) && state.isActive) _fail();
    }
  }

  bool _isCurrent(int generation) => ref.mounted && generation == _generation;

  void _emit(PlaybackState next) {
    if (next == state) return;
    state = next;
    final wanted = next.status == PlaybackStatus.playing;
    if (wanted == _wakeLockHeld) return;
    _wakeLockHeld = wanted;
    if (wanted) {
      _wakeLock.acquire();
    } else {
      _wakeLock.release();
    }
  }

  static Future<void> _quietly(Future<void> future) =>
      future.then<void>((_) {}, onError: (Object _) {});
}
