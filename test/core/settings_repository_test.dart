import 'package:flutter_test/flutter_test.dart';
import 'package:muslim/core/settings/settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SettingsRepository> _repository([
  Map<String, Object> values = const <String, Object>{},
]) async {
  SharedPreferences.setMockInitialValues(values);
  return SettingsRepository(await SharedPreferences.getInstance());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('defaults', () {
    test(
      'every setting has its data-model default when nothing is stored',
      () async {
        final settings = await _repository();

        expect(settings.theme, ThemePreference.light);
        expect(settings.readingMode, ReadingMode.pages);
        expect(settings.fontScale, 1.0);
        expect(settings.lastAyahId, isNull);
        expect(settings.reciterId, 12);
        expect(settings.repeatCount, 3);
        expect(settings.autoscrollSpeed, 30.0);
        expect(settings.videoGrayscale, isFalse);
        expect(settings.locale, AppLocale.ar);
      },
    );
  });

  group('enum storage values', () {
    test('match the strings in data-model.md', () {
      expect(ThemePreference.values.map((v) => v.storageValue), <String>[
        'light',
        'night',
        'black_on_white',
        'white_on_black',
      ]);
      expect(ReadingMode.values.map((v) => v.storageValue), <String>[
        'pages',
        'continuous',
      ]);
      expect(AppLocale.values.map((v) => v.storageValue), <String>['ar', 'en']);
    });
  });

  group('round trip', () {
    test(
      'every setter stores under its key and the getter reads it back',
      () async {
        final settings = await _repository();
        final prefs = await SharedPreferences.getInstance();

        for (final theme in ThemePreference.values) {
          await settings.setTheme(theme);
          expect(settings.theme, theme);
          expect(prefs.getString('theme'), theme.storageValue);
        }
        for (final mode in ReadingMode.values) {
          await settings.setReadingMode(mode);
          expect(settings.readingMode, mode);
          expect(prefs.getString('reading_mode'), mode.storageValue);
        }
        for (final locale in AppLocale.values) {
          await settings.setLocale(locale);
          expect(settings.locale, locale);
          expect(prefs.getString('locale'), locale.storageValue);
        }

        await settings.setFontScale(1.7);
        expect(settings.fontScale, 1.7);
        expect(prefs.getDouble('font_scale'), 1.7);

        await settings.setLastAyahId(255);
        expect(settings.lastAyahId, 255);
        expect(prefs.getInt('last_ayah_id'), 255);
        await settings.setLastAyahId(null);
        expect(settings.lastAyahId, isNull);
        expect(prefs.containsKey('last_ayah_id'), isFalse);

        await settings.setReciterId(4);
        expect(settings.reciterId, 4);
        expect(prefs.getInt('reciter_id'), 4);

        await settings.setRepeatCount(20);
        expect(settings.repeatCount, 20);
        expect(prefs.getInt('repeat_count'), 20);

        await settings.setAutoscrollSpeed(55.5);
        expect(settings.autoscrollSpeed, 55.5);
        expect(prefs.getDouble('autoscroll_speed'), 55.5);

        await settings.setVideoGrayscale(true);
        expect(settings.videoGrayscale, isTrue);
        expect(prefs.getBool('video_grayscale'), isTrue);
      },
    );

    test('values survive a new repository over the same store', () async {
      final first = await _repository();
      await first.setTheme(ThemePreference.whiteOnBlack);
      await first.setRepeatCount(9);
      await first.setLastAyahId(6236);

      final second = SettingsRepository(await SharedPreferences.getInstance());
      expect(second.theme, ThemePreference.whiteOnBlack);
      expect(second.repeatCount, 9);
      expect(second.lastAyahId, 6236);
    });
  });

  group('setters clamp into range', () {
    test('font_scale is clamped to 0.8..2.0 and snapped to 0.1', () async {
      final settings = await _repository();
      final cases = <double, double>{
        0.1: 0.8,
        0.8: 0.8,
        1.04: 1.0,
        1.06: 1.1,
        1.25: 1.3,
        2.0: 2.0,
        5.0: 2.0,
        double.nan: 1.0,
      };
      for (final MapEntry(key: input, value: expected) in cases.entries) {
        await settings.setFontScale(input);
        expect(settings.fontScale, expected, reason: 'input $input');
      }
    });

    test('font_scale steps are exact tenths', () {
      for (var i = 8; i <= 20; i++) {
        expect(SettingsRepository.snapFontScale(i / 10), i / 10);
        expect(SettingsRepository.snapFontScale(0.1 * i), i / 10);
      }
    });

    test('repeat_count is clamped to 2..20', () async {
      final settings = await _repository();
      await settings.setRepeatCount(1);
      expect(settings.repeatCount, 2);
      await settings.setRepeatCount(21);
      expect(settings.repeatCount, 20);
    });

    test('autoscroll_speed is clamped to 10..120', () async {
      final settings = await _repository();
      await settings.setAutoscrollSpeed(5);
      expect(settings.autoscrollSpeed, 10);
      await settings.setAutoscrollSpeed(500);
      expect(settings.autoscrollSpeed, 120);
      await settings.setAutoscrollSpeed(double.nan);
      expect(settings.autoscrollSpeed, 30);
    });

    test('last_ayah_id outside 1..6236 is rejected, not clamped', () async {
      final settings = await _repository();
      await settings.setLastAyahId(10);
      expect(() => settings.setLastAyahId(0), throwsRangeError);
      expect(() => settings.setLastAyahId(6237), throwsRangeError);
      expect(settings.lastAyahId, 10);
    });

    test('reciter_id below 1 is rejected', () async {
      final settings = await _repository();
      expect(() => settings.setReciterId(0), throwsRangeError);
      expect(settings.reciterId, 12);
    });
  });

  group('stored values out of range fall back to the default', () {
    final cases =
        <(String, Object, Object? Function(SettingsRepository), Object?)>[
          ('font_scale', 0.7, (s) => s.fontScale, 1.0),
          ('font_scale', 2.1, (s) => s.fontScale, 1.0),
          ('font_scale', double.nan, (s) => s.fontScale, 1.0),
          ('last_ayah_id', 0, (s) => s.lastAyahId, null),
          ('last_ayah_id', 6237, (s) => s.lastAyahId, null),
          ('reciter_id', 0, (s) => s.reciterId, 12),
          ('reciter_id', -3, (s) => s.reciterId, 12),
          ('repeat_count', 1, (s) => s.repeatCount, 3),
          ('repeat_count', 21, (s) => s.repeatCount, 3),
          ('autoscroll_speed', 9.9, (s) => s.autoscrollSpeed, 30.0),
          ('autoscroll_speed', 120.1, (s) => s.autoscrollSpeed, 30.0),
        ];

    for (final (key, stored, read, expected) in cases) {
      test('$key = $stored', () async {
        final settings = await _repository(<String, Object>{key: stored});
        expect(read(settings), expected);
      });
    }

    test('unknown enum strings fall back', () async {
      final settings = await _repository(<String, Object>{
        'theme': 'sepia',
        'reading_mode': 'scroll',
        'locale': 'fr',
      });
      expect(settings.theme, ThemePreference.light);
      expect(settings.readingMode, ReadingMode.pages);
      expect(settings.locale, AppLocale.ar);
    });

    test('enum names that are not storage values fall back', () async {
      final settings = await _repository(<String, Object>{
        'theme': 'blackOnWhite',
      });
      expect(settings.theme, ThemePreference.light);
    });

    test('in-range stored values are read, font_scale snapped', () async {
      final settings = await _repository(<String, Object>{
        'font_scale': 1.23,
        'last_ayah_id': 1,
        'repeat_count': 2,
        'autoscroll_speed': 120.0,
        'theme': 'black_on_white',
        'reading_mode': 'continuous',
        'locale': 'en',
      });
      expect(settings.fontScale, 1.2);
      expect(settings.lastAyahId, 1);
      expect(settings.repeatCount, 2);
      expect(settings.autoscrollSpeed, 120.0);
      expect(settings.theme, ThemePreference.blackOnWhite);
      expect(settings.readingMode, ReadingMode.continuous);
      expect(settings.locale, AppLocale.en);
    });
  });

  group('stored values of the wrong type fall back to the default', () {
    test('strings, bools and lists where numbers or strings belong', () async {
      final settings = await _repository(<String, Object>{
        'theme': 1,
        'reading_mode': true,
        'font_scale': '1.5',
        'last_ayah_id': '255',
        'reciter_id': 4.0,
        'repeat_count': 5.0,
        'autoscroll_speed': true,
        'video_grayscale': 'true',
        'locale': <String>['en'],
      });

      expect(settings.theme, ThemePreference.light);
      expect(settings.readingMode, ReadingMode.pages);
      expect(settings.fontScale, 1.0);
      expect(settings.lastAyahId, isNull);
      expect(settings.reciterId, 12);
      expect(settings.repeatCount, 3);
      expect(settings.autoscrollSpeed, 30.0);
      expect(settings.videoGrayscale, isFalse);
      expect(settings.locale, AppLocale.ar);
    });

    test(
      'a whole number stored as int is accepted for a double setting',
      () async {
        final settings = await _repository(<String, Object>{
          'font_scale': 2,
          'autoscroll_speed': 45,
        });
        expect(settings.fontScale, 2.0);
        expect(settings.autoscrollSpeed, 45.0);
      },
    );
  });
}
