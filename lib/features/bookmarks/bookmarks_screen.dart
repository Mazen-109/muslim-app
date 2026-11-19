import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/routing/app_router.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/state_views.dart';
import '../../data/bookmark_repository.dart';
import '../../data/models/ayah.dart';
import '../../data/quran_database.dart';
import '../../data/quran_repository.dart';
import '../../data/user_database.dart';

/// The key of the section of [AyahMarkKind] marks on the bookmarks screen.
class BookmarkSectionKey extends ValueKey<AyahMarkKind> {
  const BookmarkSectionKey(super.value);
}

/// The key of the empty state of a section of the bookmarks screen.
class BookmarkSectionEmptyKey extends ValueKey<(String, AyahMarkKind)> {
  const BookmarkSectionEmptyKey(AyahMarkKind kind) : super(('empty', kind));
}

/// The key of the row of ayah [ayahId] in a section of the bookmarks screen.
class BookmarkRowKey extends ValueKey<(AyahMarkKind, int)> {
  const BookmarkRowKey(AyahMarkKind kind, int ayahId) : super((kind, ayahId));
}

/// The key of the remove button of a row of the bookmarks screen.
class BookmarkRemoveKey extends ValueKey<(String, AyahMarkKind, int)> {
  const BookmarkRemoveKey(AyahMarkKind kind, int ayahId)
    : super(('remove', kind, ayahId));
}

/// `/bookmarks` (contracts/routes.md, spec US5): the reader's bookmarks and
/// memorised ayahs in two sections, each newest first.
///
/// A row shows the surah name in the interface language, the ayah number
/// and the page; tapping it opens the Mushaf on that ayah with a brief
/// highlight. A row is removed by swiping it away or with its remove
/// button, and a snackbar offers to undo; undo puts the mark back with its
/// original time, so it returns to its place. Each section has its own
/// empty state.
///
/// The screen shows no Quran text: rows name ayahs by surah and number.
class BookmarksScreen extends ConsumerStatefulWidget {
  const BookmarksScreen({super.key});

  @override
  ConsumerState<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends ConsumerState<BookmarksScreen> {
  /// Rows swiped away whose removal the list has not reported yet. A
  /// dismissed row must leave the tree at once, before the repository's
  /// change reaches the list.
  final Set<(AyahMarkKind, int)> _dismissed = <(AyahMarkKind, int)>{};

  void _remove(AyahMark mark, AyahMarkKind kind, {required bool swiped}) {
    final repository = ref.read(markRepositoryProvider(kind)).requireValue;
    final l10n = AppLocalizations.of(context);
    if (swiped) setState(() => _dismissed.add((kind, mark.ayahId)));
    repository.remove(mark.ayahId);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(switch (kind) {
            AyahMarkKind.bookmark => l10n.bookmarksBookmarkRemoved,
            AyahMarkKind.memorisation => l10n.bookmarksMemorisedRemoved,
          }),
          action: SnackBarAction(
            label: l10n.bookmarksUndo,
            onPressed: () {
              if (mounted) {
                setState(() => _dismissed.remove((kind, mark.ayahId)));
              }
              repository.restore(mark);
            },
          ),
        ),
      );
  }

  void _open(Ayah ayah) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    context.go(AppRoutes.mushafAyah(ayah.ref, highlight: true));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    for (final kind in AyahMarkKind.values) {
      ref.listen<AsyncValue<List<AyahMark>>>(ayahMarksProvider(kind), (
        previous,
        next,
      ) {
        final ids = <int>{
          for (final mark in next.value ?? const <AyahMark>[]) mark.ayahId,
        };
        _dismissed.removeWhere((d) => d.$1 == kind && !ids.contains(d.$2));
      });
    }
    final quran = ref.watch(quranRepositoryProvider);
    final bookmarks = ref.watch(ayahMarksProvider(AyahMarkKind.bookmark));
    final memorised = ref.watch(ayahMarksProvider(AyahMarkKind.memorisation));

    final Widget body;
    if (quran.hasError) {
      body = ErrorStateView(
        message: l10n.mushafDataErrorMessage,
        onRetry: () => ref.invalidate(quranDatabaseProvider),
      );
    } else if (bookmarks.hasError || memorised.hasError) {
      body = ErrorStateView(
        onRetry: () => ref.invalidate(userDatabaseProvider),
      );
    } else if (quran.value case final repository?
        when bookmarks.hasValue && memorised.hasValue) {
      List<AyahMark> shown(AyahMarkKind kind, List<AyahMark> marks) =>
          <AyahMark>[
            for (final mark in marks)
              if (!_dismissed.contains((kind, mark.ayahId))) mark,
          ];
      body = CustomScrollView(
        slivers: <Widget>[
          for (final (kind, marks) in <(AyahMarkKind, List<AyahMark>)>[
            (AyahMarkKind.bookmark, bookmarks.requireValue),
            (AyahMarkKind.memorisation, memorised.requireValue),
          ])
            ..._section(
              kind: kind,
              marks: shown(kind, marks),
              repository: repository,
            ),
          const SliverPadding(padding: EdgeInsets.only(bottom: AppSpacing.xl)),
        ],
      );
    } else {
      body = const LoadingStateView();
    }

    return AppScaffold(
      title: l10n.navBookmarks,
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSizes.readingMeasure),
          child: body,
        ),
      ),
    );
  }

  List<Widget> _section({
    required AyahMarkKind kind,
    required List<AyahMark> marks,
    required QuranRepository repository,
  }) {
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    return <Widget>[
      SliverToBoxAdapter(
        child: _SectionHead(
          key: BookmarkSectionKey(kind),
          kind: kind,
          count: marks.length,
          first: kind == AyahMarkKind.values.first,
        ),
      ),
      if (marks.isEmpty)
        SliverToBoxAdapter(
          child: _SectionEmpty(key: BookmarkSectionEmptyKey(kind), kind: kind),
        )
      else
        SliverList.separated(
          itemCount: marks.length,
          separatorBuilder: (context, index) => const Divider(),
          itemBuilder: (context, index) {
            final mark = marks[index];
            final ayah = repository.ayah(mark.ayahId);
            final surah = repository.surah(ayah.surahId);
            return _MarkRow(
              key: BookmarkRowKey(kind, ayah.id),
              kind: kind,
              ayah: ayah,
              surahName: arabic ? surah.nameAr : surah.nameEn,
              onOpen: () => _open(ayah),
              onRemove: ({required swiped}) =>
                  _remove(mark, kind, swiped: swiped),
            );
          },
        ),
    ];
  }
}

