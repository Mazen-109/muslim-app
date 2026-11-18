import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_motion.dart';
import '../../../data/models/mushaf_page.dart';
import '../../../data/quran_repository.dart';
import '../reader_controller.dart';
import 'mushaf_page_widget.dart';
import 'page_line_widgets.dart';

/// A Mushaf page with its running head, read from the repository.
typedef MushafPageData = ({MushafPage page, MushafPageHeading heading});

/// Page [number] (1 to 604) and the surah and juz of its first word. Needs
/// [quranRepositoryProvider] to have a value.
final mushafPageProvider = Provider.autoDispose.family<MushafPageData, int>((
  ref,
  number,
) {
  final repository = ref.watch(quranRepositoryProvider).requireValue;
  final page = repository.page(number);
  final firstAyahId = page.lines.whereType<AyahLine>().first.words.first.ayahId;
  final juz = repository
      .juzs()
      .firstWhere(
        (j) => j.firstAyahId <= firstAyahId && firstAyahId <= j.lastAyahId,
      )
      .id;
  return (
    page: page,
    heading: MushafPageHeading(
      surah: repository.surah(repository.refOf(firstAyahId).surah),
      juz: juz,
    ),
  );
});

/// The 604 pages as a right-to-left [PageView]: page 1 is the first item
/// and the next page comes in from the left, as in the printed Mushaf,
/// whatever the interface language. Only the visible page and its
/// neighbours are built.
///
/// The view follows [readerControllerProvider]: it opens on the
/// controller's page, reports page turns to it, and turns to a new page the
/// controller moves to (a link, the audio follower).
class MushafPageView extends ConsumerStatefulWidget {
  const MushafPageView({super.key, this.onAyahTap, this.onAyahLongPress});

  final AyahCallback? onAyahTap;
  final AyahCallback? onAyahLongPress;

  @override
  ConsumerState<MushafPageView> createState() => _MushafPageViewState();
}

class _MushafPageViewState extends ConsumerState<MushafPageView> {
  late final PageController _controller = PageController(
    initialPage: ref.read(readerControllerProvider).page - 1,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _follow(int page) {
    if (!_controller.hasClients) return;
    final shown = (_controller.page ?? _controller.initialPage).round() + 1;
    if (shown == page) return;
    if ((shown - page).abs() == 1) {
      _controller.animateToPage(
        page - 1,
        duration: AppMotion.resolve(context, AppMotion.pageTurn),
        curve: AppMotion.standard,
      );
    } else {
      _controller.jumpToPage(page - 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(
      readerControllerProvider.select((s) => s.page),
      (previous, next) => _follow(next),
    );
    final l10n = AppLocalizations.of(context);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: PageView.builder(
        controller: _controller,
        itemCount: pageCount,
        allowImplicitScrolling: true,
        onPageChanged: (index) =>
            ref.read(readerControllerProvider.notifier).showPage(index + 1),
        itemBuilder: (context, index) => Semantics(
          container: true,
          label: l10n.mushafPageNumber(index + 1),
          child: Directionality(
            // The running head follows the interface language; the text
            // block sets its own right-to-left direction.
            textDirection: Directionality.of(this.context),
            child: _PageSlot(
              number: index + 1,
              onAyahTap: widget.onAyahTap,
              onAyahLongPress: widget.onAyahLongPress,
            ),
          ),
        ),
      ),
    );
  }
}

class _PageSlot extends ConsumerWidget {
  const _PageSlot({required this.number, this.onAyahTap, this.onAyahLongPress});

  final int number;
  final AyahCallback? onAyahTap;
  final AyahCallback? onAyahLongPress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(mushafPageProvider(number));
    final highlighted = ref.watch(
      readerControllerProvider.select((s) => s.highlightedAyahId),
    );
    return MushafPageWidget(
      page: data.page,
      heading: data.heading,
      highlightedAyahId: highlighted,
      onAyahTap: onAyahTap,
      onAyahLongPress: onAyahLongPress,
    );
  }
}
