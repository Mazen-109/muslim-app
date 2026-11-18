import 'package:material_ui/material_ui.dart';

/// Every colour role of one theme (DESIGN.md, Colors).
///
/// The four palettes below are the only place colour values are written.
/// Widgets read colours from `Theme.of(context).colorScheme` and from the
/// [AppColors] extension, never from these constants directly.
@immutable
class AppPalette {
  const AppPalette({
    required this.brightness,
    required this.surface,
    required this.surfaceContainerLowest,
    required this.surfaceContainerLow,
    required this.surfaceContainer,
    required this.surfaceContainerHigh,
    required this.surfaceContainerHighest,
    required this.text,
    required this.textSecondary,
    required this.accent,
    required this.onAccent,
    required this.accentContainer,
    required this.onAccentContainer,
    required this.neutralAccent,
    required this.onNeutralAccent,
    required this.neutralAccentContainer,
    required this.onNeutralAccentContainer,
    required this.outline,
    required this.outlineVariant,
    required this.error,
    required this.onError,
    required this.errorContainer,
    required this.onErrorContainer,
    required this.inverseSurface,
    required this.onInverseSurface,
    required this.inverseAccent,
    required this.page,
    required this.quranText,
    required this.ayahHighlight,
    required this.rule,
    required this.scrim,
  });

  final Brightness brightness;

  /// The ground behind all chrome.
  final Color surface;
  final Color surfaceContainerLowest;
  final Color surfaceContainerLow;
  final Color surfaceContainer;
  final Color surfaceContainerHigh;
  final Color surfaceContainerHighest;

  /// Body text and icons.
  final Color text;

  /// Secondary text: metadata, captions, supporting lines.
  final Color textSecondary;

  /// Lapis ink: selection, the current position, links. Used sparingly.
  final Color accent;
  final Color onAccent;
  final Color accentContainer;
  final Color onAccentContainer;

  /// Slate: secondary and tertiary roles. Deliberately not a second hue.
  final Color neutralAccent;
  final Color onNeutralAccent;
  final Color neutralAccentContainer;
  final Color onNeutralAccentContainer;

  final Color outline;
  final Color outlineVariant;
  final Color error;
  final Color onError;
  final Color errorContainer;
  final Color onErrorContainer;
  final Color inverseSurface;
  final Color onInverseSurface;
  final Color inverseAccent;

  /// The Mushaf page: the brightest (or, at night, the calmest) sheet.
  final Color page;

  /// Quran text on [page].
  final Color quranText;

  /// The wash behind the ayah being recited or selected.
  final Color ayahHighlight;

  /// Hairline rules: running heads, list separators, page edges.
  final Color rule;

  final Color scrim;