/// A section head: a hairline rule (except above the first), then the
/// section's title with its count, with more space above than below.
class _SectionHead extends StatelessWidget {
  const _SectionHead({
    super.key,
    required this.kind,
    required this.count,
    required this.first,
  });

  final AyahMarkKind kind;
  final int count;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final title = switch (kind) {
      AyahMarkKind.bookmark => l10n.bookmarksSectionBookmarks,
      AyahMarkKind.memorisation => l10n.bookmarksSectionMemorised,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (!first) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          const Divider(),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.xl,
            AppSpacing.gutter,
            AppSpacing.sm,
          ),
          child: Semantics(
            header: true,
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleSmall!.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                if (count > 0)
                  Text(
                    '$count',
                    style: theme.textTheme.labelMedium!.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontFeatures: const <FontFeature>[
                        FontFeature.tabularFigures(),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The empty state of one section: what the section holds and how to add
/// to it, quieter than a full-screen state because the other section sits
/// beside it.
class _SectionEmpty extends StatelessWidget {
  const _SectionEmpty({super.key, required this.kind});

  final AyahMarkKind kind;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (icon, title, message) = switch (kind) {
      AyahMarkKind.bookmark => (
        Icons.bookmark_border,
        l10n.bookmarksEmptyTitle,
        l10n.bookmarksEmptyMessage,
      ),
      AyahMarkKind.memorisation => (
        Icons.check_circle_outline,
        l10n.memorisedEmptyTitle,
        l10n.memorisedEmptyMessage,
      ),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.gutter,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ExcludeSemantics(
            child: Icon(
              icon,
              size: AppSizes.icon,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: theme.textTheme.bodyLarge),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  message,
                  style: theme.textTheme.bodyMedium!.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One marked ayah: the surah name, then the ayah number and page, with a
/// remove button at the end. It can also be swiped away.
class _MarkRow extends StatelessWidget {
  const _MarkRow({
    super.key,
    required this.kind,
    required this.ayah,
    required this.surahName,
    required this.onOpen,
    required this.onRemove,
  });

  final AyahMarkKind kind;
  final Ayah ayah;
  final String surahName;
  final VoidCallback onOpen;
  final void Function({required bool swiped}) onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final removeLabel = switch (kind) {
      AyahMarkKind.bookmark => l10n.bookmarksRemoveBookmark,
      AyahMarkKind.memorisation => l10n.bookmarksRemoveMemorised,
    };

    Widget swipeBackground(AlignmentDirectional alignment) => ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Align(
        alignment: alignment,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Icon(Icons.close, color: scheme.onSurfaceVariant),
        ),
      ),
    );

    return Dismissible(
      key: ValueKey<(AyahMarkKind, int)>((kind, ayah.id)),
      background: swipeBackground(AlignmentDirectional.centerStart),
      secondaryBackground: swipeBackground(AlignmentDirectional.centerEnd),
      onDismissed: (_) => onRemove(swiped: true),
      child: ListTile(
        minTileHeight: AppSizes.listRowMinHeight,
        contentPadding: const EdgeInsetsDirectional.only(
          start: AppSpacing.gutter,
          end: AppSpacing.xs,
        ),
        title: Text(surahName),
        subtitle: Text(l10n.bookmarksRowDetails(ayah.ayahNumber, ayah.page)),
        trailing: IconButton(
          key: BookmarkRemoveKey(kind, ayah.id),
          tooltip: removeLabel,
          color: scheme.onSurfaceVariant,
          icon: const Icon(Icons.close),
          onPressed: () => onRemove(swiped: false),
        ),
        onTap: onOpen,
      ),
    );
  }
}
