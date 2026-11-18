import 'package:material_ui/material_ui.dart';

/// Font families declared in `pubspec.yaml`.
abstract final class AppFonts {
  /// Interface text in Arabic and Latin. Never used for Quran text.
  static const String ui = 'NotoSansArabic';

  /// Quran text only (KFGQPC Uthmanic Script Hafs). Never used for anything
  /// else, and never replaced by a fallback font.
  static const String quran = 'UthmanicHafs';

  /// Asset paths, for loading the fonts in tests.
  static const String uiAsset = 'assets/fonts/NotoSansArabic-Variable.ttf';
  static const String quranAsset = 'assets/fonts/UthmanicHafs1Ver18.ttf';
}

/// Font weights used by the type scale. The interface font is variable, so
/// each style also sets the matching `wght` axis value.
abstract final class AppFontWeights {
  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semiBold = FontWeight.w600;
}

/// The type scale (DESIGN.md, Typography).
///
/// Sizes are logical pixels and scale with the reader's text size setting.
/// Arabic needs more line height than Latin, so every role is set looser than
/// the Material default. Letter spacing is always zero: tracking breaks the
/// joins between Arabic letters.
abstract final class AppTypography {
  static TextStyle _ui(double size, double height, FontWeight weight) =>
      TextStyle(
        fontFamily: AppFonts.ui,
        fontSize: size,
        height: height,
        fontWeight: weight,
        fontVariations: <FontVariation>[
          FontVariation('wght', weight.value.toDouble()),
        ],
        letterSpacing: 0,
        leadingDistribution: TextLeadingDistribution.even,
      );

  /// The fifteen Material roles, without colours. [textTheme] adds them.
  static final TextTheme baseTextTheme = TextTheme(
    displayLarge: _ui(48, 1.25, AppFontWeights.regular),
    displayMedium: _ui(40, 1.25, AppFontWeights.regular),
    displaySmall: _ui(34, 1.3, AppFontWeights.regular),
    headlineLarge: _ui(30, 1.35, AppFontWeights.medium),
    headlineMedium: _ui(26, 1.4, AppFontWeights.medium),
    headlineSmall: _ui(23, 1.4, AppFontWeights.medium),
    titleLarge: _ui(21, 1.45, AppFontWeights.semiBold),
    titleMedium: _ui(17, 1.5, AppFontWeights.semiBold),
    titleSmall: _ui(15, 1.5, AppFontWeights.semiBold),
    bodyLarge: _ui(17, 1.7, AppFontWeights.regular),
    bodyMedium: _ui(15, 1.65, AppFontWeights.regular),
    bodySmall: _ui(13, 1.6, AppFontWeights.regular),
    labelLarge: _ui(15, 1.4, AppFontWeights.medium),
    labelMedium: _ui(13, 1.4, AppFontWeights.medium),
    labelSmall: _ui(12, 1.4, AppFontWeights.medium),
  );

  /// The type scale in [text], with [secondary] for the small supporting
  /// roles (body small and label small).
  static TextTheme textTheme({required Color text, required Color secondary}) =>
      baseTextTheme
          .apply(bodyColor: text, displayColor: text)
          .copyWith(
            bodySmall: baseTextTheme.bodySmall!.copyWith(color: secondary),
            labelSmall: baseTextTheme.labelSmall!.copyWith(color: secondary),
          );

  /// The default Quran text size in continuous view, before the reader's
  /// font scale. The page view computes its own size per page.
  static const double quranFontSize = 26;

  /// Quran text: the Uthmanic Hafs family and nothing else. The empty
  /// fallback list means a missing glyph shows as missing instead of being
  /// drawn in another font. No colour: take it from [AppColors.quranText].
  static const TextStyle quran = TextStyle(
    fontFamily: AppFonts.quran,
    fontFamilyFallback: <String>[],
    fontSize: quranFontSize,
    height: 2.0,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    wordSpacing: 0,
    leadingDistribution: TextLeadingDistribution.even,
  );
}
