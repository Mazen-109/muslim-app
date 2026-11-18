import 'package:material_ui/material_ui.dart';

/// Motion durations and curves (DESIGN.md, Overview: motion).
///
/// Motion confirms a change and gets out of the way. Read durations through
/// [resolve], which returns zero when the platform asks for reduced motion.
abstract final class AppMotion {
  /// Colour and opacity changes on a control: press, select, toggle.
  static const Duration short = Duration(milliseconds: 150);

  /// Small layout changes: a row expanding, a bar showing or hiding.
  static const Duration medium = Duration(milliseconds: 250);

  /// Surfaces entering: a sheet rising, a screen transition.
  static const Duration long = Duration(milliseconds: 350);

  /// Turning a Mushaf page when it is animated rather than dragged.
  static const Duration pageTurn = Duration(milliseconds: 300);

  /// The default curve for state changes and entrances.
  static const Curve standard = Curves.easeOutCubic;

  /// For surfaces leaving the screen.
  static const Curve exit = Curves.easeInCubic;

  /// [duration], or zero when animations are disabled on the device.
  static Duration resolve(BuildContext context, Duration duration) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false
      ? Duration.zero
      : duration;
}
