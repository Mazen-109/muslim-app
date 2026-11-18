import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:muslim/core/settings/settings_repository.dart';
import 'package:muslim/core/theme/app_colors.dart';
import 'package:muslim/core/theme/app_spacing.dart';
import 'package:muslim/core/theme/app_theme.dart';
import 'package:muslim/core/theme/app_typography.dart';
import 'package:muslim/data/sources_registry.dart';

/// WCAG 2.x relative luminance of [color], ignoring alpha.
double _luminance(Color color) {
  double channel(double c) =>
      c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(color.r) +
      0.7152 * channel(color.g) +
      0.0722 * channel(color.b);
}

/// WCAG 2.x contrast ratio between two opaque colours, from 1 to 21.
double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

String _hex(Color c) =>
    '#${c.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';

/// Every surface that text is drawn on, with a name for failure messages.
Map<String, Color> _textBackgrounds(ThemeData theme) {
  final s = theme.colorScheme;
  return <String, Color>{
    'scaffold': theme.scaffoldBackgroundColor,
    'surface': s.surface,
    'surfaceContainerLowest': s.surfaceContainerLowest,
    'surfaceContainerLow': s.surfaceContainerLow,
    'surfaceContainer': s.surfaceContainer,
    'surfaceContainerHigh': s.surfaceContainerHigh,
    'surfaceContainerHighest': s.surfaceContainerHighest,
    'page': theme.extension<AppColors>()!.page,
  };
}

/// Collects every [Color] reachable from [root] through its diagnostics:
/// colour properties, nested themes, text and icon styles, borders, and
/// widget-state properties resolved in the common states.
List<(String, Color)> _allColors(Diagnosticable root) {
  const stateSets = <Set<WidgetState>>[
    <WidgetState>{},
    <WidgetState>{WidgetState.selected},
    <WidgetState>{WidgetState.disabled},
    <WidgetState>{WidgetState.pressed},
    <WidgetState>{WidgetState.hovered},
    <WidgetState>{WidgetState.focused},
    <WidgetState>{WidgetState.error},
    <WidgetState>{WidgetState.selected, WidgetState.pressed},
    <WidgetState>{WidgetState.selected, WidgetState.disabled},
  ];
  final found = <(String, Color)>[];
  final seen = Set<Object>.identity();

  void visit(String path, Object? value, int depth) {
    if (value == null || depth > 8) return;
    switch (value) {
      case Color():
        found.add((path, value));
      case BorderSide():
        visit('$path.color', value.color, depth + 1);
      case OutlinedBorder():
        visit('$path.side', value.side, depth + 1);
      case InputBorder():
        visit('$path.borderSide', value.borderSide, depth + 1);
      case BoxDecoration():
        visit('$path.color', value.color, depth + 1);
      case WidgetStateProperty<Object?>():
        for (final states in stateSets) {
          visit('$path$states', value.resolve(states), depth + 1);
        }
      case Diagnosticable():
        if (!seen.add(value)) return;
        for (final property in value.toDiagnosticsNode().getProperties()) {
          visit('$path.${property.name}', property.value, depth + 1);
        }
      case Iterable<Object?>():
        var i = 0;
        for (final item in value) {
          visit('$path[$i]', item, depth + 1);
          i++;
        }
    }
  }

  visit('theme', root, 0);
  if (root is ThemeData) {
    // Theme extensions do not appear in ThemeData's diagnostics.
    final colors = root.extension<AppColors>()!;
    visit('theme.extensions.page', colors.page, 1);
    visit('theme.extensions.quranText', colors.quranText, 1);
    visit('theme.extensions.ayahHighlight', colors.ayahHighlight, 1);
    visit('theme.extensions.rule', colors.rule, 1);
  }
  return found;
}

