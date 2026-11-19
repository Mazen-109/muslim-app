import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:muslim/core/routing/app_router.dart';

import '../../helpers/fonts.dart';
import '../../helpers/pump_app.dart';

// Goldens of the page view at phone size in the light theme. They are
// checked by eye against DESIGN.md: justified lines, centred short lines,
// surah banners and basmala lines, nothing clipped. The text comes from the
// bundled database; nothing here names or contains it.

const Size phone = Size(400, 800);

void main() {
  setUpAll(loadAppFonts);

  for (final page in <int>[1, 2, 3, 604]) {
    testWidgets('page $page', (tester) async {
      final container = await pumpApp(tester, size: phone);
      container.read(appRouterProvider).go(AppRoutes.mushafPage(page));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../../goldens/mushaf/page_$page.png'),
      );
    });
  }
}
