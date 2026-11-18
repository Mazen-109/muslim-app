import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:muslim/core/l10n/generated/app_localizations.dart';

import 'helpers/pump_app.dart';

void main() {
  testWidgets('app builds in Arabic, right to left', (tester) async {
    await pumpApp(tester);

    final navigation = find.byType(AppBar);
    expect(navigation, findsOneWidget);
    final context = tester.element(navigation);
    expect(Localizations.localeOf(context), const Locale('ar'));
    expect(Directionality.of(context), TextDirection.rtl);
    expect(
      AppLocalizations.of(context).appTitle,
      lookupAppLocalizations(const Locale('ar')).appTitle,
    );
  });
}
