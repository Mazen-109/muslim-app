import 'package:flutter/foundation.dart';

import '../../data/models/ayah_ref.dart';

/// The playback states of data-model.md section 6.
enum PlaybackStatus {
  /// Nothing is playing and nothing is loaded.
  idle,

  /// Play was pressed and the audio of [PlaybackState.ayah] is loading.
  loading,

  /// [PlaybackState.ayah] is being recited (possibly while buffering).
  playing,

  /// Paused on [PlaybackState.ayah]; resume continues from there.
  paused,

  /// [PlaybackState.ayah] could not be loaded or played, typically for lack
  /// of a network; retry continues from that ayah.
  error,
}

/// What a recitation covers.
enum PlaybackMode {
  /// From the start ayah to the end of its surah.
  surah,

  /// Only one ayah, once.
  single,

  /// One ayah, [PlaybackState.repeatCount] times.
  repeat,
}

/// The state of the recitation (data-model.md section 5).
///
/// When [status] is [PlaybackStatus.idle] every other field is unset. In
/// every other status [ayah] and [reciterId] are set, and in
/// [PlaybackMode.repeat] so are [repeatCount] and [remainingRepeats].
@immutable
class PlaybackState {
  const PlaybackState({
    required this.status,
    this.ayah,
    this.reciterId,
    this.mode = PlaybackMode.surah,
    this.repeatCount,
    this.remainingRepeats,
  });

  /// No recitation.
  static const PlaybackState idle = PlaybackState(status: PlaybackStatus.idle);

  final PlaybackStatus status;

  /// The ayah being loaded, recited, paused on, or that failed.
  final AyahRef? ayah;

  /// The id of the reciter in use.
  final int? reciterId;

  final PlaybackMode mode;

  /// In repeat mode, how many times the ayah is recited in all (2 to 20).
  final int? repeatCount;

  /// In repeat mode, how many recitations of the ayah are left, counting the
  /// current one: [repeatCount] during the first, 1 during the last.
  final int? remainingRepeats;

  /// Whether a recitation is in progress (any status but idle).
  bool get isActive => status != PlaybackStatus.idle;

  PlaybackState copyWith({
    PlaybackStatus? status,
    AyahRef? ayah,
    int? reciterId,
    int? remainingRepeats,
  }) => PlaybackState(
    status: status ?? this.status,
    ayah: ayah ?? this.ayah,
    reciterId: reciterId ?? this.reciterId,
    mode: mode,
    repeatCount: repeatCount,
    remainingRepeats: remainingRepeats ?? this.remainingRepeats,
  );

  @override
  bool operator ==(Object other) =>
      other is PlaybackState &&
      other.status == status &&
      other.ayah == ayah &&
      other.reciterId == reciterId &&
      other.mode == mode &&
      other.repeatCount == repeatCount &&
      other.remainingRepeats == remainingRepeats;

  @override
  int get hashCode =>
      Object.hash(status, ayah, reciterId, mode, repeatCount, remainingRepeats);

  @override
  String toString() =>
      'PlaybackState(${status.name}, $ayah, reciter: $reciterId, '
      '${mode.name}, repeats: $remainingRepeats/$repeatCount)';
}
