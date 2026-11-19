import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/settings/settings_providers.dart';
import '../../core/settings/settings_repository.dart';
import '../../core/theme/app_spacing.dart';

/// The keys of the repeat picker's controls.
const ValueKey<String> repeatPickerKey = ValueKey<String>('repeat-picker');
const ValueKey<String> repeatPickerSliderKey = ValueKey<String>(
  'repeat-picker-slider',
);
const ValueKey<String> repeatPickerFewerKey = ValueKey<String>(
  'repeat-picker-fewer',
);
const ValueKey<String> repeatPickerMoreKey = ValueKey<String>(
  'repeat-picker-more',
);
const ValueKey<String> repeatPickerCountKey = ValueKey<String>(
  'repeat-picker-count',
);
const ValueKey<String> repeatPickerStartKey = ValueKey<String>(
  'repeat-picker-start',
);

/// Asks how many times to repeat an ayah, from 2 to 20, starting at the
/// `repeat_count` setting. Returns the count, or null when the sheet is
/// dismissed. The chosen count is saved as `repeat_count`, so the next
/// repeat starts from it.
Future<int?> showRepeatPicker(BuildContext context) =>
    showModalBottomSheet<int>(
      context: context,
      useRootNavigator: true,
      builder: (context) => const RepeatPicker(),
    );

/// A count between one-fewer and one-more buttons, with a slider, and a
/// button that confirms it.
class RepeatPicker extends ConsumerStatefulWidget {
  const RepeatPicker({super.key});

  @override
  ConsumerState<RepeatPicker> createState() => RepeatPickerState();
}

/// The state of [RepeatPicker]; [count] is the count shown.
class RepeatPickerState extends ConsumerState<RepeatPicker> {
  static const int _min = SettingsRepository.minRepeatCount;
  static const int _max = SettingsRepository.maxRepeatCount;

  late int count = ref.read(repeatCountProvider).clamp(_min, _max);

  void _set(int value) => setState(() => count = value.clamp(_min, _max));

  Future<void> _start() async {
    final chosen = count;
    await ref.read(repeatCountProvider.notifier).set(chosen);
    if (mounted) Navigator.of(context).pop(chosen);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SafeArea(
      key: repeatPickerKey,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSizes.readingMeasure),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            0,
            AppSpacing.gutter,
            AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Semantics(
                header: true,
                child: Text(
                  l10n.repeatPickerTitle,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Semantics(
                liveRegion: true,
                child: Text(
                  l10n.ayahMenuRepeatTimes(count),
                  key: repeatPickerCountKey,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: scheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: <Widget>[
                  IconButton(
                    key: repeatPickerFewerKey,
                    tooltip: l10n.repeatPickerFewer,
                    icon: const Icon(Icons.remove),
                    onPressed: count > _min ? () => _set(count - 1) : null,
                  ),
                  Expanded(
                    child: Slider(
                      key: repeatPickerSliderKey,
                      value: count.toDouble(),
                      min: _min.toDouble(),
                      max: _max.toDouble(),
                      divisions: _max - _min,
                      semanticFormatterCallback: (value) =>
                          l10n.ayahMenuRepeatTimes(value.round()),
                      onChanged: (value) => _set(value.round()),
                    ),
                  ),
                  IconButton(
                    key: repeatPickerMoreKey,
                    tooltip: l10n.repeatPickerMore,
                    icon: const Icon(Icons.add),
                    onPressed: count < _max ? () => _set(count + 1) : null,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                key: repeatPickerStartKey,
                icon: const Icon(Icons.repeat),
                label: Text(l10n.repeatPickerStart),
                onPressed: _start,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
