import 'dart:ui' show Tristate;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:muslim/core/l10n/generated/app_localizations.dart';
import 'package:muslim/core/routing/app_router.dart';
import 'package:muslim/core/settings/settings_providers.dart';
import 'package:muslim/core/settings/settings_repository.dart';
import 'package:muslim/core/theme/app_theme.dart';
import 'package:muslim/data/reciter_repository.dart';
import 'package:muslim/features/index/index_screen.dart';
import 'package:muslim/features/mushaf/continuous/text_size_sheet.dart';
import 'package:muslim/features/settings/reciter_setting.dart';
import 'package:muslim/features/settings/settings_screen.dart';
import 'package:muslim/features/settings/theme_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fonts.dart';
import '../../helpers/pump_app.dart';

// The settings screen (US7). Every assertion is on keys, provider state and
// stored preferences; nothing here contains Quran text or other religious
// content, and reciters are named only by id.

final AppLocalizations ar = lookupAppLocalizations(const Locale('ar'));
final AppLocalizations en = lookupAppLocalizations(const Locale('en'));

const Size phone = Size(400, 800);

Future<ProviderContainer> openSettings(
  WidgetTester tester, {
  Map<String, Object> preferences = const <String, Object>{},
}) async {
  final container = await pumpApp(
    tester,
    size: phone,
    preferences: preferences,
  );
  container.read(appRouterProvider).go(AppRoutes.settings);
  await tester.pumpAndSettle();
  return container;
}

Finder get settingsList => find
    .descendant(
      of: find.byType(SettingsScreen),
      matching: find.byType(Scrollable),
    )
    .first;

Future<void> scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 200, scrollable: settingsList);
  await tester.pumpAndSettle();
}

Future<SharedPreferences> prefs() => SharedPreferences.getInstance();

ThemeData themeAt(WidgetTester tester, Finder finder) =>
    Theme.of(tester.element(finder));

