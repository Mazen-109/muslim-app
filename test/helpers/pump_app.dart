import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:muslim/app.dart';
import 'package:muslim/core/settings/settings_providers.dart';
import 'package:muslim/data/quran_database.dart';
import 'package:muslim/data/user_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'quran_database.dart';

/// The overrides every app test needs: mock preferences holding
/// [preferences] (keys as in `SettingsRepository`), the bundled content
/// database and an in-memory user database.
Future<List<Override>> appTestOverrides({
  Map<String, Object> preferences = const <String, Object>{},
}) async {
  SharedPreferences.setMockInitialValues(preferences);
  final sharedPreferences = await SharedPreferences.getInstance();
  return <Override>[
    sharedPreferencesProvider.overrideWithValue(sharedPreferences),
    quranDatabaseProvider.overrideWith((ref) async {
      final database = openBundledQuranDatabase();
      ref.onDispose(database.close);
      return database;
    }),
    userDatabaseProvider.overrideWith((ref) async {
      final database = UserDatabase.inMemory();
      ref.onDispose(database.close);
      return database;
    }),
  ];
}

/// Pumps [MuslimApp] (or [child]) under a [ProviderScope] with
/// [appTestOverrides] plus [overrides], at [size] logical pixels when given,
/// and settles. Returns the scope's container.
Future<ProviderContainer> pumpApp(
  WidgetTester tester, {
  Map<String, Object> preferences = const <String, Object>{},
  List<Override> overrides = const <Override>[],
  Size? size,
  double devicePixelRatio = 2,
  Widget child = const MuslimApp(),
}) async {
  if (size != null) {
    tester.view.physicalSize = size * devicePixelRatio;
    tester.view.devicePixelRatio = devicePixelRatio;
    addTearDown(tester.view.reset);
  }
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        ...await appTestOverrides(preferences: preferences),
        ...overrides,
      ],
      child: child,
    ),
  );
  await tester.pumpAndSettle();
  return tester.container();
}
