import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/routing/app_router.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/ayah_ref.dart';
import '../../data/models/juz.dart';
import '../../data/models/surah.dart';
import '../../data/quran_database.dart';
import '../../data/quran_repository.dart';

/// The tabs of `/index` (routes.md), in order, with their `tab` values.
enum IndexTab {
  surahs('surahs'),
  juz('juz');

  const IndexTab(this.queryValue);

  /// The value of the route's `tab` parameter.
  final String queryValue;

  /// The tab named by [value], or [surahs] when it names none.
  static IndexTab fromQuery(String? value) =>
      values.firstWhere((tab) => tab.queryValue == value, orElse: () => surahs);
}

/// `/index`: the 114 surahs and the 30 juz, each row opening the Mushaf at
/// its first ayah.
///
/// Names come from the content database as stored and are set in the
/// interface font; the Uthmanic font is kept for Quran text.
class IndexScreen extends ConsumerStatefulWidget {
  const IndexScreen({super.key, this.initialTab = IndexTab.surahs});

  /// The tab shown first, from the route's `tab` parameter.
  final IndexTab initialTab;

  @override
  ConsumerState<IndexScreen> createState() => _IndexScreenState();
}

class _IndexScreenState extends ConsumerState<IndexScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
    length: IndexTab.values.length,
    initialIndex: widget.initialTab.index,
    vsync: this,
  );

  @override
  void didUpdateWidget(IndexScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A new `tab` parameter while the screen is shown selects that tab.
    if (widget.initialTab != oldWidget.initialTab) {
      _tabs.index = widget.initialTab.index;
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final repository = ref.watch(quranRepositoryProvider);

    return AppScaffold(
      title: l10n.screenIndex,
      bottom: TabBar(
        controller: _tabs,
        tabs: <Widget>[
          Tab(text: l10n.indexTabSurahs),
          Tab(text: l10n.indexTabJuz),
        ],
      ),
      body: switch (repository) {
        AsyncData(:final value) => TabBarView(
          controller: _tabs,
          children: <Widget>[
            _SurahList(repository: value),
            _JuzList(repository: value),
          ],
        ),
        AsyncError() => ErrorStateView(
          onRetry: () => ref.invalidate(quranDatabaseProvider),
        ),
        _ => const LoadingStateView(),
      },
    );
  }
}

void _openAt(BuildContext context, AyahRef ref) =>
    context.go(AppRoutes.mushafAyah(ref));

class _SurahList extends StatelessWidget {
  const _SurahList({required this.repository});

  final QuranRepository repository;

  @override
  Widget build(BuildContext context) {
    final surahs = repository.surahs();
    return ListView.separated(
      key: const PageStorageKey<IndexTab>(IndexTab.surahs),
      itemCount: surahs.length,
      separatorBuilder: (context, index) => const Divider(),
      itemBuilder: (context, index) {
        final surah = surahs[index];
        return SurahRow(
          key: ValueKey<String>('surah-${surah.id}'),
          surah: surah,
        );
      },
    );
  }
}

class _JuzList extends StatelessWidget {
  const _JuzList({required this.repository});

  final QuranRepository repository;

  @override
  Widget build(BuildContext context) {
    final juzs = repository.juzs();
    return ListView.separated(
      key: const PageStorageKey<IndexTab>(IndexTab.juz),
      itemCount: juzs.length,
      separatorBuilder: (context, index) => const Divider(),
      itemBuilder: (context, index) {
        final juz = juzs[index];
        final start = repository.refOf(juz.firstAyahId);
        return JuzRow(
          key: ValueKey<String>('juz-${juz.id}'),
          juz: juz,
          start: start,
          surah: repository.surah(start.surah),
        );
      },
    );
  }
}

/// One surah in the index: its number in the margin, its name, Makki or
/// Madani with the ayah count, and the page it starts on.
class SurahRow extends StatelessWidget {
  const SurahRow({super.key, required this.surah});

  final Surah surah;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final place = switch (surah.revelationPlace) {
      RevelationPlace.makkah => l10n.surahMakki,
      RevelationPlace.madinah => l10n.surahMadani,
    };
    return ListTile(
      leading: _Numeral(surah.id),
      title: Text(surah.nameAr),
      subtitle: Text(l10n.surahDetails(place, l10n.ayahCount(surah.ayahCount))),
      trailing: Text(l10n.pageNumber(surah.pageStart)),
      onTap: () => _openAt(context, AyahRef(surah.id, 1)),
    );
  }
}

/// One juz in the index: its number in the margin, its title, the surah and
/// ayah where it starts, and the page it starts on.
class JuzRow extends StatelessWidget {
  const JuzRow({
    super.key,
    required this.juz,
    required this.start,
    required this.surah,
  });

  final Juz juz;

  /// The juz's first ayah.
  final AyahRef start;

  /// The surah of [start].
  final Surah surah;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListTile(
      leading: _Numeral(juz.id),
      title: Text(l10n.juzTitle(juz.id)),
      subtitle: Text(l10n.juzStart(surah.nameAr, start.ayah)),
      trailing: Text(l10n.pageNumber(juz.pageStart)),
      onTap: () => _openAt(context, start),
    );
  }
}

/// A marginal numeral, like the numbers in the margin of a printed edition:
/// tabular figures, centred in a column wide enough for three digits so the
/// names line up down the list. The row's title already carries the number
/// for a juz, and the position carries it for a surah, so screen readers
/// skip it.
class _Numeral extends StatelessWidget {
  const _Numeral(this.number);

  final int number;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ExcludeSemantics(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: AppSpacing.xxl),
        child: Text(
          '$number',
          textAlign: TextAlign.center,
          style: theme.textTheme.labelLarge!.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}
