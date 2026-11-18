import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:muslim/core/settings/settings_repository.dart';
import 'package:muslim/core/theme/app_colors.dart';
import 'package:muslim/core/theme/app_spacing.dart';
import 'package:muslim/core/theme/app_theme.dart';
import 'package:muslim/core/theme/app_typography.dart';

// A specimen of each theme: colour roles, the type scale and a few themed
// components. The labels are neutral interface words only; the specimen holds
// no Quran text and no other religious content.

const Size _logicalSize = Size(400, 1010);
const double _pixelRatio = 2;

Future<void> _loadUiFont() async {
  final loader = FontLoader(AppFonts.ui)
    ..addFont(rootBundle.load(AppFonts.uiAsset));
  await loader.load();
}

String _hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

class _Specimen extends StatelessWidget {
  const _Specimen({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = theme.textTheme;
    final reading = AppColors.of(context);

    final swatches = <(String, Color)>[
      ('surface', scheme.surface),
      ('container', scheme.surfaceContainer),
      ('container highest', scheme.surfaceContainerHighest),
      ('page', reading.page),
      ('text', scheme.onSurface),
      ('text secondary', scheme.onSurfaceVariant),
      ('Quran text', reading.quranText),
      ('accent', scheme.primary),
      ('accent container', scheme.primaryContainer),
      ('ayah highlight', reading.ayahHighlight),
      ('rule', reading.rule),
      ('outline', scheme.outline),
    ];

    final scale = <(String, TextStyle?)>[
      ('displaySmall', text.displaySmall),
      ('headlineLarge', text.headlineLarge),
      ('headlineSmall', text.headlineSmall),
      ('titleLarge', text.titleLarge),
      ('titleMedium', text.titleMedium),
      ('bodyLarge', text.bodyLarge),
      ('bodyMedium', text.bodyMedium),
      ('bodySmall', text.bodySmall),
      ('labelLarge', text.labelLarge),
      ('labelSmall', text.labelSmall),
    ];

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.gutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(title, style: text.headlineSmall),
            const SizedBox(height: AppSpacing.lg),
            const Divider(),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                for (final (name, color) in swatches)
                  SizedBox(
                    width: 116,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Container(
                          height: 36,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: AppRadii.smAll,
                            border: Border.all(
                              color: scheme.outlineVariant,
                              width: AppSizes.hairline,
                            ),
                          ),
                        ),
                        Text(
                          name,
                          style: text.labelMedium,
                          textDirection: TextDirection.ltr,
                        ),
                        Text(
                          _hex(color),
                          style: text.labelSmall,
                          textDirection: TextDirection.ltr,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            const Divider(),
            const SizedBox(height: AppSpacing.sm),
            for (final (name, style) in scale)
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: <Widget>[
                  Expanded(child: Text('الإعدادات Settings', style: style)),
                  Text(
                    '$name ${style!.fontSize!.toStringAsFixed(0)}',
                    style: text.labelSmall,
                    textDirection: TextDirection.ltr,
                  ),
                ],
              ),
            const SizedBox(height: AppSpacing.lg),
            const Divider(),
            const ListTile(
              title: Text('حجم الخط'),
              subtitle: Text('Font size'),
              trailing: Text('100%'),
            ),
            const Divider(),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                FilledButton(onPressed: () {}, child: const Text('متابعة')),
                OutlinedButton(onPressed: () {}, child: const Text('إلغاء')),
                TextButton(onPressed: () {}, child: const Text('المصادر')),
                Switch(value: true, onChanged: (_) {}),
                Switch(value: false, onChanged: (_) {}),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Slider(value: 0.4, onChanged: (_) {}),
            const SizedBox(height: AppSpacing.sm),
            const LinearProgressIndicator(value: 0.6),
          ],
        ),
      ),
    );
  }
}

void main() {
  setUpAll(_loadUiFont);

  const titles = <ThemePreference, String>{
    ThemePreference.light: 'فاتح  Light',
    ThemePreference.night: 'ليلي  Night',
    ThemePreference.blackOnWhite: 'أسود على أبيض  Black on white',
    ThemePreference.whiteOnBlack: 'أبيض على أسود  White on black',
  };

  for (final preference in ThemePreference.values) {
    testWidgets('specimen of the ${preference.storageValue} theme', (
      tester,
    ) async {
      tester.view.physicalSize = _logicalSize * _pixelRatio;
      tester.view.devicePixelRatio = _pixelRatio;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.of(preference),
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: _Specimen(title: titles[preference]!),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(_Specimen),
        matchesGoldenFile('theme_specimen_${preference.storageValue}.png'),
      );
    });
  }
}
