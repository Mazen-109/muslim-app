import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/models/ayah_ref.dart';
import '../../data/models/mushaf_page.dart';
import '../../data/quran_repository.dart';
import '../../features/mushaf/reader_controller.dart';
import '../../features/mushaf/reader_screen.dart';
import '../l10n/generated/app_localizations.dart';
import '../settings/settings_providers.dart';
import '../widgets/app_scaffold.dart';
import 'modal_observer.dart';
import 'placeholder_screens.dart';
import '../../features/index/index_screen.dart';

/// Paths and builders of the routes in `contracts/routes.md`.
abstract final class AppRoutes {
  static const String launch = '/';
  static const String index = '/index';
  static const String mushaf = '/mushaf';
  static const String search = '/search';
  static const String bookmarks = '/bookmarks';
  static const String stories = '/stories';
  static const String settings = '/settings';
  static const String sources = '/settings/sources';

  /// `/mushaf?ayah=S:A`, with `highlight=1` when [highlight] is set.
  static String mushafAyah(AyahRef ref, {bool highlight = false}) =>
      '$mushaf?ayah=${ref.key}${highlight ? '&highlight=1' : ''}';

  /// `/mushaf?page=N`.
  static String mushafPage(int page) => '$mushaf?page=$page';

  /// `/stories/surah/:surah`.
  static String surahStory(int surah) => '$stories/surah/$surah';

  /// `/stories/prophet/:storyId`.
  static String prophetStory(String storyId) =>
      '$stories/prophet/${Uri.encodeComponent(storyId)}';

  /// `/stories/prophet/:storyId/:episodeId`.
  static String episode(String storyId, String episodeId) =>
      '${prophetStory(storyId)}/${Uri.encodeComponent(episodeId)}';
}

/// A decimal number without sign, spaces or leading zeros.
final RegExp _plainNumber = RegExp(r'^[1-9][0-9]{0,3}$');

int? _parseNumber(String? value) =>
    value != null && _plainNumber.hasMatch(value) ? int.parse(value) : null;

/// Where `/` leads: the Mushaf at [lastAyahId] when it is set, otherwise the
/// index (routes.md). [repository] maps the ayah id to its key; when the
/// content database cannot be opened the index is the fallback, and the
/// screens behind it show the database error.
Future<String> launchLocation({
  required int? lastAyahId,
  required Future<QuranRepository> Function() repository,
}) async {
  if (lastAyahId == null) return AppRoutes.index;
  try {
    final repo = await repository();
    return AppRoutes.mushafAyah(repo.refOf(lastAyahId));
  } on Object {
    return AppRoutes.index;
  }
}

/// Whether [query] is a valid `/mushaf` query (routes.md): exactly one of
/// `ayah` (an `S:A` key of an existing ayah) and `page` (1 to 604), and
/// `highlight`, when present, equal to `1`. Other keys are ignored.
///
/// The ayah number is checked against the content database. When the
/// database cannot be opened, only the key's form is checked, so the reader
/// opens and shows its blocking database error instead of a redirect.
Future<bool> isValidMushafQuery(
  Map<String, String> query, {
  required Future<QuranRepository> Function() repository,
}) async {
  final ayah = query['ayah'];
  final page = query['page'];
  final highlight = query['highlight'];
  if ((ayah == null) == (page == null)) return false;
  if (highlight != null && highlight != '1') return false;

  if (page != null) {
    final number = _parseNumber(page);
    return number != null && number <= pageCount;
  }

  final ref = AyahRef.tryParse(ayah!);
  if (ref == null) return false;
  final QuranRepository repo;
  try {
    repo = await repository();
  } on Object {
    return true;
  }
  return ref.isValidFor(repo.ayahCounts);
}

/// The key of the [ScaffoldMessenger] above every screen, used to show
/// messages that come from routing rather than from a screen.
final scaffoldMessengerKeyProvider =
    Provider<GlobalKey<ScaffoldMessengerState>>(
      (ref) => GlobalKey<ScaffoldMessengerState>(),
    );

/// The app's router. It starts at `/`, which applies the launch rule.
final appRouterProvider = Provider<GoRouter>((ref) {
  Future<QuranRepository> repository() =>
      ref.read(quranRepositoryProvider.future);
  final messengerKey = ref.watch(scaffoldMessengerKeyProvider);

  void showInvalidLink() {
    WidgetsBinding.instance
      ..addPostFrameCallback((_) {
        final messenger = messengerKey.currentState;
        if (messenger == null || !messenger.mounted) return;
        messenger.showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(messenger.context).invalidLink),
          ),
        );
      })
      ..scheduleFrame();
  }

  final router = GoRouter(
    initialLocation: AppRoutes.launch,
    // Sheets, dialogs and menus on any navigator are counted
    // (modal_observer.dart). The shell's branch navigators report to the
    // router's observers too.
    observers: <NavigatorObserver>[
      ModalRouteObserver(
        onOpened: () => ref.read(openModalCountProvider.notifier).opened(),
        onClosed: () => ref.read(openModalCountProvider.notifier).closed(),
      ),
    ],
    routes: <RouteBase>[
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppNavigationShell(navigationShell: navigationShell),
        branches: <StatefulShellBranch>[
          // Mushaf. `/` comes first so that it is the branch's start: the
          // Mushaf destination always resumes through the launch rule.
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.launch,
                redirect: (context, state) => launchLocation(
                  lastAyahId: ref.read(lastAyahIdProvider),
                  repository: repository,
                ),
              ),
              GoRoute(
                path: AppRoutes.index,
                builder: (context, state) => IndexScreen(
                  initialTab: IndexTab.fromQuery(
                    state.uri.queryParameters['tab'],
                  ),
                ),
              ),
              GoRoute(
                path: AppRoutes.mushaf,
                redirect: (context, state) async {
                  final valid = await isValidMushafQuery(
                    state.uri.queryParameters,
                    repository: repository,
                  );
                  if (valid) return null;
                  showInvalidLink();
                  return AppRoutes.index;
                },
                builder: (context, state) => ReaderScreen(
                  target: ReaderTarget.fromQuery(state.uri.queryParameters),
                ),
              ),
              GoRoute(
                path: AppRoutes.search,
                builder: (context, state) => const SearchPlaceholder(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.stories,
                builder: (context, state) => const StoriesPlaceholder(),
                routes: <RouteBase>[
                  GoRoute(
                    path: 'surah/:surah',
                    redirect: (context, state) {
                      final surah = _parseNumber(state.pathParameters['surah']);
                      return surah == null || surah > surahCount
                          ? AppRoutes.stories
                          : null;
                    },
                    builder: (context, state) => const SurahStoryPlaceholder(),
                  ),
                  GoRoute(
                    path: 'prophet/:storyId',
                    builder: (context, state) => const EpisodesPlaceholder(),
                    routes: <RouteBase>[
                      GoRoute(
                        path: ':episodeId',
                        builder: (context, state) => const EpisodePlaceholder(),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.bookmarks,
                builder: (context, state) => const BookmarksPlaceholder(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.settings,
                builder: (context, state) => const SettingsPlaceholder(),
                routes: <RouteBase>[
                  GoRoute(
                    path: 'sources',
                    builder: (context, state) => const SourcesPlaceholder(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
