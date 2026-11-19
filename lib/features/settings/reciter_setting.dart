import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/settings/settings_providers.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/models/reciter.dart';
import '../../data/reciter_repository.dart';

/// The key of the settings row that opens the default reciter choice.
const ValueKey<String> reciterSettingKey = ValueKey<String>('reciter-setting');

/// The key of [reciterId]'s row in the default reciter sheet.
ValueKey<String> reciterOptionKey(int reciterId) =>
    ValueKey<String>('reciter-option-$reciterId');

/// [reciter]'s name in the interface language, with its recitation style
/// when it has one. Names come from the content database as stored.
String reciterLabel(BuildContext context, Reciter reciter) {
  final l10n = AppLocalizations.of(context);
  final name = Localizations.localeOf(context).languageCode == 'ar'
      ? reciter.nameAr
      : reciter.nameEn;
  final style = switch (reciter.style) {
    null => null,
    ReciterStyle.murattal => l10n.reciterStyleMurattal,
    ReciterStyle.mujawwad => l10n.reciterStyleMujawwad,
    ReciterStyle.muallim => l10n.reciterStyleMuallim,
  };
  return style == null ? name : l10n.reciterWithStyle(name, style);
}

/// The default reciter (`reciter_id`): a row showing the current reciter
/// that opens a sheet listing every reciter.
class ReciterSetting extends ConsumerWidget {
  const ReciterSetting({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final repository = ref.watch(reciterRepositoryProvider).value;
    final current = repository?.reciter(ref.watch(reciterIdProvider));

    return ListTile(
      key: reciterSettingKey,
      leading: const Icon(Icons.record_voice_over_outlined),
      title: Text(l10n.settingsReciter),
      subtitle: current == null ? null : Text(reciterLabel(context, current)),
      enabled: repository != null,
      onTap: repository == null
          ? null
          : () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (context) => _ReciterSheet(repository: repository),
            ),
    );
  }
}

class _ReciterSheet extends ConsumerWidget {
  const _ReciterSheet({required this.repository});

  final ReciterRepository repository;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final selectedId = ref.watch(reciterIdProvider);
    final theme = Theme.of(context);

    return SafeArea(
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
            child: Text(
              l10n.settingsReciter,
              style: theme.textTheme.titleLarge,
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: <Widget>[
                for (final reciter in repository.reciters())
                  _option(context, ref, reciter, reciter.id == selectedId),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }

  Widget _option(
    BuildContext context,
    WidgetRef ref,
    Reciter reciter,
    bool selected,
  ) {
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: ListTile(
        key: reciterOptionKey(reciter.id),
        title: Text(reciterLabel(context, reciter)),
        selected: selected,
        trailing: selected ? const Icon(Icons.check) : null,
        onTap: () async {
          await ref.read(reciterIdProvider.notifier).set(reciter.id);
          if (context.mounted) Navigator.of(context).pop();
        },
      ),
    );
  }
}
