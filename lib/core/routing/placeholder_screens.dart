import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/generated/app_localizations.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/state_views.dart';
import 'app_router.dart';

// Stand-ins for the screens that later tasks build. Each one is a titled
// scaffold and a neutral "not ready yet" state, with the links the contract
// asks for (the Mushaf app bar reaches the index and search; settings reach
// the sources page). They hold no Quran text and no other religious content.
// A task that builds a screen replaces its placeholder in the router.

class _Placeholder extends StatelessWidget {
  const _Placeholder({
    required this.title,
    this.actions = const <Widget>[],
    this.links = const <Widget>[],
  });

  final String Function(AppLocalizations l10n) title;
  final List<Widget> actions;
  final List<Widget> links;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final notReady = EmptyStateView(
      icon: Icons.hourglass_empty,
      title: l10n.placeholderMessage,
    );
    return AppScaffold(
      title: title(l10n),
      actions: actions,
      body: links.isEmpty
          ? notReady
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                ...links,
                const Divider(),
                Expanded(child: notReady),
              ],
            ),
    );
  }
}

/// `/index`.
class IndexPlaceholder extends StatelessWidget {
  const IndexPlaceholder({super.key});

  @override
  Widget build(BuildContext context) =>
      _Placeholder(title: (l10n) => l10n.screenIndex);
}

/// `/mushaf`.
class MushafPlaceholder extends StatelessWidget {
  const MushafPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _Placeholder(
      title: (l10n) => l10n.navMushaf,
      actions: <Widget>[
        IconButton(
          tooltip: l10n.screenIndex,
          icon: const Icon(Icons.format_list_bulleted),
          onPressed: () => context.go(AppRoutes.index),
        ),
        IconButton(
          tooltip: l10n.screenSearch,
          icon: const Icon(Icons.search),
          onPressed: () => context.go(AppRoutes.search),
        ),
      ],
    );
  }
}

/// `/search`.
class SearchPlaceholder extends StatelessWidget {
  const SearchPlaceholder({super.key});

  @override
  Widget build(BuildContext context) =>
      _Placeholder(title: (l10n) => l10n.screenSearch);
}

/// `/bookmarks`.
class BookmarksPlaceholder extends StatelessWidget {
  const BookmarksPlaceholder({super.key});

  @override
  Widget build(BuildContext context) =>
      _Placeholder(title: (l10n) => l10n.navBookmarks);
}

/// `/stories`.
class StoriesPlaceholder extends StatelessWidget {
  const StoriesPlaceholder({super.key});

  @override
  Widget build(BuildContext context) =>
      _Placeholder(title: (l10n) => l10n.navStories);
}

/// `/stories/surah/:surah`.
class SurahStoryPlaceholder extends StatelessWidget {
  const SurahStoryPlaceholder({super.key});

  @override
  Widget build(BuildContext context) =>
      _Placeholder(title: (l10n) => l10n.screenSurahStory);
}

/// `/stories/prophet/:storyId`.
class EpisodesPlaceholder extends StatelessWidget {
  const EpisodesPlaceholder({super.key});

  @override
  Widget build(BuildContext context) =>
      _Placeholder(title: (l10n) => l10n.screenEpisodes);
}

/// `/stories/prophet/:storyId/:episodeId`.
class EpisodePlaceholder extends StatelessWidget {
  const EpisodePlaceholder({super.key});

  @override
  Widget build(BuildContext context) =>
      _Placeholder(title: (l10n) => l10n.screenEpisode);
}

/// `/settings`.
class SettingsPlaceholder extends StatelessWidget {
  const SettingsPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _Placeholder(
      title: (l10n) => l10n.navSettings,
      links: <Widget>[
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: Text(l10n.screenSources),
          onTap: () => context.go(AppRoutes.sources),
        ),
      ],
    );
  }
}

/// `/settings/sources`.
class SourcesPlaceholder extends StatelessWidget {
  const SourcesPlaceholder({super.key});

  @override
  Widget build(BuildContext context) =>
      _Placeholder(title: (l10n) => l10n.screenSources);
}
