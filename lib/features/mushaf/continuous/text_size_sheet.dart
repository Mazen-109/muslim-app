import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/settings/settings_providers.dart';
import '../../../core/settings/settings_repository.dart';
import '../../../core/theme/app_spacing.dart';

/// The key of the text size slider.
const ValueKey<String> textSizeSliderKey = ValueKey<String>('text-size-slider');

/// The key of the button that makes the text one step smaller.
const ValueKey<String> textSizeSmallerKey = ValueKey<String>(
  'text-size-smaller',
);

/// The key of the button that makes the text one step larger.
const ValueKey<String> textSizeLargerKey = ValueKey<String>('text-size-larger');

/// Opens the continuous view's text size control as a bottom sheet over
/// the reader, so the text behind it resizes as the reader adjusts it.
Future<void> showTextSizeSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => const TextSizeSheet(),
    );

/// The continuous view's text size control in a sheet: [TextSizeControl]
/// under the sheet's title, within the reading measure.
class TextSizeSheet extends StatelessWidget {
  const TextSizeSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSizes.readingMeasure),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            0,
            AppSpacing.gutter,
            AppSpacing.xl,
          ),
          child: TextSizeControl(
            title: AppLocalizations.of(context).readerTextSize,
          ),
        ),
      ),
    );
  }
}

/// `font_scale` (data-model.md section 4) from 0.8 to 2.0 in steps of 0.1:
/// [title] and the size as a percentage of the default, over a slider
/// between one-step smaller and larger buttons. Every change is applied and
/// persisted at once. Used by the reader's sheet and by the settings screen.
class TextSizeControl extends ConsumerWidget {
  const TextSizeControl({super.key, required this.title});

  final String title;

  static const double _step = 0.1;
  static const int _divisions = 12;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scale = ref.watch(fontScaleProvider);
    final notifier = ref.read(fontScaleProvider.notifier);
    const min = SettingsRepository.minFontScale;
    const max = SettingsRepository.maxFontScale;
    final percent = (scale * 100).round();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
            Text(
              l10n.readerTextSizeValue(percent),
              style: theme.textTheme.labelMedium,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: <Widget>[
            IconButton(
              key: textSizeSmallerKey,
              tooltip: l10n.readerTextSmaller,
              icon: const Icon(Icons.text_decrease),
              onPressed: scale <= min
                  ? null
                  : () => notifier.set(scale - _step),
            ),
            Expanded(
              child: Slider(
                key: textSizeSliderKey,
                value: scale.clamp(min, max),
                min: min,
                max: max,
                divisions: _divisions,
                label: l10n.readerTextSizeValue(percent),
                semanticFormatterCallback: (value) =>
                    l10n.readerTextSizeValue((value * 100).round()),
                onChanged: (value) {
                  if (value != scale) notifier.set(value);
                },
              ),
            ),
            IconButton(
              key: textSizeLargerKey,
              tooltip: l10n.readerTextLarger,
              icon: const Icon(Icons.text_increase),
              onPressed: scale >= max
                  ? null
                  : () => notifier.set(scale + _step),
            ),
          ],
        ),
      ],
    );
  }
}