void main() {
  const allPreferences = ThemePreference.values;

  group('contrast (at least 7:1 in every theme)', () {
    for (final preference in allPreferences) {
      group(preference.storageValue, () {
        final theme = AppTheme.of(preference);
        final scheme = theme.colorScheme;
        final colors = theme.extension<AppColors>()!;

        test('body text', () {
          expect(theme.textTheme.bodyLarge!.color, scheme.onSurface);
          expect(theme.textTheme.bodyMedium!.color, scheme.onSurface);
          for (final MapEntry(:key, :value) in _textBackgrounds(
            theme,
          ).entries) {
            final ratio = _contrast(scheme.onSurface, value);
            expect(
              ratio,
              greaterThanOrEqualTo(7),
              reason:
                  'body ${_hex(scheme.onSurface)} on $key ${_hex(value)}: '
                  '${ratio.toStringAsFixed(2)}',
            );
          }
        });

        test('secondary text', () {
          expect(theme.textTheme.bodySmall!.color, scheme.onSurfaceVariant);
          expect(
            theme.listTileTheme.subtitleTextStyle!.color,
            scheme.onSurfaceVariant,
          );
          for (final MapEntry(:key, :value) in _textBackgrounds(
            theme,
          ).entries) {
            final ratio = _contrast(scheme.onSurfaceVariant, value);
            expect(
              ratio,
              greaterThanOrEqualTo(7),
              reason:
                  'secondary ${_hex(scheme.onSurfaceVariant)} on $key '
                  '${_hex(value)}: ${ratio.toStringAsFixed(2)}',
            );
          }
        });

        test('Quran text, on the page and on the ayah highlight', () {
          final quran = AppTheme.quranTextStyle(theme).color!;
          expect(quran, colors.quranText);
          for (final (name, background) in <(String, Color)>[
            ('page', colors.page),
            ('ayahHighlight', colors.ayahHighlight),
          ]) {
            final ratio = _contrast(quran, background);
            expect(
              ratio,
              greaterThanOrEqualTo(7),
              reason:
                  'Quran ${_hex(quran)} on $name ${_hex(background)}: '
                  '${ratio.toStringAsFixed(2)}',
            );
          }
        });

        test('all colours are opaque where text sits', () {
          for (final MapEntry(:key, :value) in _textBackgrounds(
            theme,
          ).entries) {
            expect(value.a, 1.0, reason: key);
          }
          expect(scheme.onSurface.a, 1.0);
          expect(scheme.onSurfaceVariant.a, 1.0);
          expect(colors.quranText.a, 1.0);
        });
      });
    }

    test('the contrast function matches known WCAG values', () {
      expect(
        _contrast(const Color(0xFF000000), const Color(0xFFFFFFFF)),
        closeTo(21, 1e-9),
      );
      expect(
        _contrast(const Color(0xFF777777), const Color(0xFFFFFFFF)),
        closeTo(4.48, 0.01),
      );
      expect(
        _contrast(const Color(0xFFFFFFFF), const Color(0xFFFFFFFF)),
        closeTo(1, 1e-9),
      );
    });
  });

  group('black and white themes', () {
    for (final preference in <ThemePreference>[
      ThemePreference.blackOnWhite,
      ThemePreference.whiteOnBlack,
    ]) {
      test('${preference.storageValue} has no chromatic colour anywhere', () {
        final colors = _allColors(AppTheme.of(preference));
        // The walk must actually reach the colour scheme, the reading
        // colours and the component themes.
        expect(colors.length, greaterThan(150));
        final paths = colors.map((c) => c.$1).join('\n');
        expect(paths, contains('colorScheme.primary'));
        expect(paths, contains('extensions'));
        expect(paths, contains('navigationBarTheme'));
        for (final (path, color) in colors) {
          final argb = color.toARGB32();
          final r = (argb >> 16) & 0xFF;
          final g = (argb >> 8) & 0xFF;
          final b = argb & 0xFF;
          expect(r == g && g == b, isTrue, reason: '$path is ${_hex(color)}');
        }
      });
    }

    test('the walk does find chroma in a colour theme', () {
      final chromatic = _allColors(AppTheme.light).where((entry) {
        final argb = entry.$2.toARGB32();
        return ((argb >> 16) & 0xFF) != (argb & 0xFF);
      });
      expect(chromatic, isNotEmpty);
    });

    test('white_on_black uses a true black background', () {
      final theme = AppTheme.whiteOnBlack;
      const black = Color(0xFF000000);
      expect(theme.scaffoldBackgroundColor, black);
      expect(theme.colorScheme.surface, black);
      expect(theme.canvasColor, black);
      expect(theme.extension<AppColors>()!.page, black);
    });
  });

  group('Quran text style', () {
    void expectUthmanicOnly(TextStyle style) {
      expect(style.fontFamily, 'UthmanicHafs');
      expect(style.fontFamilyFallback, isNotNull);
      expect(style.fontFamilyFallback, isEmpty);
      expect(style.letterSpacing, 0);
    }

    test('uses only the UthmanicHafs family, with no fallback', () {
      expect(AppFonts.quran, 'UthmanicHafs');
      expectUthmanicOnly(AppTypography.quran);
    });

    test('keeps the family and the empty fallback in every theme', () {
      for (final preference in allPreferences) {
        expectUthmanicOnly(AppTheme.quranTextStyle(AppTheme.of(preference)));
      }
    });

    test('keeps the empty fallback when merged over an interface style', () {
      final merged = AppTheme.light.textTheme.bodyLarge!.merge(
        AppTheme.quranTextStyle(AppTheme.light),
      );
      expectUthmanicOnly(merged);
    });

    test('interface styles never use the Quran font', () {
      for (final preference in allPreferences) {
        final theme = AppTheme.of(preference);
        for (final style in <TextStyle?>[
          theme.textTheme.displayLarge,
          theme.textTheme.headlineMedium,
          theme.textTheme.titleLarge,
          theme.textTheme.bodyLarge,
          theme.textTheme.bodySmall,
          theme.textTheme.labelLarge,
          theme.textTheme.labelSmall,
        ]) {
          expect(style!.fontFamily, AppFonts.ui);
          expect(style.letterSpacing, 0);
        }
      }
    });
  });

  group('theme mapping', () {
    test('maps every ThemePreference to its theme', () {
      expect(AppTheme.of(ThemePreference.light), same(AppTheme.light));
      expect(AppTheme.of(ThemePreference.night), same(AppTheme.night));
      expect(
        AppTheme.of(ThemePreference.blackOnWhite),
        same(AppTheme.blackOnWhite),
      );
      expect(
        AppTheme.of(ThemePreference.whiteOnBlack),
        same(AppTheme.whiteOnBlack),
      );
      expect(allPreferences.map(AppTheme.of).toSet().length, 4);
    });

    test('maps every ThemePreference to its palette and brightness', () {
      expect(AppTheme.paletteOf(ThemePreference.light), AppPalette.light);
      expect(AppTheme.paletteOf(ThemePreference.night), AppPalette.night);
      expect(
        AppTheme.paletteOf(ThemePreference.blackOnWhite),
        AppPalette.blackOnWhite,
      );
      expect(
        AppTheme.paletteOf(ThemePreference.whiteOnBlack),
        AppPalette.whiteOnBlack,
      );
      expect(AppTheme.light.brightness, Brightness.light);
      expect(AppTheme.night.brightness, Brightness.dark);
      expect(AppTheme.blackOnWhite.brightness, Brightness.light);
      expect(AppTheme.whiteOnBlack.brightness, Brightness.dark);
      for (final preference in allPreferences) {
        expect(
          AppTheme.of(preference).colorScheme.surface,
          AppTheme.paletteOf(preference).surface,
        );
      }
    });
  });

  group('touch targets', () {
    test('component themes ask for at least 48 by 48 dp', () {
      for (final preference in allPreferences) {
        final theme = AppTheme.of(preference);
        expect(theme.materialTapTargetSize, MaterialTapTargetSize.padded);
        for (final style in <ButtonStyle?>[
          theme.filledButtonTheme.style,
          theme.elevatedButtonTheme.style,
          theme.outlinedButtonTheme.style,
          theme.textButtonTheme.style,
          theme.iconButtonTheme.style,
          theme.segmentedButtonTheme.style,
        ]) {
          final minimum = style!.minimumSize!.resolve(<WidgetState>{})!;
          expect(minimum.width, greaterThanOrEqualTo(AppSizes.minTouchTarget));
          expect(minimum.height, greaterThanOrEqualTo(AppSizes.minTouchTarget));
          expect(style.tapTargetSize, MaterialTapTargetSize.padded);
        }
        expect(
          theme.navigationBarTheme.height,
          greaterThanOrEqualTo(AppSizes.minTouchTarget),
        );
        expect(
          theme.listTileTheme.minTileHeight,
          greaterThanOrEqualTo(AppSizes.minTouchTarget),
        );
      }
    });

    testWidgets('buttons render at least 48 by 48 dp', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: Column(
                children: <Widget>[
                  FilledButton(onPressed: () {}, child: const Text('a')),
                  OutlinedButton(onPressed: () {}, child: const Text('a')),
                  TextButton(onPressed: () {}, child: const Text('a')),
                  ElevatedButton(onPressed: () {}, child: const Text('a')),
                  IconButton(
                    onPressed: () {},
                    icon: const SizedBox.square(dimension: 8),
                  ),
                  Switch(value: true, onChanged: (_) {}),
                  Checkbox(value: true, onChanged: (_) {}),
                ],
              ),
            ),
          ),
        ),
      );
      for (final type in <Type>[
        FilledButton,
        OutlinedButton,
        TextButton,
        ElevatedButton,
        IconButton,
        Switch,
        Checkbox,
      ]) {
        final size = tester.getSize(find.byType(type));
        expect(size.width, greaterThanOrEqualTo(48), reason: '$type');
        expect(size.height, greaterThanOrEqualTo(48), reason: '$type');
      }
    });
  });

  group('interface font', () {
    test('is declared in pubspec.yaml and registered in sources.json', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final declaration = RegExp(
        r'^\s*-\s*family:\s*' +
            AppFonts.ui +
            r'\s*\n\s*fonts:\s*\n\s*-\s*asset:\s*' +
            RegExp.escape(AppFonts.uiAsset) +
            r'\s*$',
        multiLine: true,
      );
      expect(declaration.hasMatch(pubspec), isTrue);

      final registry = SourcesRegistry.parse(
        File(sourcesRegistryAsset).readAsStringSync(),
      );
      final entry = registry.sources.where(
        (s) => s.assetPath == AppFonts.uiAsset,
      );
      expect(entry, hasLength(1));
      expect(entry.single.kind, SourceKind.font);
      expect(entry.single.sha256, isNotNull);
      expect(entry.single.license, contains('Open Font License'));
      expect(File('assets/fonts/NotoSansArabic-OFL.txt').existsSync(), isTrue);
    });
  });
}
