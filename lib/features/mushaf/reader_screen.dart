import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/routing/app_router.dart';
import '../../core/settings/settings_repository.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/state_views.dart';
import '../../data/quran_repository.dart';
import '../audio/player_bar.dart';
import '../ayah_menu/ayah_menu_sheet.dart';
import '../tafsir/tafsir_sheet.dart';
import 'continuous/continuous_view.dart';
import 'continuous/text_size_sheet.dart';
import 'go_to_sheet.dart';
import 'page_view/mushaf_page_view.dart';
import 'page_view/page_line_widgets.dart';
import 'quran_font_check.dart';
import 'reader_controller.dart';
import 'resume.dart';

/// The Mushaf reader at `/mushaf` (contracts/routes.md).
///
/// It opens at [target] once the content database is open and the Quran
/// font has passed its check. Either failure shows a blocking error instead
/// of the page: the Mushaf is never drawn from partial data or in another
/// font (plan.md, Errors).
class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({
    super.key,
    required this.target,
    this.onAyahTap,
    this.onAyahLongPress,
  });

  final ReaderTarget target;

  /// Called with the ayah id of a tapped word. When null, a tap opens the
  /// tafsir sheet on that ayah.
  final AyahCallback? onAyahTap;

  /// Called with the ayah id of a long-pressed word. When null, a long
  /// press opens the ayah menu on that ayah.
  final AyahCallback? onAyahLongPress;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  /// The target the controller was last opened at.
  ReaderTarget? _opened;

  void _openWhenReady() {
    if (_opened == widget.target) return;
    final ready = ref.read(quranRepositoryProvider).hasValue;
    if (!ready) return;
    _opened = widget.target;
    ref.read(readerControllerProvider.notifier).open(widget.target);
  }

  void _openTafsir(int ayahId) => showTafsirSheet(context, ayahId);

  void _openAyahMenu(int ayahId) => showAyahMenu(context, ayahId);

  /// Opens the go-to sheet and moves the reader to the place chosen there,
  /// through the `/mushaf` route like any other link.
  Future<void> _goTo() async {
    final target = await showGoToSheet(
      context,
      initialAyahId: ref.read(readerControllerProvider).currentAyahId,
    );
    if (target == null || !mounted) return;
    final location = switch (target) {
      AyahTarget(:final ref, :final highlight) => AppRoutes.mushafAyah(
        ref,
        highlight: highlight,
      ),
      PageTarget(:final page) => AppRoutes.mushafPage(page),
    };
    if (target == widget.target) {
      // The route does not change, so the screen is not rebuilt with a new
      // target: apply it here.
      ref.read(readerControllerProvider.notifier).open(target);
    } else {
      context.go(location);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final repository = ref.watch(quranRepositoryProvider);
    final font = ref.watch(quranFontCheckProvider);

    Widget body;
    if (font.hasError) {
      body = ErrorStateView(
        title: l10n.mushafFontErrorTitle,
        message: l10n.mushafFontErrorMessage,
      );
    } else if (repository.hasError) {
      body = ErrorStateView(message: l10n.mushafDataErrorMessage);
    } else if (!font.hasValue || !repository.hasValue) {
      body = const LoadingStateView();
    } else {
      // Providers cannot change while the tree builds, so the link is
      // applied to the controller right after this frame. The page view is
      // first built after that, so it opens on the right page with no
      // visible jump; a later link reaches the built view, which follows
      // the controller.
      if (_opened != widget.target) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final first = _opened == null;
          _openWhenReady();
          if (first) setState(() {});
        });
      }
      body = _opened == null
          ? const LoadingStateView()
          : MushafPageView(
              onAyahTap: widget.onAyahTap ?? _openTafsir,
              onAyahLongPress: widget.onAyahLongPress ?? _openAyahMenu,
            );
    }
    final opened = body is MushafPageView;

    // The continuous view takes the page view's place, with its callbacks.
    final mode = ref.watch(readerControllerProvider.select((s) => s.mode));
    final continuous = mode == ReadingMode.continuous;
    if (continuous && body is MushafPageView) {
      body = ContinuousView(
        onAyahTap: body.onAyahTap,
        onAyahLongPress: body.onAyahLongPress,
      );
    }

    return AppScaffold(
      title: l10n.navMushaf,
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
        IconButton(
          key: readerModeToggleKey,
          tooltip: continuous
              ? l10n.readerShowPages
              : l10n.readerShowContinuous,
          icon: Icon(continuous ? Icons.auto_stories_outlined : Icons.notes),
          onPressed: () => ref
              .read(readerControllerProvider.notifier)
              .setMode(continuous ? ReadingMode.pages : ReadingMode.continuous),
        ),
        const PlayFromHereButton(),
        // Less frequent actions wait in a menu, so the title keeps its
        // room on a phone.
        PopupMenuButton<_ReaderMenuAction>(
          key: readerMoreKey,
          tooltip: MaterialLocalizations.of(context).moreButtonTooltip,
          onSelected: (action) => switch (action) {
            _ReaderMenuAction.goTo => _goTo(),
            _ReaderMenuAction.textSize => showTextSizeSheet(context),
          },
          itemBuilder: (context) => <PopupMenuEntry<_ReaderMenuAction>>[
            PopupMenuItem<_ReaderMenuAction>(
              key: readerGoToKey,
              value: _ReaderMenuAction.goTo,
              enabled: opened,
              child: ListTile(
                leading: const Icon(Icons.find_in_page_outlined),
                title: Text(l10n.readerGoTo),
              ),
            ),
            if (continuous)
              PopupMenuItem<_ReaderMenuAction>(
                key: readerTextSizeKey,
                value: _ReaderMenuAction.textSize,
                child: ListTile(
                  leading: const Icon(Icons.format_size),
                  title: Text(l10n.readerTextSize),
                ),
              ),
          ],
        ),
      ],
      // The last ayah is recorded only once the reader has opened its
      // target, so the controller's starting position is never saved.
      body: ReaderPlayback(
        child: opened ? ResumeRecorderScope(child: body) : body,
      ),
    );
  }
}

/// The key of the reader's button that switches between the page view and
/// the continuous view.
const ValueKey<String> readerModeToggleKey = ValueKey<String>(
  'reader-mode-toggle',
);

/// The actions in the reader's overflow menu.
enum _ReaderMenuAction { goTo, textSize }

/// The key of the reader's overflow menu button.
const ValueKey<String> readerMoreKey = ValueKey<String>('reader-more');

/// The key of the go-to item in the reader's overflow menu.
const ValueKey<String> readerGoToKey = ValueKey<String>('reader-go-to');

/// The key of the text size item in the reader's overflow menu
/// (continuous view only).
const ValueKey<String> readerTextSizeKey = ValueKey<String>('reader-text-size');
