import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart' show ScrollPosition;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/routing/modal_observer.dart';
import '../../core/settings/settings_repository.dart';
import '../audio/playback_state.dart';
import '../audio/recitation_controller.dart';
import '../audio/wake_lock.dart';
import '../mushaf/reader_controller.dart';

/// The auto-scroll states of data-model.md section 6.
enum AutoscrollStatus {
  /// Auto-scroll is not on.
  off,

  /// The continuous view moves at `autoscroll_speed`.
  running,

  /// On but held still, by a tap or while a sheet or menu is open.
  paused,

  /// On while a recitation is playing: the view follows the recited ayah
  /// instead of the timer.
  followingAudio,
}

/// Auto-scroll's state and commands.
final autoscrollControllerProvider =
    NotifierProvider<AutoscrollController, AutoscrollStatus>(
      AutoscrollController.new,
    );

/// The auto-scroll state machine of data-model.md section 6:
///
/// - `off` to `running` with [start], in the continuous view only.
/// - `running` and `paused` switch with [pause], [resume] and
///   [togglePause] (a tap on the text), and `running` pauses while a sheet,
///   dialog or menu is open ([openModalCountProvider]); it resumes when the
///   last one closes, unless the reader paused or stopped it meanwhile.
/// - `running` to `followingAudio` while the recitation is `playing`, and
///   back to `running` when it is no longer playing. Resuming while a
///   recitation plays goes straight to `followingAudio`.
/// - Any state to `off` with [stop], when the view reaches the end of the
///   surah ([reachedEnd]), and when the reader leaves the continuous view.
///
/// A hold on the shared screen wake lock is taken exactly while the state
/// is `running` or `followingAudio`.
///
/// The scrolling itself is done by an [AutoscrollDriver] in the continuous
/// view, which runs while the state is `running`.
class AutoscrollController extends Notifier<AutoscrollStatus> {
  late WakeLockService _wakeLock;
  bool _wakeLockHeld = false;

  /// Whether the current pause came from a sheet or menu opening, so that
  /// closing it resumes.
  bool _pausedByModal = false;

  @override
  AutoscrollStatus build() {
    _wakeLock = ref.watch(wakeLockServiceProvider);
    ref.listen<bool>(
      recitationControllerProvider.select(
        (s) => s.status == PlaybackStatus.playing,
      ),
      (_, playing) => _onPlayback(playing: playing),
    );
    ref.listen<ReadingMode>(readerControllerProvider.select((s) => s.mode), (
      _,
      mode,
    ) {
      if (mode != ReadingMode.continuous) stop();
    });
    ref.listen<int>(openModalCountProvider, (previous, next) {
      if ((previous ?? 0) == 0 && next > 0) {
        _onModalOpened();
      } else if (next == 0) {
        _onModalsClosed();
      }
    });
    ref.onDispose(() {
      if (_wakeLockHeld) {
        _wakeLockHeld = false;
        _wakeLock.release();
      }
    });
    return AutoscrollStatus.off;
  }

  /// Whether auto-scroll is on in any form.
  bool get isOn => state != AutoscrollStatus.off;

  /// Turns auto-scroll on. Does nothing unless it is off and the reader is
  /// in the continuous view.
  void start() {
    if (state != AutoscrollStatus.off) return;
    if (ref.read(readerControllerProvider).mode != ReadingMode.continuous) {
      return;
    }
    if (ref.read(openModalCountProvider) > 0) {
      _pausedByModal = true;
      _set(AutoscrollStatus.paused);
    } else {
      _set(_active);
    }
  }

  /// Turns auto-scroll off from any state.
  void stop() {
    if (!ref.mounted) return;
    _pausedByModal = false;
    _set(AutoscrollStatus.off);
  }

  /// Pauses running auto-scroll; does nothing in another state.
  void pause() {
    if (state != AutoscrollStatus.running) return;
    _pausedByModal = false;
    _set(AutoscrollStatus.paused);
  }

