import 'package:flutter/foundation.dart';

/// What the player is doing with its playlist, independent of whether it
/// has been asked to play (see [AudioPlayerPortState.playing]).
enum AudioProcessing {
  /// No playlist is loaded, or the player was stopped.
  idle,

  /// The playlist is being loaded.
  loading,

  /// The current item is buffering and cannot play yet.
  buffering,

  /// The current item can play.
  ready,

  /// The last item of the playlist has finished.
  completed,
}

/// One state of an [AudioPlayerPort].
@immutable
class AudioPlayerPortState {
  const AudioPlayerPortState({required this.playing, required this.processing});

  /// Whether the player plays as soon as [processing] is ready. It stays
  /// true when the playlist completes.
  final bool playing;
  final AudioProcessing processing;

  @override
  bool operator ==(Object other) =>
      other is AudioPlayerPortState &&
      other.playing == playing &&
      other.processing == processing;

  @override
  int get hashCode => Object.hash(playing, processing);

  @override
  String toString() =>
      'AudioPlayerPortState(playing: $playing, processing: $processing)';
}

/// A small interface over the audio player, so that the recitation
/// controller can be tested with a fake.
///
/// A playlist is a list of URIs played one after the other. Indexes are
/// positions in that list.
abstract interface class AudioPlayerPort {
  /// The index of the current item, or null when no playlist is loaded.
  Stream<int?> get currentIndexStream;

  /// The player state; emits on every change.
  Stream<AudioPlayerPortState> get stateStream;

  /// Load and playback failures, such as a network error. A failure of
  /// [setPlaylist] is also thrown by it.
  Stream<Object> get errorStream;

  /// Replaces the playlist with [uris] and loads the item at [initialIndex]
  /// from its start. Completes when that item is loaded; throws when it
  /// cannot be loaded. Does not start playback.
  Future<void> setPlaylist(List<Uri> uris, {int initialIndex = 0});

  /// Starts or resumes playback. Returns without waiting for playback to
  /// end; failures arrive on [errorStream].
  Future<void> play();

  /// Pauses playback at the current position.
  Future<void> pause();

  /// Moves to the start of the item at [index] of the playlist.
  Future<void> seekToIndex(int index);

  /// Stops playback and releases the loaded audio.
  Future<void> stop();

  /// Releases the player. It must not be used afterwards.
  Future<void> dispose();
}
