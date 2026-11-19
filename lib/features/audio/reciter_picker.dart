import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/settings/settings_providers.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/reciter.dart';
import '../../data/reciter_repository.dart';
import 'player_bar.dart';

/// The key of the reciter picker's row for the reciter with id [value].
class ReciterTileKey extends ValueKey<int> {
  const ReciterTileKey(super.value);
}

/// Opens the reciter list as a bottom sheet. Choosing a reciter saves it as
/// the `reciter_id` setting and closes the sheet; a recitation in progress
/// continues from its current ayah with the new reciter
/// ([RecitationController]). The ayah menu's reciter shortcut opens the same
/// sheet.
Future<void> showReciterPicker(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => const ReciterPicker(),
    );

/// Every reciter of the content database in display order, with its name
/// and recitation style. The chosen one is marked with the accent wash and
/// a check.
class ReciterPicker extends ConsumerWidget {
  const ReciterPicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final repository = ref.watch(reciterRepositoryProvider);
    final selected = ref.watch(reciterIdProvider);

    final Widget list;
    if (repository.hasError) {
      list = ErrorStateView(message: l10n.mushafDataErrorMessage);
    } else if (!repository.hasValue) {
      list = const LoadingStateView();
    } else {
      final reciters = repository.requireValue.reciters();
      // An unknown saved id plays with the first reciter, so mark that one.
      final current = reciters.any((r) => r.id == selected)
          ? selected
          : reciters.first.id;
      list = ListView(
        shrinkWrap: true,
        children: <Widget>[
          for (final reciter in reciters)
            _ReciterTile(
              reciter: reciter,
              selected: reciter.id == current,
              onTap: () async {
                await ref.read(reciterIdProvider.notifier).set(reciter.id);
                if (context.mounted) Navigator.of(context).pop();
              },
            ),
        ],
      );
    }

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: AppSizes.readingMeasure,
          maxHeight: MediaQuery.sizeOf(context).height * 0.75,
        ),
        child: Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.gutter,
                  0,
                  AppSpacing.gutter,
                  AppSpacing.sm,
                ),
                child: Semantics(
                  header: true,
                  child: Text(
                    l10n.reciterPickerTitle,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ),
              Flexible(child: list),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReciterTile extends StatelessWidget {
  const _ReciterTile({
    required this.reciter,
    required this.selected,
    required this.onTap,
  });

  final Reciter reciter;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final style = switch (reciter.style) {
      null => null,
      ReciterStyle.murattal => l10n.reciterStyleMurattal,
      ReciterStyle.mujawwad => l10n.reciterStyleMujawwad,
      ReciterStyle.muallim => l10n.reciterStyleMuallim,
    };
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      child: ListTile(
        key: ReciterTileKey(reciter.id),
        minTileHeight: AppSizes.listRowMinHeight,
        selected: selected,
        selectedTileColor: scheme.primaryContainer,
        selectedColor: scheme.onPrimaryContainer,
        title: Text(reciterName(context, reciter)),
        subtitle: style == null ? null : Text(style),
        trailing: selected
            ? const ExcludeSemantics(child: Icon(Icons.check))
            : null,
        onTap: onTap,
      ),
    );
  }
}
