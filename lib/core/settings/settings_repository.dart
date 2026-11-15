import 'package:shared_preferences/shared_preferences.dart';

/// The app theme (data-model.md section 4, key `theme`).
enum ThemePreference {
  light('light'),
  night('night'),
  blackOnWhite('black_on_white'),
  whiteOnBlack('white_on_black');

  const ThemePreference(this.storageValue);

  /// The string stored in preferences. Stable: never rename.
  final String storageValue;
}

/// How the Mushaf is shown (key `reading_mode`).
enum ReadingMode {
  pages('pages'),
  continuous('continuous');

  const ReadingMode(this.storageValue);

  /// The string stored in preferences. Stable: never rename.
  final String storageValue;
}

/// The interface language (key `locale`).
enum AppLocale {
  ar('ar'),
  en('en');

  const AppLocale(this.storageValue);

  /// The string stored in preferences, which is also the language code.
  final String storageValue;
}

/// Typed access to every setting in data-model.md section 4.
///
/// Getters never throw: a stored value that is missing, of the wrong type, out
/// of range or unknown reads as the default. Setters clamp numbers into range
/// (and snap [fontScale] to its 0.1 step) before storing, so what is stored is
/// always what the getter returns.
class SettingsRepository {
  SettingsRepository(this._prefs);

  final SharedPreferences _prefs;

  static const String themeKey = 'theme';
  static const String readingModeKey = 'reading_mode';
  static const String fontScaleKey = 'font_scale';
  static const String lastAyahIdKey = 'last_ayah_id';
  static const String reciterIdKey = 'reciter_id';
  static const String repeatCountKey = 'repeat_count';
  static const String autoscrollSpeedKey = 'autoscroll_speed';
  static const String videoGrayscaleKey = 'video_grayscale';
  static const String localeKey = 'locale';

  static const ThemePreference defaultTheme = ThemePreference.light;
  static const ReadingMode defaultReadingMode = ReadingMode.pages;

  static const double minFontScale = 0.8;
  static const double maxFontScale = 2.0;
  static const double defaultFontScale = 1.0;

  static const int minAyahId = 1;
  static const int maxAyahId = 6236;

  /// Al-Husary (Mu'allim), `reciters.id` 12.
  static const int defaultReciterId = 12;

  static const int minRepeatCount = 2;
  static const int maxRepeatCount = 20;
  static const int defaultRepeatCount = 3;

  /// Logical pixels per second.
  static const double minAutoscrollSpeed = 10;
  static const double maxAutoscrollSpeed = 120;
  static const double defaultAutoscrollSpeed = 30;

  static const bool defaultVideoGrayscale = false;
  static const AppLocale defaultLocale = AppLocale.ar;

  // theme

  ThemePreference get theme =>
      _enumValue(themeKey, ThemePreference.values, (v) => v.storageValue) ??
      defaultTheme;

  Future<void> setTheme(ThemePreference value) =>
      _prefs.setString(themeKey, value.storageValue);

  // reading_mode

  ReadingMode get readingMode =>
      _enumValue(readingModeKey, ReadingMode.values, (v) => v.storageValue) ??
      defaultReadingMode;

  Future<void> setReadingMode(ReadingMode value) =>
      _prefs.setString(readingModeKey, value.storageValue);

  // font_scale

  double get fontScale {
    final stored = _double(fontScaleKey);
    if (stored == null || stored < minFontScale || stored > maxFontScale) {
      return defaultFontScale;
    }
    return snapFontScale(stored);
  }

  Future<void> setFontScale(double value) =>
      _prefs.setDouble(fontScaleKey, snapFontScale(value));

  /// Clamps [value] into 0.8 to 2.0 and rounds it to the nearest 0.1.
  static double snapFontScale(double value) {
    if (value.isNaN) return defaultFontScale;
    final clamped = value.clamp(minFontScale, maxFontScale);
    return (clamped * 10).round() / 10;
  }

  // last_ayah_id

  /// The last ayah read, or null before the first read.
  int? get lastAyahId {
    final stored = _prefs.get(lastAyahIdKey);
    if (stored is int && stored >= minAyahId && stored <= maxAyahId) {
      return stored;
    }
    return null;
  }

  /// Stores the last ayah read; null clears it. Throws [RangeError] outside
  /// 1 to 6236, since a clamped ayah id would point at the wrong ayah.
  Future<void> setLastAyahId(int? value) {
    if (value == null) return _prefs.remove(lastAyahIdKey);
    RangeError.checkValueInInterval(value, minAyahId, maxAyahId, 'value');
    return _prefs.setInt(lastAyahIdKey, value);
  }

  // reciter_id

  /// A `reciters.id`. Only positivity is checked here; whether the reciter
  /// exists is the reciter repository's concern.
  int get reciterId {
    final stored = _prefs.get(reciterIdKey);
    return stored is int && stored > 0 ? stored : defaultReciterId;
  }

  /// Throws [RangeError] for an id below 1.
  Future<void> setReciterId(int value) {
    if (value < 1) throw RangeError.range(value, 1, null, 'value');
    return _prefs.setInt(reciterIdKey, value);
  }

  // repeat_count

  int get repeatCount {
    final stored = _prefs.get(repeatCountKey);
    if (stored is int && stored >= minRepeatCount && stored <= maxRepeatCount) {
      return stored;
    }
    return defaultRepeatCount;
  }

  Future<void> setRepeatCount(int value) => _prefs.setInt(
    repeatCountKey,
    value.clamp(minRepeatCount, maxRepeatCount),
  );

  // autoscroll_speed

  double get autoscrollSpeed {
    final stored = _double(autoscrollSpeedKey);
    if (stored == null ||
        stored < minAutoscrollSpeed ||
        stored > maxAutoscrollSpeed) {
      return defaultAutoscrollSpeed;
    }
    return stored;
  }

  Future<void> setAutoscrollSpeed(double value) => _prefs.setDouble(
    autoscrollSpeedKey,
    value.isNaN
        ? defaultAutoscrollSpeed
        : value.clamp(minAutoscrollSpeed, maxAutoscrollSpeed),
  );

  // video_grayscale

  bool get videoGrayscale {
    final stored = _prefs.get(videoGrayscaleKey);
    return stored is bool ? stored : defaultVideoGrayscale;
  }

  Future<void> setVideoGrayscale(bool value) =>
      _prefs.setBool(videoGrayscaleKey, value);

  // locale

  AppLocale get locale =>
      _enumValue(localeKey, AppLocale.values, (v) => v.storageValue) ??
      defaultLocale;

  Future<void> setLocale(AppLocale value) =>
      _prefs.setString(localeKey, value.storageValue);

  // helpers

  /// A stored double. A whole number stored as an int is accepted, since
  /// some platform stores do not keep the distinction; NaN is rejected.
  double? _double(String key) {
    final stored = _prefs.get(key);
    if (stored is double) return stored.isNaN ? null : stored;
    if (stored is int) return stored.toDouble();
    return null;
  }

  T? _enumValue<T>(String key, List<T> values, String Function(T) stored) {
    final raw = _prefs.get(key);
    if (raw is! String) return null;
    for (final value in values) {
      if (stored(value) == raw) return value;
    }
    return null;
  }
}
