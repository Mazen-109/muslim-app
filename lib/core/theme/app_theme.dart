import 'package:material_ui/material_ui.dart';

import '../settings/settings_repository.dart';
import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// The four app themes (spec FR-022) built from the design tokens.
abstract final class AppTheme {
  static final ThemeData light = build(AppPalette.light);
  static final ThemeData night = build(AppPalette.night);
  static final ThemeData blackOnWhite = build(AppPalette.blackOnWhite);
  static final ThemeData whiteOnBlack = build(AppPalette.whiteOnBlack);

  /// The theme for the reader's [preference].
  static ThemeData of(ThemePreference preference) => switch (preference) {
    ThemePreference.light => light,
    ThemePreference.night => night,
    ThemePreference.blackOnWhite => blackOnWhite,
    ThemePreference.whiteOnBlack => whiteOnBlack,
  };

  /// The palette behind the reader's [preference].
  static AppPalette paletteOf(ThemePreference preference) =>
      switch (preference) {
        ThemePreference.light => AppPalette.light,
        ThemePreference.night => AppPalette.night,
        ThemePreference.blackOnWhite => AppPalette.blackOnWhite,
        ThemePreference.whiteOnBlack => AppPalette.whiteOnBlack,
      };

  /// Quran text in [theme]'s Quran colour.
  static TextStyle quranTextStyle(ThemeData theme) => AppTypography.quran
      .copyWith(color: theme.extension<AppColors>()!.quranText);

