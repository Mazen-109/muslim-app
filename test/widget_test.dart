import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:muslim/app.dart';

void main() {
  testWidgets('app builds in Arabic, right to left', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MuslimApp()));
    await tester.pumpAndSettle();

    final titleFinder = find.text('مسلم');
    expect(titleFinder, findsOneWidget);
    expect(Directionality.of(tester.element(titleFinder)), TextDirection.rtl);
    expect(
      Localizations.localeOf(tester.element(titleFinder)),
      const Locale('ar'),
    );
  });
}
