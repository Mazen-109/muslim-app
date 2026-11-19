import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/settings/settings_providers.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/tafsir.dart';
import '../../data/quran_repository.dart';
import '../../data/tafsir_repository.dart';
import '../mushaf/reader_controller.dart';

/// Opens the tafsir sheet (spec US2, FR-011) on ayah [ayahId] over the
/// reader.
///
/// While the sheet is open, the ayah it shows is highlighted in the reader
/// through [whileHighlighting]. The sheet never moves the reader: it does
/// not change the current ayah or the page, even when previous and next
/// reach an ayah on another page, so the reader finds the page exactly as it
/// was on dismissal. When the sheet closes, the highlight returns to what it
/// was before the sheet opened, unless something else (such as the audio
/// follower) has moved it meanwhile. A one-time link highlight counts as
/// already seen and is not restored.
///
/// Needs [quranRepositoryProvider] to have a value, as the reader does.
Future<void> showTafsirSheet(BuildContext context, int ayahId) =>
    whileHighlighting(
      ProviderScope.containerOf(context, listen: false),
      ayahId,
      (moveTo) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        useRootNavigator: true,
        builder: (context) =>
            TafsirSheet(initialAyahId: ayahId, onAyahChanged: moveTo),
      ),
    );

/// The tafsir work the sheet shows: the first in the content database. The
/// MVP bundles exactly one (research R6); a reader's choice of tafsir is not
/// in the MVP.
Tafsir? sheetTafsirOf(TafsirRepository repository) {
  final all = repository.tafsirs();
  return all.isEmpty ? null : all.first;
}

/// A draggable sheet with one ayah, its tafsir and the tafsir's attribution,
/// and buttons to the previous and next ayah across surah boundaries.
///
/// The ayah is the stored canonical text in the Quran font; the tafsir text,
/// its name and its author are shown exactly as stored. Interface text and
/// the tafsir follow the reader's font size setting, and the tafsir text is
/// selectable. Everything is read from the bundled database: the sheet makes
/// no network call.
class TafsirSheet extends ConsumerStatefulWidget {
  const TafsirSheet({
    super.key,
    required this.initialAyahId,
    this.onAyahChanged,
  });

  final int initialAyahId;

  /// Called with the new ayah id after previous or next.
  final ValueChanged<int>? onAyahChanged;

  /// Keys for tests and for the screen reader order.
  static const Key previousKey = ValueKey<String>('tafsir-previous');
  static const Key nextKey = ValueKey<String>('tafsir-next');
  static const Key ayahKey = ValueKey<String>('tafsir-ayah');
  static const Key textKey = ValueKey<String>('tafsir-text');
  static const Key sourceKey = ValueKey<String>('tafsir-source');
  static const Key rangeKey = ValueKey<String>('tafsir-range');

  @override
  ConsumerState<TafsirSheet> createState() => TafsirSheetState();
}

/// The state of [TafsirSheet]; [ayahId] is the ayah shown.
class TafsirSheetState extends ConsumerState<TafsirSheet> {
  late int ayahId = widget.initialAyahId;
  ScrollController? _scroll;

