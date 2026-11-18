import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Keeps the screen awake while enabled.
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

/// The screen wake lock. Tests override it with a fake.
final wakeLockProvider = Provider<WakeLock>(
  (ref) => const WakelockPlusWakeLock(),
);
