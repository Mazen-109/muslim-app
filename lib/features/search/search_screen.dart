import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/routing/app_router.dart';
import '../../core/settings/settings_providers.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/ayah.dart';
import '../../data/quran_database.dart';
import '../../data/quran_repository.dart';
import '../mushaf/quran_font_check.dart';
import 'search_controller.dart';

/// `/search` (contracts/routes.md, spec US6): a search field, the number of
/// matching ayahs and the matches in Mushaf order, each opening the Mushaf
/// on its ayah with a brief highlight.
///
/// Results show the canonical ayah text in the Quran font only. Like the
/// reader, the screen shows an error instead of results when that font
/// fails its check, and never draws ayah text in another font.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, this.initialQuery});

  /// The route's `q` parameter: searched at once when given. Without it the
  /// screen shows the last query searched.
  final String? initialQuery;

  /// The search field.
  static const Key fieldKey = ValueKey<String>('search-field');

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final TextEditingController _text = TextEditingController(
    text: widget.initialQuery ?? ref.read(searchQueryProvider),
  );

  @override
  void initState() {
    super.initState();
    _applyInitialQuery();
  }

  @override
  void didUpdateWidget(SearchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialQuery != oldWidget.initialQuery) {
      final query = widget.initialQuery;
      if (query != null) _text.text = query;
      _applyInitialQuery();
    }
  }

  /// Searches the route's `q` right after this frame: providers cannot
  /// change while the tree builds.
  void _applyInitialQuery() {
    final query = widget.initialQuery;
    if (query == null || query == ref.read(searchQueryProvider)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(searchQueryProvider.notifier).submit(query);
    });
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _clear() {
    _text.clear();
    ref.read(searchQueryProvider.notifier).submit('');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final notifier = ref.read(searchQueryProvider.notifier);

    return AppScaffold(
      title: l10n.screenSearch,
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSizes.readingMeasure),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.gutter,
                  AppSpacing.sm,
                  AppSpacing.gutter,
                  AppSpacing.md,
                ),
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _text,
                  builder: (context, value, _) => TextField(
                    key: SearchScreen.fieldKey,
                    controller: _text,
                    autofocus: value.text.isEmpty,
                    // Queries are Arabic (FR-020), in either interface
                    // language.
                    textDirection: TextDirection.rtl,
                    textInputAction: TextInputAction.search,
                    autocorrect: false,
                    enableSuggestions: false,
                    onChanged: notifier.edit,
                    onSubmitted: notifier.submit,
                    decoration: InputDecoration(
                      hintText: l10n.searchFieldHint,
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: value.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: l10n.searchClear,
                              icon: const Icon(Icons.close),
                              onPressed: _clear,
                            ),
                    ),
                  ),
                ),
              ),
              const Expanded(child: _SearchBody()),
            ],
          ),
        ),
      ),
    );
  }
}

/// Everything under the field: the starting state, the results, the
/// no-results state, or loading and errors.
class _SearchBody extends ConsumerWidget {
  const _SearchBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final results = ref.watch(searchResultsProvider);

    switch (results) {
      case AsyncError():
        return ErrorStateView(
          message: l10n.mushafDataErrorMessage,
          onRetry: () => ref.invalidate(quranDatabaseProvider),
        );
      case AsyncData(value: null):
        return EmptyStateView(
          icon: Icons.search,
          title: l10n.searchStartTitle,
          message: l10n.searchStartMessage,
        );
      case AsyncData(:final AyahSearchResult value) when value.total == 0:
        return EmptyStateView(
          icon: Icons.search_off,
          title: l10n.searchNoResultsTitle,
          message: l10n.searchNoResultsMessage,
          announce: true,
        );
      case AsyncData(:final AyahSearchResult value):
        final font = ref.watch(quranFontCheckProvider);
        if (font.hasError) {
          return ErrorStateView(
            title: l10n.mushafFontErrorTitle,
            message: l10n.mushafFontErrorMessage,
          );
        }
        if (!font.hasValue) return const LoadingStateView();
        return _ResultList(
          result: value,
          repository: ref.watch(quranRepositoryProvider).requireValue,
        );
      default:
        return const LoadingStateView();
    }
  }
}

class _ResultList extends ConsumerWidget {
  const _ResultList({required this.result, required this.repository});

  final AyahSearchResult result;
  final QuranRepository repository;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scale = ref.watch(fontScaleProvider);
    final arabic = Localizations.localeOf(context).languageCode == 'ar';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.gutter,
            vertical: AppSpacing.sm,
          ),
          child: Semantics(
            liveRegion: true,
            child: Text(
              l10n.searchResultCount(result.total),
              key: SearchResultRow.countKey,
              style: theme.textTheme.labelMedium!.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        const Divider(),
        Expanded(
          child: ListView.separated(
            // A new query starts at the top.
            key: ValueKey<String>(result.foldedQuery),
            itemCount: result.total,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              final ayah = repository.ayah(result.ayahIds[index]);
              final surah = repository.surah(ayah.surahId);
              return SearchResultRow(
                key: SearchResultRow.keyOf(ayah.id),
                ayah: ayah,
                surahName: arabic ? surah.nameAr : surah.nameEn,
                fontScale: scale,
              );
            },
          ),
        ),
      ],
    );
  }
}

/// One search result: the surah name and ayah number, then the canonical
/// ayah text in the Quran font at the reader's text size. Tapping it opens
/// the Mushaf on that ayah and highlights it once.
class SearchResultRow extends StatelessWidget {
  const SearchResultRow({
    super.key,
    required this.ayah,
    required this.surahName,
    required this.fontScale,
  });

  final Ayah ayah;

  /// The surah's name in the interface language, from the database.
  final String surahName;

  /// The reader's text size setting, as for the continuous view.
  final double fontScale;

  /// The key of the row of ayah [ayahId].
  static Key keyOf(int ayahId) => ValueKey<String>('search-result-$ayahId');

  /// The key of the ayah text in the row of ayah [ayahId].
  static Key textKeyOf(int ayahId) =>
      ValueKey<String>('search-result-text-$ayahId');

  /// The key of the result count.
  static const Key countKey = ValueKey<String>('search-result-count');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final quran = AppTheme.quranTextStyle(theme);

    return InkWell(
      onTap: () => context.go(AppRoutes.mushafAyah(ayah.ref, highlight: true)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSizes.listRowMinHeight),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.gutter,
            vertical: AppSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                l10n.searchResultPlace(surahName, ayah.ayahNumber),
                style: theme.textTheme.labelMedium!.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                ayah.textQpcHafs,
                key: textKeyOf(ayah.id),
                textDirection: TextDirection.rtl,
                style: quran.copyWith(
                  fontSize: AppTypography.quranFontSize * fontScale,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
