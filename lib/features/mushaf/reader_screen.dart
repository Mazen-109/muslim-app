import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/routing/app_router.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/state_views.dart';
import '../../data/quran_repository.dart';
import '../tafsir/tafsir_sheet.dart';
import 'page_view/mushaf_page_view.dart';
import 'page_view/page_line_widgets.dart';
import 'quran_font_check.dart';
import 'reader_controller.dart';

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

  /// Called with the ayah id of a long-pressed word (the ayah menu, later).
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final repository = ref.watch(quranRepositoryProvider);
    final font = ref.watch(quranFontCheckProvider);

    final Widget body;
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
              onAyahLongPress: widget.onAyahLongPress,
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
      ],
      body: body,
    );
  }
}
