import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/routing/app_router.dart';
import '../../core/settings/settings_providers.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/bookmark_repository.dart';
import '../../data/quran_repository.dart';
import '../../data/reciter_repository.dart';
import '../audio/player_bar.dart';
import '../audio/recitation_controller.dart';
import '../audio/reciter_picker.dart';
import '../mushaf/reader_controller.dart';
import '../tafsir/tafsir_sheet.dart';
import 'ayah_actions.dart';
import 'repeat_picker.dart';

/// The key of an action row of the ayah menu.
class AyahActionKey extends ValueKey<AyahAction> {
  const AyahActionKey(super.value);
}

/// The key of the ayah menu sheet.
const ValueKey<String> ayahMenuKey = ValueKey<String>('ayah-menu');

/// The key of the ayah menu's heading.
const ValueKey<String> ayahMenuTitleKey = ValueKey<String>('ayah-menu-title');

/// The key of the reciter shortcut on the Listen row.
const ValueKey<String> ayahMenuReciterKey = ValueKey<String>(
  'ayah-menu-reciter',
);

/// Opens the ayah menu (spec US4, FR-017) for ayah [ayahId] over the reader,
/// and carries out the action chosen there.
///
/// The ayah is highlighted while the menu is open. Bookmark, Mark as
/// memorised and the reciter shortcut act inside the menu, which stays open;
/// Bookmark and Mark as memorised are toggles that show the ayah's current
/// state. Every other action closes the menu first and then runs from
/// [context]:
///
/// - Listen recites only this ayah, once.
/// - Repeat asks for a count ([showRepeatPicker]) and recites the ayah that
///   many times; the player bar shows the repeats left.
/// - Tafsir opens the tafsir sheet on this ayah.
/// - Surah story opens `/stories/surah/:surah`; it is enabled only when the
///   catalog has a playable story for the surah.
/// - Share hands [formatAyahShareText] to [sharePortProvider].
/// - Report an error calls [ayahErrorReporterProvider], and is listed only
///   when one is provided.
///
/// Needs [quranRepositoryProvider] to have a value, as the reader does.
Future<void> showAyahMenu(BuildContext context, int ayahId) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final action = await whileHighlighting(
    container,
    ayahId,
    (_) => showModalBottomSheet<AyahAction>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: true,
      builder: (context) => AyahMenuSheet(ayahId: ayahId),
    ),
  );
  if (action == null || !context.mounted) return;
  await _run(context, container, action, ayahId);
}

Future<void> _run(
  BuildContext context,
  ProviderContainer container,
  AyahAction action,
  int ayahId,
) async {
  final quran = container.read(quranRepositoryProvider).requireValue;
  final ref = quran.refOf(ayahId);
  final recitation = container.read(recitationControllerProvider.notifier);
  switch (action) {
    case AyahAction.listen:
      unawaited(recitation.playAyah(ref));
    case AyahAction.repeat:
      final count = await showRepeatPicker(context);
      if (count != null) unawaited(recitation.repeatAyah(ref, count));
    case AyahAction.tafsir:
      await showTafsirSheet(context, ayahId);
    case AyahAction.surahStory:
      GoRouter.of(context).go(AppRoutes.surahStory(ref.surah));
    case AyahAction.share:
      final text = formatAyahShareText(
        ayah: quran.ayah(ayahId),
        surah: quran.surah(ref.surah),
        l10n: AppLocalizations.of(context),
      );
      // The reader's area anchors the share popover on iPad.
      final box = context.findRenderObject() as RenderBox?;
      final origin = box != null && box.hasSize
          ? box.localToGlobal(Offset.zero) & box.size
          : null;
      await container.read(sharePortProvider).shareText(text, origin: origin);
    case AyahAction.report:
      await container.read(ayahErrorReporterProvider)?.call(context, ayahId);
    case AyahAction.bookmark:
    case AyahAction.memorise:
      // Handled inside the menu, which stays open.
      break;
  }
}

/// The ayah menu: the ayah's reference, then one row per action in the
/// order of [AyahAction]. A row that leaves the menu closes it with its
/// action as the result.
class AyahMenuSheet extends ConsumerWidget {
  const AyahMenuSheet({super.key, required this.ayahId});

  final int ayahId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final quran = ref.watch(quranRepositoryProvider).requireValue;
    final ayah = quran.ayah(ayahId);
    final surah = quran.surah(ayah.surahId);
    final surahName = Localizations.localeOf(context).languageCode == 'ar'
        ? surah.nameAr
        : surah.nameEn;

