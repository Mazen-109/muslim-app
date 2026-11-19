import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/routing/app_router.dart';
import '../../core/settings/settings_providers.dart';
import '../../core/settings/settings_repository.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_scaffold.dart';
import '../mushaf/continuous/text_size_sheet.dart';
import 'reciter_setting.dart';
import 'theme_picker.dart';

/// The key of the interface language choice.
const ValueKey<String> localeSettingKey = ValueKey<String>('locale-setting');

/// The key of the black and white video switch.
const ValueKey<String> videoGrayscaleSettingKey = ValueKey<String>(
  'video-grayscale-setting',
);

/// The key of the row that opens the sources page.
const ValueKey<String> sourcesSettingKey = ValueKey<String>('sources-setting');

/// `/settings` (US7): theme, interface language, continuous view text size,
/// default reciter and black and white video, then the way to the sources
/// page. Every change applies at once and is stored on the device.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    const inset = EdgeInsets.symmetric(horizontal: AppSpacing.gutter);

    return AppScaffold(
      title: l10n.navSettings,
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSizes.readingMeasure),
          child: ListView(
            padding: const EdgeInsets.only(bottom: AppSpacing.xl),
            children: <Widget>[
              _SectionHead(l10n.settingsSectionAppearance, first: true),
              _Label(l10n.settingsTheme),
              const Padding(padding: inset, child: ThemePicker()),
              const SizedBox(height: AppSpacing.xl),
              _Label(l10n.settingsLanguage),
              const Padding(padding: inset, child: _LanguageChoice()),
              _SectionHead(l10n.settingsSectionReading),
              Padding(
                padding: inset,
                child: TextSizeControl(title: l10n.settingsTextSize),
              ),
              const SizedBox(height: AppSpacing.sm),
              const Divider(),
              const ReciterSetting(),
              _SectionHead(l10n.settingsSectionVideo),
              const _VideoGrayscaleSwitch(),
              _SectionHead(l10n.settingsSectionAbout),
              ListTile(
                key: sourcesSettingKey,
                leading: const Icon(Icons.info_outline),
                title: Text(l10n.screenSources),
                subtitle: Text(l10n.settingsSourcesHint),
                onTap: () => context.go(AppRoutes.sources),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A section head: a hairline rule (except above the first), then the
/// title, with more space above it than below.
class _SectionHead extends StatelessWidget {
  const _SectionHead(this.title, {this.first = false});

  final String title;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (!first) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          const Divider(),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.xl,
            AppSpacing.gutter,
            AppSpacing.sm,
          ),
          child: Semantics(
            header: true,
            child: Text(
              title,
              style: theme.textTheme.titleSmall!.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The name of one setting above its control.
class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.sm,
        AppSpacing.gutter,
        AppSpacing.md,
      ),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

/// Arabic or English (`locale`). Each language is named in itself.
class _LanguageChoice extends ConsumerWidget {
  const _LanguageChoice();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return SegmentedButton<AppLocale>(
      key: localeSettingKey,
      showSelectedIcon: false,
      segments: <ButtonSegment<AppLocale>>[
        ButtonSegment<AppLocale>(
          value: AppLocale.ar,
          label: Text(l10n.languageArabic),
        ),
        ButtonSegment<AppLocale>(
          value: AppLocale.en,
          label: Text(l10n.languageEnglish),
        ),
      ],
      selected: <AppLocale>{ref.watch(localeProvider)},
      onSelectionChanged: (selection) =>
          ref.read(localeProvider.notifier).set(selection.single),
    );
  }
}

/// "Black and white videos" (`video_grayscale`, read by the video player).
class _VideoGrayscaleSwitch extends ConsumerWidget {
  const _VideoGrayscaleSwitch();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return SwitchListTile(
      key: videoGrayscaleSettingKey,
      secondary: const Icon(Icons.filter_b_and_w_outlined),
      title: Text(l10n.settingsVideoGrayscale),
      subtitle: Text(l10n.settingsVideoGrayscaleHint),
      value: ref.watch(videoGrayscaleProvider),
      onChanged: (value) =>
          ref.read(videoGrayscaleProvider.notifier).set(value),
    );
  }
}
