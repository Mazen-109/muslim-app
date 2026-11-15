import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muslim/core/settings/settings_providers.dart';
import 'package:muslim/core/settings/settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<(ProviderContainer, SharedPreferences)> _container([
  Map<String, Object> values = const <String, Object>{},
]) async {
  SharedPreferences.setMockInitialValues(values);
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer.test(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  return (container, prefs);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('providers start from defaults', () async {
    final (container, _) = await _container();

    expect(container.read(themeProvider), ThemePreference.light);
    expect(container.read(localeProvider), AppLocale.ar);
    expect(container.read(readingModeProvider), ReadingMode.pages);
    expect(container.read(fontScaleProvider), 1.0);
    expect(container.read(reciterIdProvider), 12);
    expect(container.read(repeatCountProvider), 3);
    expect(container.read(autoscrollSpeedProvider), 30.0);
    expect(container.read(videoGrayscaleProvider), isFalse);
    expect(container.read(lastAyahIdProvider), isNull);
  });

  test('providers start from stored values', () async {
    final (container, _) = await _container(<String, Object>{
      'theme': 'night',
      'locale': 'en',
      'last_ayah_id': 300,
    });

    expect(container.read(themeProvider), ThemePreference.night);
    expect(container.read(localeProvider), AppLocale.en);
    expect(container.read(lastAyahIdProvider), 300);
  });

  test('set updates listeners and persists every value', () async {
    final (container, prefs) = await _container();
    final seen = <ThemePreference>[];
    container.listen(themeProvider, (_, next) => seen.add(next));

    await container.read(themeProvider.notifier).set(ThemePreference.night);
    await container.read(localeProvider.notifier).set(AppLocale.en);
    await container
        .read(readingModeProvider.notifier)
        .set(ReadingMode.continuous);
    await container.read(fontScaleProvider.notifier).set(1.5);
    await container.read(reciterIdProvider.notifier).set(7);
    await container.read(repeatCountProvider.notifier).set(10);
    await container.read(autoscrollSpeedProvider.notifier).set(80);
    await container.read(videoGrayscaleProvider.notifier).set(true);
    await container.read(lastAyahIdProvider.notifier).set(2000);

    expect(seen, <ThemePreference>[ThemePreference.night]);
    expect(container.read(themeProvider), ThemePreference.night);
    expect(container.read(localeProvider), AppLocale.en);
    expect(container.read(readingModeProvider), ReadingMode.continuous);
    expect(container.read(fontScaleProvider), 1.5);
    expect(container.read(reciterIdProvider), 7);
    expect(container.read(repeatCountProvider), 10);
    expect(container.read(autoscrollSpeedProvider), 80.0);
    expect(container.read(videoGrayscaleProvider), isTrue);
    expect(container.read(lastAyahIdProvider), 2000);

    expect(prefs.getString('theme'), 'night');
    expect(prefs.getString('locale'), 'en');
    expect(prefs.getString('reading_mode'), 'continuous');
    expect(prefs.getDouble('font_scale'), 1.5);
    expect(prefs.getInt('reciter_id'), 7);
    expect(prefs.getInt('repeat_count'), 10);
    expect(prefs.getDouble('autoscroll_speed'), 80.0);
    expect(prefs.getBool('video_grayscale'), isTrue);
    expect(prefs.getInt('last_ayah_id'), 2000);

    // A fresh container over the same store reads the persisted values.
    final fresh = ProviderContainer.test(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    expect(fresh.read(themeProvider), ThemePreference.night);
    expect(fresh.read(lastAyahIdProvider), 2000);
  });

  test('state shows the clamped or snapped value that was stored', () async {
    final (container, prefs) = await _container();

    await container.read(fontScaleProvider.notifier).set(1.94);
    expect(container.read(fontScaleProvider), 1.9);
    expect(prefs.getDouble('font_scale'), 1.9);

    await container.read(repeatCountProvider.notifier).set(50);
    expect(container.read(repeatCountProvider), 20);

    await container.read(autoscrollSpeedProvider.notifier).set(1);
    expect(container.read(autoscrollSpeedProvider), 10.0);
  });

  test('clearing last ayah id removes it', () async {
    final (container, prefs) = await _container(<String, Object>{
      'last_ayah_id': 5,
    });

    await container.read(lastAyahIdProvider.notifier).set(null);
    expect(container.read(lastAyahIdProvider), isNull);
    expect(prefs.containsKey('last_ayah_id'), isFalse);
  });

  test('the repository provider can be overridden directly', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'repeat_count': 15,
    });
    final repository = SettingsRepository(
      await SharedPreferences.getInstance(),
    );
    final container = ProviderContainer.test(
      overrides: [settingsRepositoryProvider.overrideWithValue(repository)],
    );

    expect(container.read(repeatCountProvider), 15);
  });
}
