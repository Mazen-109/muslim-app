import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:muslim/core/routing/app_router.dart';
import 'package:muslim/core/settings/settings_repository.dart';

import '../../helpers/fonts.dart';
import '../../helpers/pump_app.dart';

// The Mushaf page, the index and the settings screen in each of the four
// themes (T020). The page's text comes from the bundled database; nothing
// here names or contains it. Checked by eye against DESIGN.md.

const Size phone = Size(400, 800);

/// Tall enough to show the whole settings screen in one image.
const Size tallPhone = Size(400, 1280);

void main() {
  setUpAll(loadAppFonts);

  final screens = <(String, String, Size)>[
    ('mushaf', AppRoutes.mushafPage(3), phone),
    ('index', AppRoutes.index, phone),
    ('settings', AppRoutes.settings, tallPhone),
  ];

  for (final preference in ThemePreference.values) {
    for (final (name, path, size) in screens) {
      testWidgets('$name in the ${preference.storageValue} theme', (
        tester,
      ) async {
        final container = await pumpApp(
          tester,
          size: size,
          preferences: <String, Object>{
            SettingsRepository.themeKey: preference.storageValue,
          },
        );
        container.read(appRouterProvider).go(path);
        await tester.pumpAndSettle();

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            '../../goldens/themes/${name}_${preference.storageValue}.png',
          ),
        );
      });
    }
  }
}