  void _go(int id) {
    setState(() => ayahId = id);
    widget.onAyahChanged?.call(id);
    final scroll = _scroll;
    if (scroll != null && scroll.hasClients) scroll.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final quran = ref.watch(quranRepositoryProvider).requireValue;
    final tafsirs = ref.watch(tafsirRepositoryProvider);
    final scale = ref.watch(fontScaleProvider);

    final ayah = quran.ayah(ayahId);
    final surah = quran.surah(ayah.surahId);
    final surahName = Localizations.localeOf(context).languageCode == 'ar'
        ? surah.nameAr
        : surah.nameEn;
    final hasPrevious = ayahId > 1;
    final hasNext = ayahId < quran.ayahTotal;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 1,
      snap: true,
      snapSizes: const <double>[0.6],
      builder: (context, scrollController) {
        _scroll = scrollController;
        return Column(
          children: <Widget>[
            _Header(
              title: l10n.tafsirSheetTitle(surahName, ayah.ayahNumber),
              scale: scale,
              onPrevious: hasPrevious ? () => _go(ayahId - 1) : null,
              onNext: hasNext ? () => _go(ayahId + 1) : null,
            ),
            const Divider(),
            Expanded(
              // The content is a handful of blocks, so it is built whole
              // rather than lazily.
              child: SingleChildScrollView(
                controller: scrollController,
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.gutter,
                  AppSpacing.xl,
                  AppSpacing.gutter,
                  AppSpacing.xxl + MediaQuery.paddingOf(context).bottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _AyahText(text: ayah.textQpcHafs, scale: scale),
                    const SizedBox(height: AppSpacing.xl),
                    ...tafsirs.when(
                      loading: () => const <Widget>[LoadingStateView()],
                      error: (_, _) => <Widget>[
                        ErrorStateView(message: l10n.tafsirMissing),
                      ],
                      data: (repository) => _tafsirBody(
                        context,
                        repository: repository,
                        quran: quran,
                        scale: scale,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _tafsirBody(
    BuildContext context, {
    required TafsirRepository repository,
    required QuranRepository quran,
    required double scale,
  }) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final secondary = theme.colorScheme.onSurfaceVariant;
    final tafsir = sheetTafsirOf(repository);
    final entry = tafsir == null ? null : repository.entry(tafsir.id, ayahId);
    if (tafsir == null || entry == null) {
      return <Widget>[ErrorStateView(message: l10n.tafsirMissing)];
    }
    final direction = tafsir.language == 'ar'
        ? TextDirection.rtl
        : TextDirection.ltr;
    final covers = entry.covers;
    TextStyle scaled(TextStyle style) =>
        style.copyWith(fontSize: style.fontSize! * scale);

    return <Widget>[
      Text(
        l10n.tafsirSource(tafsir.nameAr, tafsir.author),
        key: TafsirSheet.sourceKey,
        style: scaled(text.labelMedium!.copyWith(color: secondary)),
      ),
      if (!covers.isSingle) ...<Widget>[
        const SizedBox(height: AppSpacing.xs),
        Text(
          l10n.tafsirCoversRange(covers.from.key, covers.to.key),
          key: TafsirSheet.rangeKey,
          style: scaled(text.labelMedium!.copyWith(color: secondary)),
        ),
      ],
      const SizedBox(height: AppSpacing.md),
      Directionality(
        textDirection: direction,
        child: SelectableText(
          entry.text,
          key: TafsirSheet.textKey,
          style: scaled(text.bodyLarge!),
          textAlign: TextAlign.start,
        ),
      ),
    ];
  }
}

/// The ayah reference between the previous and next buttons. Previous sits
/// at the start (right in Arabic) and next at the end, so that next points
/// the way the Mushaf's pages turn.
class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.scale,
    required this.onPrevious,
    required this.onNext,
  });

  final String title;
  final double scale;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final style = Theme.of(context).textTheme.titleMedium!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      child: Row(
        children: <Widget>[
          IconButton(
            key: TafsirSheet.previousKey,
            tooltip: l10n.tafsirPreviousAyah,
            icon: const Icon(Icons.chevron_left),
            onPressed: onPrevious,
          ),
          Expanded(
            child: Semantics(
              header: true,
              liveRegion: true,
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: style.copyWith(fontSize: style.fontSize! * scale),
              ),
            ),
          ),
          IconButton(
            key: TafsirSheet.nextKey,
            tooltip: l10n.tafsirNextAyah,
            icon: const Icon(Icons.chevron_right),
            onPressed: onNext,
          ),
        ],
      ),
    );
  }
}

/// The ayah's stored text in the Quran font, at the continuous view's size
/// times the reader's font scale.
class _AyahText extends StatelessWidget {
  const _AyahText({required this.text, required this.scale});

  final String text;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Text(
        text,
        key: TafsirSheet.ayahKey,
        textAlign: TextAlign.justify,
        style: AppTheme.quranTextStyle(Theme.of(context))
            .copyWith(fontSize: AppTypography.quranFontSize * scale),
      ),
    );
  }
}
