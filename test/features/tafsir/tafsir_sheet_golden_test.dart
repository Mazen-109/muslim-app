import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:muslim/core/routing/app_router.dart';
import 'package:muslim/data/models/ayah_ref.dart';
import 'package:muslim/data/models/mushaf_page.dart';
import 'package:muslim/data/quran_repository.dart';
import 'package:muslim/features/mushaf/page_view/page_line_widgets.dart';

import '../../helpers/fonts.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/quran_database.dart';

// A golden of the tafsir sheet over the page view at phone size in the
// light theme, on an ayah whose entry explains a group of ayahs (research
// R6), so the range line shows. It is checked by eye against DESIGN.md. The
// text comes from the bundled database; nothing here names or contains it.

const Size phone = Size(400, 800);

void main() {
  late QuranRepository quran;
  late void Function() close;

  setUpAll(() async {
    await loadAppFonts();
    (quran, close) = openBundledQuranRepository();
  });
  tearDownAll(() => close());

  testWidgets('tafsir sheet on a grouped entry', (tester) async {
    final id = quran.ayahIdOf(AyahRef.parse('4:66'));
    final page = quran.pageOf(id);
    final container = await pumpApp(tester, size: phone);
    container.read(appRouterProvider).go(AppRoutes.mushafPage(page));
    await tester.pumpAndSettle();

    final word = quran
        .page(page)
        .lines
        .whereType<AyahLine>()
        .expand((l) => l.words)
        .firstWhere((w) => w.ayahId == id);
    await tester.tap(find.byKey(MushafWordKey(word.id)));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../goldens/tafsir/sheet_grouped_light.png'),
    );
  });
}
