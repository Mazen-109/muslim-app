import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Keeps the screen awake while enabled: the platform switch.
abstract interface class WakeLock {
  Future<void> enable();
  Future<void> disable();
}

/// The [WakeLock] of the app, backed by `wakelock_plus`.
class WakelockPlusWakeLock implements WakeLock {
  const WakelockPlusWakeLock();

  @override
  Future<void> enable() => WakelockPlus.enable();

  @override
  Future<void> disable() => WakelockPlus.disable();
}

/// The platform wake lock. Tests override it with a fake.
final wakeLockProvider = Provider<WakeLock>(
  (ref) => const WakelockPlusWakeLock(),
);

/// The one screen wake lock of the app, shared by every feature that keeps
/// the screen awake (FR-016: the recitation and auto-scroll).
///
/// It counts holds: the platform lock is enabled when the first hold is
/// taken and disabled when the last is released, so one feature stopping
/// never lets the screen sleep while another still needs it. Each feature
/// takes at most one hold and releases it when it no longer needs the
/// screen awake.
class WakeLockService {
  WakeLockService(this._lock);

  final WakeLock _lock;
  int _holds = 0;
  bool _disposed = false;

  /// How many holds are taken.
  int get holds => _holds;

  /// Whether the screen is kept awake.
  bool get isHeld => _holds > 0;

  /// Takes a hold.
  void acquire() {
    _holds++;
    if (_holds == 1 && !_disposed) unawaited(_quietly(_lock.enable()));
  }

  /// Releases a hold taken with [acquire]. Throws [StateError] when no hold
  /// is taken.
  void release() {
    if (_holds == 0) {
      throw StateError('WakeLockService.release without a hold');
    }
    _holds--;
    if (_holds == 0 && !_disposed) unawaited(_quietly(_lock.disable()));
  }

  /// Lets the screen sleep, whatever holds are left.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    if (_holds > 0) unawaited(_quietly(_lock.disable()));
  }

  /// The platform call may fail (no plugin in a test, a platform error);
  /// keeping the screen awake is best effort.
  static Future<void> _quietly(Future<void> future) =>
      future.then<void>((_) {}, onError: (Object _) {});
}

/// The shared, reference-counted screen wake lock.
final wakeLockServiceProvider = Provider<WakeLockService>((ref) {
  final service = WakeLockService(ref.watch(wakeLockProvider));
  ref.onDispose(service.dispose);
  return service;
});
