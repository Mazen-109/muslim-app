import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/settings/settings_providers.dart';
import '../../data/models/reciter.dart';
import '../../data/reciter_repository.dart';
import '../audio/reciter_picker.dart';

/// The key of the settings row that opens the default reciter choice.
const ValueKey<String> reciterSettingKey = ValueKey<String>('reciter-setting');

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
/// that opens the same reciter picker as the player bar.
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
      onTap: repository == null ? null : () => showReciterPicker(context),
    );
  }
}
