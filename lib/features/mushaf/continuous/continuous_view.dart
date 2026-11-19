import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/settings/settings_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/ayah_ref.dart';
import '../../../data/models/surah.dart';
import '../../../data/models/word.dart';
import '../../../data/quran_repository.dart';
import '../../autoscroll/autoscroll_controller.dart';
import '../page_view/page_line_widgets.dart';
import '../reader_controller.dart';
import 'ayah_paragraph.dart';
import 'continuous_surah.dart';

/// The key of the continuous view's scrollable. Tests drag it.
const ValueKey<String> continuousScrollKey = ValueKey<String>(
  'continuous-scroll',
);

/// The key of the continuous view's surah header for surah [value].
class ContinuousHeaderKey extends ValueKey<int> {
  const ContinuousHeaderKey(super.value);
}

/// The key of the basmala above the first ayah of surah [value].
class ContinuousBasmalaKey extends ValueKey<int> {
  const ContinuousBasmalaKey(super.value);
}

/// The key of the button that opens the previous surah.
const ValueKey<String> continuousPreviousSurahKey = ValueKey<String>(
  'continuous-previous-surah',
);

/// The key of the button that opens the next surah.
const ValueKey<String> continuousNextSurahKey = ValueKey<String>(
  'continuous-next-surah',
);

/// The continuous view: one surah at a time as flowing, justified text,
/// under its header and basmala, built lazily paragraph by paragraph.
///
/// The view follows [readerControllerProvider] as the page view does. It
/// opens with the controller's current ayah at the top of the screen,
/// reports the ayah at the top as the reader scrolls, and moves to an ayah
/// the controller moves to (a link, go-to, the audio follower) when that
/// ayah is not already on screen. A change of `font_scale` keeps the
/// current ayah at the top.
///
/// It shows one surah: buttons at the start and the end open the previous
/// and the next surah, and auto-scroll (data-model.md section 6) stops at
/// the end of the surah.
///
/// While auto-scroll is `running` the view moves at `autoscroll_speed`,
/// except while the reader drags it. While auto-scroll is running or
/// paused, a tap on the text pauses or resumes it instead of reaching
/// [onAyahTap]. Leaving the view (another view, another screen or tab)
/// turns auto-scroll off.
class ContinuousView extends ConsumerStatefulWidget {
  const ContinuousView({super.key, this.onAyahTap, this.onAyahLongPress});

  final AyahCallback? onAyahTap;
  final AyahCallback? onAyahLongPress;

  @override
  ConsumerState<ContinuousView> createState() => _ContinuousViewState();
}

