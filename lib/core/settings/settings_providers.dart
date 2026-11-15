import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'settings_repository.dart';

/// The loaded preferences. `main` overrides this after
/// `SharedPreferences.getInstance()`; tests override it with mock values.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError(
    'sharedPreferencesProvider must be overridden with a loaded instance.',
  ),
);

/// The settings repository. Tests may override this directly.
final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(sharedPreferencesProvider)),
);

/// Holds one setting. [set] persists the value, then exposes what the
/// repository reads back, so a clamped or snapped value is what widgets see.
class SettingNotifier<T> extends Notifier<T> {
  SettingNotifier(this._read, this._write);

  final T Function(SettingsRepository repository) _read;
  final Future<void> Function(SettingsRepository repository, T value) _write;

  @override
  T build() => _read(ref.watch(settingsRepositoryProvider));

  Future<void> set(T value) async {
    final repository = ref.read(settingsRepositoryProvider);
    await _write(repository, value);
    state = _read(repository);
  }
}

NotifierProvider<SettingNotifier<T>, T> _settingProvider<T>(
  T Function(SettingsRepository repository) read,
  Future<void> Function(SettingsRepository repository, T value) write,
) => NotifierProvider<SettingNotifier<T>, T>(
  () => SettingNotifier<T>(read, write),
);

final themeProvider = _settingProvider<ThemePreference>(
  (r) => r.theme,
  (r, v) => r.setTheme(v),
);

final localeProvider = _settingProvider<AppLocale>(
  (r) => r.locale,
  (r, v) => r.setLocale(v),
);

final readingModeProvider = _settingProvider<ReadingMode>(
  (r) => r.readingMode,
  (r, v) => r.setReadingMode(v),
);

final fontScaleProvider = _settingProvider<double>(
  (r) => r.fontScale,
  (r, v) => r.setFontScale(v),
);

final reciterIdProvider = _settingProvider<int>(
  (r) => r.reciterId,
  (r, v) => r.setReciterId(v),
);

final repeatCountProvider = _settingProvider<int>(
  (r) => r.repeatCount,
  (r, v) => r.setRepeatCount(v),
);

final autoscrollSpeedProvider = _settingProvider<double>(
  (r) => r.autoscrollSpeed,
  (r, v) => r.setAutoscrollSpeed(v),
);

final videoGrayscaleProvider = _settingProvider<bool>(
  (r) => r.videoGrayscale,
  (r, v) => r.setVideoGrayscale(v),
);

/// The last ayah read; null before the first read. Setting null clears it.
final lastAyahIdProvider = _settingProvider<int?>(
  (r) => r.lastAyahId,
  (r, v) => r.setLastAyahId(v),
);
