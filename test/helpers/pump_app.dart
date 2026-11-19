import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:muslim/app.dart';
import 'package:muslim/core/settings/settings_providers.dart';
import 'package:muslim/data/quran_database.dart';
import 'package:muslim/data/user_database.dart';
import 'package:muslim/features/audio/audio_player_port.dart';
import 'package:muslim/features/audio/recitation_controller.dart';
import 'package:muslim/features/audio/wake_lock.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_audio.dart';
import 'quran_database.dart';

/// The overrides every app test needs: mock preferences holding
/// [preferences] (keys as in `SettingsRepository`), the bundled content
/// database, a user database ([openUserDatabase] when given, in memory
/// otherwise), and a silent audio player and wake lock ([audioPlayer] and
/// [wakeLock] when given, fresh fakes otherwise).
Future<List<Override>> appTestOverrides({
  Map<String, Object> preferences = const <String, Object>{},
  AudioPlayerPort? audioPlayer,
  WakeLock? wakeLock,
  UserDatabase Function()? openUserDatabase,
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
      final database = (openUserDatabase ?? UserDatabase.inMemory)();
      ref.onDispose(database.close);
      return database;
    }),
    audioPlayerPortProvider.overrideWithValue(audioPlayer ?? FakeAudioPlayer()),
    wakeLockProvider.overrideWithValue(wakeLock ?? FakeWakeLock()),
  ];
}

/// Pumps [MuslimApp] (or [child]) under a [ProviderScope] with
/// [appTestOverrides] (with [audioPlayer], [wakeLock] and
/// [openUserDatabase]) plus [overrides],
/// at [size] logical pixels when given, and settles. Returns the scope's container.
Future<ProviderContainer> pumpApp(
  WidgetTester tester, {
  Map<String, Object> preferences = const <String, Object>{},
  AudioPlayerPort? audioPlayer,
  WakeLock? wakeLock,
  UserDatabase Function()? openUserDatabase,
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
        ...await appTestOverrides(
          preferences: preferences,
          audioPlayer: audioPlayer,
          wakeLock: wakeLock,
          openUserDatabase: openUserDatabase,
        ),
        ...overrides,
      ],
      child: child,
    ),
  );
  await tester.pumpAndSettle();
  return tester.container();
}
