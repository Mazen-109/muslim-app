import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/settings/settings_providers.dart';
import '../../core/settings/settings_repository.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';

/// The key of the option for [preference] in the theme picker.
ValueKey<String> themeOptionKey(ThemePreference preference) =>
    ValueKey<String>('theme-option-${preference.storageValue}');

/// The name of [preference] in the interface language.
String themeName(AppLocalizations l10n, ThemePreference preference) =>
    switch (preference) {
      ThemePreference.light => l10n.themeLight,
      ThemePreference.night => l10n.themeNight,
      ThemePreference.blackOnWhite => l10n.themeBlackOnWhite,
      ThemePreference.whiteOnBlack => l10n.themeWhiteOnBlack,
    };

/// The four themes (FR-022) side by side, each shown as a swatch drawn in
/// its own colours. Picking one applies it to the whole app at once and
/// stores it.
class ThemePicker extends ConsumerWidget {
  const ThemePicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(themeProvider);
    final l10n = AppLocalizations.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final (i, preference) in ThemePreference.values.indexed) ...[
          if (i > 0) const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _ThemeOption(
              key: themeOptionKey(preference),
              label: themeName(l10n, preference),
              theme: AppTheme.of(preference),
              selected: preference == selected,
              onTap: () => ref.read(themeProvider.notifier).set(preference),
            ),
          ),
        ],
      ],
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    super.key,
    required this.label,
    required this.theme,
    required this.selected,
    required this.onTap,
  });

  final String label;

  /// The theme this option previews, not the one around it.
  final ThemeData theme;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final current = Theme.of(context);
    final scheme = current.colorScheme;
    final ring = selected ? scheme.primary : scheme.outlineVariant;
    final ringWidth = selected ? 2 * AppSizes.hairline : AppSizes.hairline;

    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.mdAll,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxs),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              AnimatedContainer(
                duration: AppMotion.resolve(context, AppMotion.short),
                curve: AppMotion.standard,
                decoration: BoxDecoration(
                  borderRadius: AppRadii.mdAll,
                  border: Border.all(color: ring, width: ringWidth),
                ),
                padding: const EdgeInsets.all(AppSpacing.xxs),
                child: ThemeSwatch(theme: theme),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  if (selected) ...<Widget>[
                    Icon(
                      Icons.check,
                      size: AppSpacing.lg,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: AppSpacing.xxs),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: current.textTheme.labelMedium!.copyWith(
                        color: selected
                            ? scheme.onSurface
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A miniature of [theme] in its colours only: the ground, a page with lines
/// of ink and one marked line, and a bar with the accent's indicator. It
/// holds no text.
class ThemeSwatch extends StatelessWidget {
  const ThemeSwatch({super.key, required this.theme});

  final ThemeData theme;

  static const double _aspectRatio = 3 / 4;
  static const double _lineHeight = 3;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    final reading = theme.extension<AppColors>()!;

    Widget line(Color color, {double widthFactor = 1}) => FractionallySizedBox(
      alignment: AlignmentDirectional.centerEnd,
      widthFactor: widthFactor,
      child: Container(
        height: _lineHeight,
        decoration: BoxDecoration(
          color: color,
          borderRadius: const BorderRadius.all(Radius.circular(_lineHeight)),
        ),
      ),
    );

    return ExcludeSemantics(
      child: AspectRatio(
        aspectRatio: _aspectRatio,
        child: ClipRRect(
          borderRadius: AppRadii.smAll,
          child: ColoredBox(
            color: scheme.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(AppSpacing.sm),
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: reading.page,
                      border: Border.all(
                        color: reading.rule,
                        width: AppSizes.hairline,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        line(reading.rule),
                        line(reading.quranText),
                        Container(
                          color: reading.ayahHighlight,
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.xxs,
                          ),
                          child: line(reading.quranText),
                        ),
                        line(reading.quranText),
                        line(reading.quranText, widthFactor: 0.6),
                      ],
                    ),
                  ),
                ),
                Container(
                  height: AppSpacing.lg,
                  color: scheme.surfaceContainerLow,
                  alignment: Alignment.center,
                  child: Container(
                    width: AppSpacing.xl,
                    height: AppSpacing.sm,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: const BorderRadius.all(
                        Radius.circular(AppRadii.full),
                      ),
                    ),
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