    final reciterId = ref.watch(reciterIdProvider);
    final reciters = ref.watch(reciterRepositoryProvider).value;
    final reciter = reciters == null
        ? null
        : reciters.reciter(reciterId) ?? reciters.reciters().first;
    final repeatCount = ref.watch(repeatCountProvider);
    final hasStory =
        ref.watch(playableSurahStoryProvider(ayah.surahId)) != null;
    bool isMarked(AyahMarkKind kind) =>
        ref.watch(markedAyahIdsProvider(kind)).contains(ayahId);
    final bookmarked = isMarked(AyahMarkKind.bookmark);
    final memorised = isMarked(AyahMarkKind.memorisation);

    Future<void> toggle(AyahMarkKind kind) async {
      (await ref.read(markRepositoryProvider(kind).future)).toggle(ayahId);
    }

    final reporter = ref.watch(ayahErrorReporterProvider);

    void close(AyahAction action) => Navigator.of(context).pop(action);

    Widget row(
      AyahAction action, {
      required IconData icon,
      required String title,
      String? subtitle,
      Widget? trailing,
      Color? iconColor,
      VoidCallback? onTap,
    }) => ListTile(
      key: AyahActionKey(action),
      minTileHeight: AppSizes.listRowMinHeight,
      contentPadding: const EdgeInsetsDirectional.only(
        start: AppSpacing.gutter,
        end: AppSpacing.xs,
      ),
      leading: Icon(icon, color: iconColor),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: trailing,
      enabled: onTap != null,
      onTap: onTap,
    );

    final rows = <Widget>[
      for (final action in AyahAction.values)
        if (action != AyahAction.report || reporter != null)
          switch (action) {
            AyahAction.listen => row(
              action,
              icon: Icons.play_circle_outline,
              title: l10n.ayahMenuListen,
              subtitle: reciter == null ? null : reciterName(context, reciter),
              trailing: IconButton(
                key: ayahMenuReciterKey,
                tooltip: l10n.playerChooseReciter,
                icon: const Icon(Icons.record_voice_over_outlined),
                onPressed: () => showReciterPicker(context),
              ),
              onTap: () => close(action),
            ),
            AyahAction.repeat => row(
              action,
              icon: Icons.repeat,
              title: l10n.ayahMenuRepeat,
              subtitle: l10n.ayahMenuRepeatTimes(repeatCount),
              onTap: () => close(action),
            ),
            AyahAction.tafsir => row(
              action,
              icon: Icons.menu_book_outlined,
              title: l10n.ayahMenuTafsir,
              onTap: () => close(action),
            ),
            AyahAction.surahStory => row(
              action,
              icon: Icons.movie_outlined,
              title: l10n.ayahMenuSurahStory,
              subtitle: hasStory ? null : l10n.ayahMenuStoryUnavailable,
              onTap: hasStory ? () => close(action) : null,
            ),
            AyahAction.bookmark => row(
              action,
              icon: bookmarked ? Icons.bookmark : Icons.bookmark_border,
              iconColor: bookmarked ? scheme.primary : null,
              title: bookmarked
                  ? l10n.ayahMenuRemoveBookmark
                  : l10n.ayahMenuAddBookmark,
              onTap: () => toggle(AyahMarkKind.bookmark),
            ),
            AyahAction.memorise => row(
              action,
              icon: memorised ? Icons.check_circle : Icons.check_circle_outline,
              iconColor: memorised ? scheme.primary : null,
              title: memorised
                  ? l10n.ayahMenuUnmarkMemorised
                  : l10n.ayahMenuMarkMemorised,
              onTap: () => toggle(AyahMarkKind.memorisation),
            ),
            AyahAction.share => row(
              action,
              icon: Icons.share_outlined,
              title: l10n.ayahMenuShare,
              onTap: () => close(action),
            ),
            AyahAction.report => row(
              action,
              icon: Icons.flag_outlined,
              title: l10n.ayahMenuReportError,
              onTap: () => close(action),
            ),
          },
    ];

    return SafeArea(
      key: ayahMenuKey,
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.gutter,
              ),
              child: Semantics(
                header: true,
                child: Text(
                  l10n.ayahMenuTitle(surahName, ayah.ayahNumber),
                  key: ayahMenuTitleKey,
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Divider(),
            Flexible(child: ListView(shrinkWrap: true, children: rows)),
          ],
        ),
      ),
    );
  }
}