  /// Resumes paused auto-scroll; does nothing in another state.
  void resume() {
    if (state != AutoscrollStatus.paused) return;
    _pausedByModal = false;
    _set(_active);
  }

  /// A tap on the text: pauses when running, resumes when paused.
  void togglePause() {
    switch (state) {
      case AutoscrollStatus.running:
        pause();
      case AutoscrollStatus.paused:
        resume();
      case AutoscrollStatus.off:
      case AutoscrollStatus.followingAudio:
        return;
    }
  }

  /// The view reached the end of the surah.
  void reachedEnd() => stop();

  /// The running state for the current playback.
  AutoscrollStatus get _active =>
      ref.read(recitationControllerProvider).status == PlaybackStatus.playing
      ? AutoscrollStatus.followingAudio
      : AutoscrollStatus.running;

  void _onPlayback({required bool playing}) {
    if (playing && state == AutoscrollStatus.running) {
      _set(AutoscrollStatus.followingAudio);
    } else if (!playing && state == AutoscrollStatus.followingAudio) {
      _set(AutoscrollStatus.running);
    }
  }

  void _onModalOpened() {
    if (state != AutoscrollStatus.running) return;
    _pausedByModal = true;
    _set(AutoscrollStatus.paused);
  }

  void _onModalsClosed() {
    if (!_pausedByModal || state != AutoscrollStatus.paused) return;
    _pausedByModal = false;
    _set(_active);
  }

  void _set(AutoscrollStatus next) {
    state = next;
    final wanted =
        next == AutoscrollStatus.running ||
        next == AutoscrollStatus.followingAudio;
    if (wanted == _wakeLockHeld) return;
    _wakeLockHeld = wanted;
    if (wanted) {
      _wakeLock.acquire();
    } else {
      _wakeLock.release();
    }
  }
}

/// Moves a scroll position forward at a speed in logical pixels per
/// second, one step per frame, and reports the end of the content.
///
/// The distance of each step is the speed times the time since the last
/// frame, so the distance covered matches the speed whatever the frame
/// rate, and a change of speed applies from the next frame.
class AutoscrollDriver {
  AutoscrollDriver({
    required TickerProvider vsync,
    required this.position,
    required this.speed,
    required this.onEnd,
    this.isSuspended,
    this.onMoved,
  }) {
    _ticker = vsync.createTicker(_tick);
  }

  /// The position to move, or null while there is none.
  final ScrollPosition? Function() position;

  /// The speed in logical pixels per second.
  final double Function() speed;

  /// Called once the position is at its end and cannot move further.
  final void Function() onEnd;

  /// Whether to skip moving on this frame, as while the reader drags.
  final bool Function()? isSuspended;

  /// Called after each step that moved the position.
  final void Function()? onMoved;

  late final Ticker _ticker;
  Duration _last = Duration.zero;

  /// Less than this from the end counts as the end.
  static const double _endTolerance = 0.5;

  bool get isRunning => _ticker.isActive;

  void start() {
    if (_ticker.isActive) return;
    _last = Duration.zero;
    _ticker.start();
  }

  void stop() => _ticker.stop();

  void dispose() => _ticker.dispose();

  void _tick(Duration elapsed) {
    final seconds =
        (elapsed - _last).inMicroseconds / Duration.microsecondsPerSecond;
    _last = elapsed;
    final position = this.position();
    if (position == null || !position.hasContentDimensions) return;
    if (isSuspended?.call() ?? false) return;
    final end = position.maxScrollExtent;
    if (position.pixels >= end - _endTolerance) {
      onEnd();
      return;
    }
    final rate = speed().clamp(
      SettingsRepository.minAutoscrollSpeed,
      SettingsRepository.maxAutoscrollSpeed,
    );
    position.jumpTo(math.min(position.pixels + rate * seconds, end));
    onMoved?.call();
  }
}