  /// Builds a theme from [p]. Every colour comes from the palette, so a black
  /// and white palette yields a theme with no chromatic colour anywhere.
  static ThemeData build(AppPalette p) {
    final scheme = p.colorScheme;
    final textTheme = AppTypography.textTheme(
      text: p.text,
      secondary: p.textSecondary,
    );
    final labelLarge = textTheme.labelLarge!;
    Color overlay(double opacity) => p.text.withValues(alpha: opacity);

    const buttonMinimumSize = Size(64, AppSizes.minTouchTarget);
    const buttonPadding = EdgeInsets.symmetric(horizontal: AppSpacing.xl);
    const buttonShape = RoundedRectangleBorder(borderRadius: AppRadii.mdAll);

    return ThemeData(
      useMaterial3: true,
      brightness: p.brightness,
      colorScheme: scheme,
      extensions: <ThemeExtension<dynamic>>[p.extension],
      fontFamily: AppFonts.ui,
      textTheme: textTheme,
      primaryTextTheme: AppTypography.textTheme(
        text: p.onAccent,
        secondary: p.onAccent,
      ),
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      splashFactory: InkRipple.splashFactory,

      // Theme-level colours, set explicitly so none falls back to a
      // Material default hue.
      canvasColor: p.surface,
      scaffoldBackgroundColor: p.surface,
      cardColor: p.surfaceContainerLow,
      dividerColor: p.rule,
      disabledColor: overlay(0.38),
      focusColor: overlay(0.12),
      highlightColor: overlay(0.08),
      hoverColor: overlay(0.08),
      splashColor: overlay(0.12),
      hintColor: p.textSecondary,
      primaryColor: p.accent,
      primaryColorDark: p.onAccentContainer,
      primaryColorLight: p.accentContainer,
      secondaryHeaderColor: p.surfaceContainerLow,
      shadowColor: p.scrim,
      unselectedWidgetColor: p.textSecondary,
      iconTheme: IconThemeData(color: p.text, size: AppSizes.icon),
      primaryIconTheme: IconThemeData(color: p.onAccent, size: AppSizes.icon),

      appBarTheme: AppBarThemeData(
        backgroundColor: p.surface,
        foregroundColor: p.text,
        surfaceTintColor: p.surface,
        shadowColor: p.scrim,
        elevation: AppElevation.level0,
        scrolledUnderElevation: AppElevation.level0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
        toolbarHeight: 64,
        iconTheme: IconThemeData(color: p.text, size: AppSizes.icon),
        actionsIconTheme: IconThemeData(color: p.text, size: AppSizes.icon),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: AppSizes.navigationBarHeight,
        backgroundColor: p.surfaceContainerLow,
        surfaceTintColor: p.surfaceContainerLow,
        shadowColor: p.scrim,
        elevation: AppElevation.level0,
        indicatorColor: p.accentContainer,
        indicatorShape: const StadiumBorder(),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => textTheme.labelMedium!.copyWith(
            color: states.contains(WidgetState.selected)
                ? p.text
                : p.textSecondary,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: AppSizes.icon,
            color: states.contains(WidgetState.selected)
                ? p.onAccentContainer
                : p.textSecondary,
          ),
        ),
      ),
      // The legacy button theme still defaults to a Material blue.
      buttonTheme: ButtonThemeData(
        colorScheme: scheme,
        buttonColor: p.surfaceContainerHigh,
        disabledColor: overlay(0.12),
        focusColor: overlay(0.12),
        hoverColor: overlay(0.08),
        highlightColor: overlay(0.08),
        splashColor: overlay(0.12),
        minWidth: AppSizes.minTouchTarget,
        height: AppSizes.minTouchTarget,
        shape: buttonShape,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: buttonMinimumSize,
          padding: buttonPadding,
          shape: buttonShape,
          textStyle: labelLarge,
          tapTargetSize: MaterialTapTargetSize.padded,
          backgroundColor: p.accent,
          foregroundColor: p.onAccent,
          disabledBackgroundColor: overlay(0.12),
          disabledForegroundColor: overlay(0.38),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: buttonMinimumSize,
          padding: buttonPadding,
          shape: buttonShape,
          textStyle: labelLarge,
          tapTargetSize: MaterialTapTargetSize.padded,
          elevation: AppElevation.level0,
          backgroundColor: p.surfaceContainerHigh,
          foregroundColor: p.text,
          shadowColor: p.scrim,
          surfaceTintColor: p.surfaceContainerHigh,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: buttonMinimumSize,
          padding: buttonPadding,
          shape: buttonShape,
          textStyle: labelLarge,
          tapTargetSize: MaterialTapTargetSize.padded,
          foregroundColor: p.text,
          side: BorderSide(color: p.outline, width: AppSizes.hairline),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(
            AppSizes.minTouchTarget,
            AppSizes.minTouchTarget,
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          shape: buttonShape,
          textStyle: labelLarge,
          tapTargetSize: MaterialTapTargetSize.padded,
          foregroundColor: p.accent,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size.square(AppSizes.minTouchTarget),
          tapTargetSize: MaterialTapTargetSize.padded,
          iconSize: AppSizes.icon,
          foregroundColor: p.text,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          minimumSize: const Size(
            AppSizes.minTouchTarget,
            AppSizes.minTouchTarget,
          ),
          tapTargetSize: MaterialTapTargetSize.padded,
          textStyle: labelLarge,
          foregroundColor: p.text,
          selectedForegroundColor: p.onAccentContainer,
          selectedBackgroundColor: p.accentContainer,
          side: BorderSide(color: p.outline, width: AppSizes.hairline),
          shape: buttonShape,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: p.accentContainer,
        foregroundColor: p.onAccentContainer,
        elevation: AppElevation.level2,
        focusElevation: AppElevation.level2,
        hoverElevation: AppElevation.level3,
        highlightElevation: AppElevation.level2,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadii.lg)),
        ),
      ),
      listTileTheme: ListTileThemeData(
        minTileHeight: AppSizes.listRowMinHeight,
        minLeadingWidth: AppSizes.icon,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.gutter,
        ),
        horizontalTitleGap: AppSpacing.lg,
        iconColor: p.textSecondary,
        textColor: p.text,
        titleTextStyle: textTheme.bodyLarge,
        subtitleTextStyle: textTheme.bodyMedium!.copyWith(
          color: p.textSecondary,
        ),
        leadingAndTrailingTextStyle: textTheme.labelMedium!.copyWith(
          color: p.textSecondary,
        ),
        selectedColor: p.accent,
        selectedTileColor: p.accentContainer,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.surface,
        selectedColor: p.accentContainer,
        disabledColor: overlay(0.12),
        checkmarkColor: p.onAccentContainer,
        deleteIconColor: p.textSecondary,
        labelStyle: textTheme.labelLarge!.copyWith(color: p.text),
        secondaryLabelStyle: textTheme.labelLarge!.copyWith(
          color: p.onAccentContainer,
        ),
        side: BorderSide(color: p.outlineVariant, width: AppSizes.hairline),
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.smAll),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        elevation: AppElevation.level0,
        pressElevation: AppElevation.level0,
        shadowColor: p.scrim,
        selectedShadowColor: p.scrim,
        surfaceTintColor: p.surface,
      ),
      switchTheme: const SwitchThemeData(
        materialTapTargetSize: MaterialTapTargetSize.padded,
      ),
      checkboxTheme: const CheckboxThemeData(
        materialTapTargetSize: MaterialTapTargetSize.padded,
      ),
      radioTheme: const RadioThemeData(
        materialTapTargetSize: MaterialTapTargetSize.padded,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: p.accent,
        inactiveTrackColor: p.surfaceContainerHighest,
        thumbColor: p.accent,
        overlayColor: p.accent.withValues(alpha: 0.12),
        valueIndicatorColor: p.inverseSurface,
        valueIndicatorTextStyle: textTheme.labelMedium!.copyWith(
          color: p.onInverseSurface,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.accent,
        linearTrackColor: p.surfaceContainerHighest,
        circularTrackColor: p.surfaceContainerHighest,
      ),
      dividerTheme: DividerThemeData(
        color: p.rule,
        thickness: AppSizes.hairline,
        space: AppSizes.hairline,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surfaceContainerLow,
        surfaceTintColor: p.surfaceContainerLow,
        modalBackgroundColor: p.surfaceContainerLow,
        shadowColor: p.scrim,
        modalBarrierColor: p.scrim.withValues(alpha: 0.32),
        elevation: AppElevation.level3,
        modalElevation: AppElevation.level3,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.lgTop),
        showDragHandle: true,
        dragHandleColor: p.outline,
        dragHandleSize: const Size(32, 4),
        constraints: const BoxConstraints(maxWidth: AppSizes.readingMeasure),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surfaceContainerLow,
        surfaceTintColor: p.surfaceContainerLow,
        shadowColor: p.scrim,
        barrierColor: p.scrim.withValues(alpha: 0.32),
        elevation: AppElevation.level3,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadii.lg)),
        ),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: p.surfaceContainer,
        surfaceTintColor: p.surfaceContainer,
        shadowColor: p.scrim,
        elevation: AppElevation.level2,
        textStyle: textTheme.bodyLarge,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.mdAll),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.inverseSurface,
        actionTextColor: p.inverseAccent,
        contentTextStyle: textTheme.bodyMedium!.copyWith(
          color: p.onInverseSurface,
        ),
        elevation: AppElevation.level2,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.smAll),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: p.inverseSurface,
          borderRadius: AppRadii.smAll,
        ),
        textStyle: textTheme.labelMedium!.copyWith(color: p.onInverseSurface),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: false,
        hintStyle: textTheme.bodyLarge!.copyWith(color: p.textSecondary),
        labelStyle: textTheme.bodyLarge!.copyWith(color: p.textSecondary),
        floatingLabelStyle: textTheme.bodyMedium!.copyWith(color: p.accent),
        helperStyle: textTheme.bodySmall,
        errorStyle: textTheme.bodySmall!.copyWith(color: p.error),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadii.smAll,
          borderSide: BorderSide(color: p.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadii.smAll,
          borderSide: BorderSide(color: p.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadii.smAll,
          borderSide: BorderSide(color: p.accent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadii.smAll,
          borderSide: BorderSide(color: p.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadii.smAll,
          borderSide: BorderSide(color: p.error, width: 2),
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: p.accent,
        selectionColor: p.accentContainer,
        selectionHandleColor: p.accent,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll<Color>(p.outline),
        radius: const Radius.circular(AppRadii.sm),
      ),
    );
  }
}