void main() {
  setUpAll(loadAppFonts);

  testWidgets('the settings route shows the settings screen', (tester) async {
    await openSettings(tester);

    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text(ar.navSettings),
      ),
      findsOneWidget,
    );
    for (final preference in ThemePreference.values) {
      expect(find.byKey(themeOptionKey(preference)), findsOneWidget);
    }
  });

  group('theme', () {
    testWidgets('picking a theme rebuilds the app theme and persists it', (
      tester,
    ) async {
      final container = await openSettings(tester);

      for (final preference in <ThemePreference>[
        ThemePreference.night,
        ThemePreference.blackOnWhite,
        ThemePreference.whiteOnBlack,
        ThemePreference.light,
      ]) {
        await tester.tap(find.byKey(themeOptionKey(preference)));
        await tester.pumpAndSettle();

        final reason = preference.storageValue;
        expect(container.read(themeProvider), preference, reason: reason);
        expect(
          (await prefs()).getString(SettingsRepository.themeKey),
          preference.storageValue,
          reason: reason,
        );
        final expected = AppTheme.of(preference).colorScheme;
        expect(
          themeAt(tester, find.byType(SettingsScreen)).colorScheme,
          expected,
          reason: reason,
        );
        expect(
          themeAt(tester, find.byType(NavigationBar)).colorScheme,
          expected,
          reason: reason,
        );
      }
    });

    testWidgets('the chosen theme reaches the other screens at once', (
      tester,
    ) async {
      final container = await openSettings(tester);

      await tester.tap(
        find.byKey(themeOptionKey(ThemePreference.whiteOnBlack)),
      );
      await tester.pumpAndSettle();

      final expected = AppTheme.whiteOnBlack.colorScheme;
      container.read(appRouterProvider).go(AppRoutes.index);
      await tester.pumpAndSettle();
      expect(themeAt(tester, find.byType(IndexScreen)).colorScheme, expected);

      container.read(appRouterProvider).go(AppRoutes.mushafPage(3));
      await tester.pumpAndSettle();
      expect(themeAt(tester, find.byType(AppBar)).colorScheme, expected);
    });

    testWidgets('the stored theme is selected on start', (tester) async {
      await openSettings(
        tester,
        preferences: <String, Object>{
          SettingsRepository.themeKey: ThemePreference.night.storageValue,
        },
      );

      for (final preference in ThemePreference.values) {
        final semantics = tester.getSemantics(
          find.byKey(themeOptionKey(preference)),
        );
        expect(
          semantics.flagsCollection.isSelected == Tristate.isTrue,
          preference == ThemePreference.night,
          reason: preference.storageValue,
        );
        expect(semantics.label, themeName(ar, preference));
      }
      expect(
        themeAt(tester, find.byType(SettingsScreen)).colorScheme,
        AppTheme.night.colorScheme,
      );
    });
  });

  group('interface language', () {
    testWidgets('switches the locale at once and persists it', (tester) async {
      final container = await openSettings(tester);

      await tester.tap(
        find.descendant(
          of: find.byKey(localeSettingKey),
          matching: find.text(en.languageEnglish),
        ),
      );
      await tester.pumpAndSettle();

      expect(container.read(localeProvider), AppLocale.en);
      expect(
        (await prefs()).getString(SettingsRepository.localeKey),
        AppLocale.en.storageValue,
      );
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text(en.navSettings),
        ),
        findsOneWidget,
      );
      expect(
        Directionality.of(tester.element(find.byType(SettingsScreen))),
        TextDirection.ltr,
      );

      await tester.tap(
        find.descendant(
          of: find.byKey(localeSettingKey),
          matching: find.text(en.languageArabic),
        ),
      );
      await tester.pumpAndSettle();

      expect(container.read(localeProvider), AppLocale.ar);
      expect(
        (await prefs()).getString(SettingsRepository.localeKey),
        AppLocale.ar.storageValue,
      );
      expect(
        Directionality.of(tester.element(find.byType(SettingsScreen))),
        TextDirection.rtl,
      );
    });
  });

  group('continuous view text size', () {
    testWidgets('steps the font scale and persists it', (tester) async {
      final container = await openSettings(tester);
      await scrollTo(tester, find.byKey(textSizeLargerKey));

      await tester.tap(find.byKey(textSizeLargerKey));
      await tester.pumpAndSettle();
      expect(container.read(fontScaleProvider), 1.1);
      expect((await prefs()).getDouble(SettingsRepository.fontScaleKey), 1.1);

      for (var i = 0; i < 2; i++) {
        await tester.tap(find.byKey(textSizeSmallerKey));
        await tester.pumpAndSettle();
      }
      expect(container.read(fontScaleProvider), 0.9);
      expect((await prefs()).getDouble(SettingsRepository.fontScaleKey), 0.9);
    });
  });

  group('default reciter', () {
    testWidgets('lists every reciter and stores the one picked', (
      tester,
    ) async {
      final container = await openSettings(tester);
      final repository = await container.read(reciterRepositoryProvider.future);
      final reciters = repository.reciters();
      final other = reciters.firstWhere(
        (r) => r.id != SettingsRepository.defaultReciterId,
      );

      await scrollTo(tester, find.byKey(reciterSettingKey));
      await tester.tap(find.byKey(reciterSettingKey));
      await tester.pumpAndSettle();

      for (final reciter in reciters) {
        final tile = tester.widget<ListTile>(
          find.byKey(reciterOptionKey(reciter.id)),
        );
        expect(
          tile.selected,
          reciter.id == SettingsRepository.defaultReciterId,
          reason: 'reciter ${reciter.id}',
        );
      }

      await tester.tap(find.byKey(reciterOptionKey(other.id)));
      await tester.pumpAndSettle();

      expect(find.byKey(reciterOptionKey(other.id)), findsNothing);
      expect(container.read(reciterIdProvider), other.id);
      expect((await prefs()).getInt(SettingsRepository.reciterIdKey), other.id);
    });

    testWidgets('the row names the stored reciter', (tester) async {
      final container = await openSettings(tester);
      final repository = await container.read(reciterRepositoryProvider.future);
      await scrollTo(tester, find.byKey(reciterSettingKey));

      for (final reciter in repository.reciters()) {
        await container.read(reciterIdProvider.notifier).set(reciter.id);
        await tester.pumpAndSettle();
        final row = tester.element(find.byKey(reciterSettingKey));
        final subtitle = tester
            .widget<ListTile>(find.byKey(reciterSettingKey))
            .subtitle;
        expect(
          (subtitle! as Text).data,
          reciterLabel(row, reciter),
          reason: 'reciter ${reciter.id}',
        );
      }
    });
  });

  group('black and white videos', () {
    testWidgets('is stored as video_grayscale', (tester) async {
      final container = await openSettings(tester);
      await scrollTo(tester, find.byKey(videoGrayscaleSettingKey));

      expect(container.read(videoGrayscaleProvider), isFalse);
      await tester.tap(find.byKey(videoGrayscaleSettingKey));
      await tester.pumpAndSettle();

      expect(container.read(videoGrayscaleProvider), isTrue);
      expect(
        (await prefs()).getBool(SettingsRepository.videoGrayscaleKey),
        isTrue,
      );

      await tester.tap(find.byKey(videoGrayscaleSettingKey));
      await tester.pumpAndSettle();
      expect(
        (await prefs()).getBool(SettingsRepository.videoGrayscaleKey),
        isFalse,
      );
    });

    testWidgets('shows the stored value', (tester) async {
      await openSettings(
        tester,
        preferences: <String, Object>{
          SettingsRepository.videoGrayscaleKey: true,
        },
      );
      await scrollTo(tester, find.byKey(videoGrayscaleSettingKey));

      expect(
        tester
            .widget<SwitchListTile>(find.byKey(videoGrayscaleSettingKey))
            .value,
        isTrue,
      );
    });
  });

  testWidgets('the sources row opens the sources page', (tester) async {
    final container = await openSettings(tester);
    await scrollTo(tester, find.byKey(sourcesSettingKey));

    await tester.tap(find.byKey(sourcesSettingKey));
    await tester.pumpAndSettle();

    expect(
      container
          .read(appRouterProvider)
          .routerDelegate
          .currentConfiguration
          .uri
          .path,
      AppRoutes.sources,
    );
  });

  testWidgets('every control has a 48 dp target and a label', (tester) async {
    final handle = tester.ensureSemantics();
    await openSettings(tester);

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });
}