  /// Lapis ink on a cool paper ground.
  static const AppPalette light = AppPalette(
    brightness: Brightness.light,
    surface: Color(0xFFF4F5F6),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFEEF0F2),
    surfaceContainer: Color(0xFFE8EBED),
    surfaceContainerHigh: Color(0xFFE3E6E9),
    surfaceContainerHighest: Color(0xFFDDE1E4),
    text: Color(0xFF15171A),
    textSecondary: Color(0xFF40454B),
    accent: Color(0xFF22457D),
    onAccent: Color(0xFFFFFFFF),
    accentContainer: Color(0xFFD9E2F1),
    onAccentContainer: Color(0xFF0E2547),
    neutralAccent: Color(0xFF3E4752),
    onNeutralAccent: Color(0xFFFFFFFF),
    neutralAccentContainer: Color(0xFFE1E5EA),
    onNeutralAccentContainer: Color(0xFF1B2129),
    outline: Color(0xFF70767E),
    outlineVariant: Color(0xFFC3C8CE),
    error: Color(0xFF861B12),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFF7DEDA),
    onErrorContainer: Color(0xFF4A0F09),
    inverseSurface: Color(0xFF2B2E32),
    onInverseSurface: Color(0xFFEEF0F2),
    inverseAccent: Color(0xFFA8BEE4),
    page: Color(0xFFFFFFFF),
    quranText: Color(0xFF111316),
    ayahHighlight: Color(0xFFE1E8F4),
    rule: Color(0xFFD3D7DB),
    scrim: Color(0xFF000000),
  );

  /// Warm-grey ink on a dim ground, for reading in the dark.
  static const AppPalette night = AppPalette(
    brightness: Brightness.dark,
    surface: Color(0xFF121315),
    surfaceContainerLowest: Color(0xFF0D0E10),
    surfaceContainerLow: Color(0xFF17181B),
    surfaceContainer: Color(0xFF1B1D20),
    surfaceContainerHigh: Color(0xFF202225),
    surfaceContainerHighest: Color(0xFF26282B),
    text: Color(0xFFE3DFD7),
    textSecondary: Color(0xFFBEBAB2),
    accent: Color(0xFFA8BEE4),
    onAccent: Color(0xFF0E2547),
    accentContainer: Color(0xFF233452),
    onAccentContainer: Color(0xFFD9E2F1),
    neutralAccent: Color(0xFFBCC3CC),
    onNeutralAccent: Color(0xFF1B2129),
    neutralAccentContainer: Color(0xFF30353C),
    onNeutralAccentContainer: Color(0xFFE1E5EA),
    outline: Color(0xFF8B8E93),
    outlineVariant: Color(0xFF3A3D41),
    error: Color(0xFFF0A39A),
    onError: Color(0xFF4A0F09),
    errorContainer: Color(0xFF5A1B14),
    onErrorContainer: Color(0xFFFADAD5),
    inverseSurface: Color(0xFFE3DFD7),
    onInverseSurface: Color(0xFF26282B),
    inverseAccent: Color(0xFF22457D),
    page: Color(0xFF17181B),
    quranText: Color(0xFFE3DFD7),
    ayahHighlight: Color(0xFF25303F),
    rule: Color(0xFF34373B),
    scrim: Color(0xFF000000),
  );

  /// Black, white and greys only.
  static const AppPalette blackOnWhite = AppPalette(
    brightness: Brightness.light,
    surface: Color(0xFFFFFFFF),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFF4F4F4),
    surfaceContainer: Color(0xFFEDEDED),
    surfaceContainerHigh: Color(0xFFE6E6E6),
    surfaceContainerHighest: Color(0xFFE0E0E0),
    text: Color(0xFF000000),
    textSecondary: Color(0xFF3B3B3B),
    accent: Color(0xFF000000),
    onAccent: Color(0xFFFFFFFF),
    accentContainer: Color(0xFFE0E0E0),
    onAccentContainer: Color(0xFF000000),
    neutralAccent: Color(0xFF3B3B3B),
    onNeutralAccent: Color(0xFFFFFFFF),
    neutralAccentContainer: Color(0xFFEDEDED),
    onNeutralAccentContainer: Color(0xFF000000),
    outline: Color(0xFF6E6E6E),
    outlineVariant: Color(0xFFC4C4C4),
    error: Color(0xFF000000),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFE0E0E0),
    onErrorContainer: Color(0xFF000000),
    inverseSurface: Color(0xFF000000),
    onInverseSurface: Color(0xFFFFFFFF),
    inverseAccent: Color(0xFFFFFFFF),
    page: Color(0xFFFFFFFF),
    quranText: Color(0xFF000000),
    ayahHighlight: Color(0xFFE6E6E6),
    rule: Color(0xFFCCCCCC),
    scrim: Color(0xFF000000),
  );

  /// White and greys on true black, for OLED screens.
  static const AppPalette whiteOnBlack = AppPalette(
    brightness: Brightness.dark,
    surface: Color(0xFF000000),
    surfaceContainerLowest: Color(0xFF000000),
    surfaceContainerLow: Color(0xFF0F0F0F),
    surfaceContainer: Color(0xFF161616),
    surfaceContainerHigh: Color(0xFF1E1E1E),
    surfaceContainerHighest: Color(0xFF262626),
    text: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFC2C2C2),
    accent: Color(0xFFFFFFFF),
    onAccent: Color(0xFF000000),
    accentContainer: Color(0xFF333333),
    onAccentContainer: Color(0xFFFFFFFF),
    neutralAccent: Color(0xFFC2C2C2),
    onNeutralAccent: Color(0xFF000000),
    neutralAccentContainer: Color(0xFF262626),
    onNeutralAccentContainer: Color(0xFFFFFFFF),
    outline: Color(0xFF8C8C8C),
    outlineVariant: Color(0xFF3D3D3D),
    error: Color(0xFFFFFFFF),
    onError: Color(0xFF000000),
    errorContainer: Color(0xFF333333),
    onErrorContainer: Color(0xFFFFFFFF),
    inverseSurface: Color(0xFFFFFFFF),
    onInverseSurface: Color(0xFF000000),
    inverseAccent: Color(0xFF000000),
    page: Color(0xFF000000),
    quranText: Color(0xFFFFFFFF),
    ayahHighlight: Color(0xFF2A2A2A),
    rule: Color(0xFF333333),
    scrim: Color(0xFF000000),
  );

  /// The Material colour scheme, with every role set explicitly so that no
  /// role falls back to a Material default hue.
  ColorScheme get colorScheme => ColorScheme(
    brightness: brightness,
    primary: accent,
    onPrimary: onAccent,
    primaryContainer: accentContainer,
    onPrimaryContainer: onAccentContainer,
    primaryFixed: accentContainer,
    primaryFixedDim: accentContainer,
    onPrimaryFixed: onAccentContainer,
    onPrimaryFixedVariant: onAccentContainer,
    secondary: neutralAccent,
    onSecondary: onNeutralAccent,
    secondaryContainer: neutralAccentContainer,
    onSecondaryContainer: onNeutralAccentContainer,
    secondaryFixed: neutralAccentContainer,
    secondaryFixedDim: neutralAccentContainer,
    onSecondaryFixed: onNeutralAccentContainer,
    onSecondaryFixedVariant: onNeutralAccentContainer,
    tertiary: neutralAccent,
    onTertiary: onNeutralAccent,
    tertiaryContainer: neutralAccentContainer,
    onTertiaryContainer: onNeutralAccentContainer,
    tertiaryFixed: neutralAccentContainer,
    tertiaryFixedDim: neutralAccentContainer,
    onTertiaryFixed: onNeutralAccentContainer,
    onTertiaryFixedVariant: onNeutralAccentContainer,
    error: error,
    onError: onError,
    errorContainer: errorContainer,
    onErrorContainer: onErrorContainer,
    surface: surface,
    onSurface: text,
    onSurfaceVariant: textSecondary,
    surfaceDim: surface,
    surfaceBright: surfaceContainerLowest,
    surfaceContainerLowest: surfaceContainerLowest,
    surfaceContainerLow: surfaceContainerLow,
    surfaceContainer: surfaceContainer,
    surfaceContainerHigh: surfaceContainerHigh,
    surfaceContainerHighest: surfaceContainerHighest,
    outline: outline,
    outlineVariant: outlineVariant,
    shadow: scrim,
    scrim: scrim,
    inverseSurface: inverseSurface,
    onInverseSurface: onInverseSurface,
    inversePrimary: inverseAccent,
    surfaceTint: surface,
  );

  /// The reading roles that have no Material equivalent.
  AppColors get extension => AppColors(
    page: page,
    quranText: quranText,
    ayahHighlight: ayahHighlight,
    rule: rule,
  );
}

/// Reading colour roles, read with `AppColors.of(context)`.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.page,
    required this.quranText,
    required this.ayahHighlight,
    required this.rule,
  });

  /// The Mushaf page ground.
  final Color page;

  /// Quran text on [page] and on [ayahHighlight].
  final Color quranText;

  /// The wash behind the ayah being recited or selected.
  final Color ayahHighlight;

  /// Hairline rules.
  final Color rule;

  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>()!;

  @override
  AppColors copyWith({
    Color? page,
    Color? quranText,
    Color? ayahHighlight,
    Color? rule,
  }) => AppColors(
    page: page ?? this.page,
    quranText: quranText ?? this.quranText,
    ayahHighlight: ayahHighlight ?? this.ayahHighlight,
    rule: rule ?? this.rule,
  );

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    return AppColors(
      page: Color.lerp(page, other.page, t)!,
      quranText: Color.lerp(quranText, other.quranText, t)!,
      ayahHighlight: Color.lerp(ayahHighlight, other.ayahHighlight, t)!,
      rule: Color.lerp(rule, other.rule, t)!,
    );
  }
}
