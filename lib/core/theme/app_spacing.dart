import 'package:material_ui/material_ui.dart';

/// The spacing scale, a 4 dp grid (DESIGN.md, Layout).
abstract final class AppSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  /// The side margin of every screen.
  static const double gutter = lg;
}

/// Fixed sizes that are not spacing.
abstract final class AppSizes {
  /// The minimum width and height of anything the reader can tap.
  static const double minTouchTarget = 48;

  /// The widest a column of running text may grow, on any screen.
  static const double readingMeasure = 600;

  /// The width of a hairline rule.
  static const double hairline = 1;

  /// Icon size in app bars, lists and buttons.
  static const double icon = 24;

  /// The height of the bottom navigation bar.
  static const double navigationBarHeight = 72;

  /// The minimum height of a list row.
  static const double listRowMinHeight = 56;

  /// The icon of a full-area empty, error or offline state.
  static const double stateIcon = 48;

  /// The window width from which the navigation bar becomes a rail
  /// (Material's medium window class).
  static const double railBreakpoint = 600;
}

/// Corner radii (DESIGN.md, Shapes).
abstract final class AppRadii {
  static const double none = 0;
  static const double sm = 4;
  static const double md = 8;
  static const double lg = 16;

  /// For circular controls only, such as the play button.
  static const double full = 999;

  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgTop = BorderRadius.vertical(
    top: Radius.circular(lg),
  );
}

/// Elevation levels in dp (DESIGN.md, Elevation & Depth). The system is flat:
/// depth comes from the surface container tones and hairline rules, and only
/// surfaces that float above the page (sheets, dialogs, menus) are raised.
abstract final class AppElevation {
  static const double level0 = 0;
  static const double level1 = 1;
  static const double level2 = 3;
  static const double level3 = 6;
}
