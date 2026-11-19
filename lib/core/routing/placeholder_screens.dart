import 'package:material_ui/material_ui.dart';

import '../l10n/generated/app_localizations.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/state_views.dart';

// Stand-ins for the screens that later tasks build. Each one is a titled
// scaffold and a neutral "not ready yet" state. They hold no Quran text and
// no other religious content.
// A task that builds a screen replaces its placeholder in the router.

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.title});

  final String Function(AppLocalizations l10n) title;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppScaffold(
      title: title(l10n),
      body: EmptyStateView(
        icon: Icons.hourglass_empty,
        title: l10n.placeholderMessage,
      ),
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

/// `/settings/sources`.
class SourcesPlaceholder extends StatelessWidget {
  const SourcesPlaceholder({super.key});

  @override
  Widget build(BuildContext context) =>
      _Placeholder(title: (l10n) => l10n.screenSources);
}