class _ContinuousViewState extends ConsumerState<ContinuousView>
    with SingleTickerProviderStateMixin {
  final GlobalKey _viewportKey = GlobalKey();

  /// The ayah the list was last anchored at, and its surah.
  late int _anchorAyahId;
  late int _surahId;

  /// Bumped on every re-anchor, so the list starts over at the new anchor.
  int _generation = 0;

  late ScrollController _scroll;

  /// The built paragraphs of the current generation, by paragraph index.
  final Map<int, GlobalKey<AyahParagraphState>> _paragraphKeys =
      <int, GlobalKey<AyahParagraphState>>{};

  /// The last ayah this view reported to the controller.
  int? _reported;

  bool _userScrolling = false;

  late final AutoscrollController _autoscroll;
  late final AutoscrollDriver _driver;

  QuranRepository get _repository =>
      ref.read(quranRepositoryProvider).requireValue;

  @override
  void initState() {
    super.initState();
    _scroll = ScrollController();
    _setAnchor(ref.read(readerControllerProvider).currentAyahId);
    _autoscroll = ref.read(autoscrollControllerProvider.notifier);
    _driver = AutoscrollDriver(
      vsync: this,
      position: () => _scroll.hasClients ? _scroll.position : null,
      speed: () => ref.read(autoscrollSpeedProvider),
      isSuspended: () => _userScrolling,
      onMoved: _report,
      onEnd: _autoscroll.reachedEnd,
    );
    _syncDriver(ref.read(autoscrollControllerProvider));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // An inactive tab keeps this view alive but off screen, with its
    // tickers muted: that is leaving the view, so auto-scroll stops.
    if (!TickerMode.valuesOf(context).enabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _autoscroll.stop());
    }
  }

  @override
  void dispose() {
    _driver.dispose();
    _scroll.dispose();
    // Providers cannot change while the tree is being finalised.
    Future<void>.microtask(_autoscroll.stop);
    super.dispose();
  }

  void _syncDriver(AutoscrollStatus status) {
    if (status == AutoscrollStatus.running) {
      _driver.start();
    } else {
      _driver.stop();
    }
  }

  void _togglePause() => _autoscroll.togglePause();

  void _setAnchor(int ayahId) {
    _anchorAyahId = ayahId;
    _surahId = _repository.refOf(ayahId).surah;
    _paragraphKeys.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) => _align());
  }

  /// Starts the list over with [ayahId] at the top.
  void _reanchor(int ayahId) {
    if (!mounted) return;
    final old = _scroll;
    setState(() {
      _generation++;
      _scroll = ScrollController();
      _setAnchor(ayahId);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
  }

  /// Scrolls the anchor ayah's first line to the top of the screen. The
  /// list already starts at the anchor's paragraph, so this only moves
  /// within it. The first ayah of a surah is shown under its header.
  void _align() {
    if (!mounted || !_scroll.hasClients) return;
    final data = ref.read(continuousSurahProvider(_surahId));
    if (_anchorAyahId == data.firstAyahId) return;
    final top = _topOf(_anchorAyahId);
    if (top == null || top.abs() < _tolerance) return;
    final position = _scroll.position;
    position.jumpTo(
      (position.pixels + top).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      ),
    );
  }

  /// Less than a pixel's difference counts as the same place.
  static const double _tolerance = 1;

  RenderBox? get _viewport {
    final object = _viewportKey.currentContext?.findRenderObject();
    return object is RenderBox && object.hasSize ? object : null;
  }

  /// The ayahs of the built paragraphs with the tops of their first lines,
  /// relative to the top of the viewport, in reading order.
  List<(int, double)> _builtAyahTops() {
    final viewport = _viewport;
    if (viewport == null) return const [];
    final entries = _paragraphKeys.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return <(int, double)>[
      for (final entry in entries)
        ...?entry.value.currentState?.ayahTops(viewport),
    ];
  }

  double? _topOf(int ayahId) {
    for (final (id, top) in _builtAyahTops()) {
      if (id == ayahId) return top;
    }
    return null;
  }

  /// The ayah at the top of the screen: the first one whose first line
  /// starts at or below the top edge and above the bottom edge, or, when
  /// one ayah fills the screen, the ayah that runs across the top edge.
  int? _topAyah() {
    final viewport = _viewport;
    if (viewport == null) return null;
    final height = viewport.size.height;
    int? across;
    for (final (id, top) in _builtAyahTops()) {
      if (top >= -_tolerance) {
        return top < height ? id : across ?? id;
      }
      across = id;
    }
    return across;
  }

  bool _reportScheduled = false;

  /// Reports the ayah at the top once the frame that the scroll caused has
  /// been laid out: a scroll notification arrives before the list moves.
  void _report() {
    if (_reportScheduled) return;
    _reportScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reportScheduled = false;
      if (!mounted) return;
      final id = _topAyah();
      if (id == null) return;
      _reported = id;
      ref.read(readerControllerProvider.notifier).setCurrentAyah(id);
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    if (notification is UserScrollNotification) {
      _userScrolling = notification.direction != ScrollDirection.idle;
      if (!_userScrolling) _report();
    } else if (notification is ScrollUpdateNotification && _userScrolling) {
      _report();
    }
    return false;
  }

  /// Follows a current ayah set from outside the view.
  void _follow(int ayahId) {
    if (ayahId == _reported) return;
    final viewport = _viewport;
    final top = _topOf(ayahId);
    if (viewport != null &&
        top != null &&
        top >= -_tolerance &&
        top + _lineHeight <= viewport.size.height) {
      return;
    }
    _reanchor(ayahId);
  }

  double get _lineHeight {
    final style = _quranStyle(Theme.of(context), ref.read(fontScaleProvider));
    return style.fontSize! * (style.height ?? 1);
  }

  static TextStyle _quranStyle(ThemeData theme, double scale) {
    final base = AppTheme.quranTextStyle(theme);
    return base.copyWith(fontSize: base.fontSize! * scale);
  }

  void _openSurah(int surahId) {
    ref
        .read(readerControllerProvider.notifier)
        .goToAyah(_repository.ayahIdOf(AyahRef(surahId, 1)));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(
      readerControllerProvider.select((s) => s.currentAyahId),
      (previous, next) => _follow(next),
    );
    ref.listen<AutoscrollStatus>(
      autoscrollControllerProvider,
      (previous, next) => _syncDriver(next),
    );
    ref.listen<double>(fontScaleProvider, (previous, next) {
      _reanchor(ref.read(readerControllerProvider).currentAyahId);
    });

    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final style = _quranStyle(theme, ref.watch(fontScaleProvider));
    final highlighted = ref.watch(
      readerControllerProvider.select((s) => s.highlightedAyahId),
    );
    final data = ref.watch(continuousSurahProvider(_surahId));
    final surah = data.surah;
    final autoscroll = ref.watch(autoscrollControllerProvider);
    final tapPauses =
        autoscroll == AutoscrollStatus.running ||
        autoscroll == AutoscrollStatus.paused;
    final onAyahTap = tapPauses ? (int _) => _togglePause() : widget.onAyahTap;

    // The list's items: the previous-surah button, the header, the basmala,
    // the paragraphs, then the next-surah button and the end space.
    final items = <Widget Function()>[
      if (surah.id > 1)
        () => _SurahStep(
          key: continuousPreviousSurahKey,
          label: AppLocalizations.of(context).continuousPreviousSurah,
          icon: Icons.expand_less,
          onPressed: () => _openSurah(surah.id - 1),
        ),
      () => _SurahHeader(key: ContinuousHeaderKey(surah.id), surah: surah),
      if (data.basmala case final basmala?)
        () => _Basmala(
          key: ContinuousBasmalaKey(surah.id),
          words: basmala,
          style: style,
        ),
    ];
    final firstParagraphItem = items.length;
    for (var i = 0; i < data.paragraphs.length; i++) {
      items.add(() {
        final key = _paragraphKeys.putIfAbsent(
          i,
          GlobalKey<AyahParagraphState>.new,
        );
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: AyahParagraph(
            key: key,
            ayahs: data.paragraphs[i],
            style: style,
            highlightedAyahId: highlighted,
            onAyahTap: onAyahTap,
            onAyahLongPress: widget.onAyahLongPress,
          ),
        );
      });
    }
    items.add(
      () => Padding(
        padding: const EdgeInsets.only(
          top: AppSpacing.lg,
          bottom: AppSpacing.xxxl,
        ),
        child: surah.id < surahCount
            ? _SurahStep(
                key: continuousNextSurahKey,
                label: AppLocalizations.of(context).continuousNextSurah,
                icon: Icons.expand_more,
                onPressed: () => _openSurah(surah.id + 1),
              )
            : const SizedBox.shrink(),
      ),
    );

    final anchorItem = _anchorAyahId == data.firstAyahId
        ? 0
        : firstParagraphItem + data.paragraphOf(_anchorAyahId);

    Widget item(int index) => Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSizes.readingMeasure),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
          child: items[index](),
        ),
      ),
    );

    const center = ValueKey<String>('continuous-center');
    return ColoredBox(
      color: colors.page,
      child: NotificationListener<ScrollNotification>(
        key: continuousScrollKey,
        onNotification: _onScroll,
        child: GestureDetector(
          // A tap between paragraphs pauses or resumes too.
          behavior: HitTestBehavior.translucent,
          onTap: tapPauses ? _togglePause : null,
          child: KeyedSubtree(
            key: _viewportKey,
            child: CustomScrollView(
              key: ValueKey<int>(_generation),
              controller: _scroll,
              center: center,
              slivers: <Widget>[
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => item(anchorItem - 1 - i),
                    childCount: anchorItem,
                  ),
                ),
                SliverList(
                  key: center,
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => item(anchorItem + i),
                    childCount: items.length - anchorItem,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The surah's name and details over a hairline rule. The name comes from
/// the database and is interface text, set in the interface face.
class _SurahHeader extends StatelessWidget {
  const _SurahHeader({super.key, required this.surah});

  final Surah surah;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final place = switch (surah.revelationPlace) {
      RevelationPlace.makkah => l10n.surahMakki,
      RevelationPlace.madinah => l10n.surahMadani,
    };
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xl, bottom: AppSpacing.lg),
      child: Column(
        children: <Widget>[
          Text(
            surah.nameAr,
            style: theme.textTheme.headlineSmall,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.surahDetails(place, l10n.ayahCount(surah.ayahCount)),
            style: theme.textTheme.labelSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          Container(height: AppSizes.hairline, color: colors.rule),
        ],
      ),
    );
  }
}

/// The basmala, centred: the words the repository gives for it, in the
/// Quran face. It belongs to no ayah of the surah, so it reports no taps.
class _Basmala extends StatelessWidget {
  const _Basmala({super.key, required this.words, required this.style});

  final List<Word> words;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text.rich(
        TextSpan(
          children: <InlineSpan>[
            for (var i = 0; i < words.length; i++) ...<InlineSpan>[
              if (i > 0) const TextSpan(text: ' '),
              TextSpan(text: words[i].textQpcHafs),
            ],
          ],
        ),
        style: style,
        textAlign: TextAlign.center,
        textDirection: TextDirection.rtl,
      ),
    );
  }
}

/// A quiet text button that opens the previous or the next surah.
class _SurahStep extends StatelessWidget {
  const _SurahStep({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Center(
        child: TextButton.icon(
          onPressed: onPressed,
          icon: Icon(icon),
          label: Text(label),
        ),
      ),
    );
  }
}
