import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/settings/settings_providers.dart';
import '../../core/settings/settings_repository.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_spacing.dart';
import '../mushaf/reader_controller.dart';
import 'autoscroll_controller.dart';

/// The key of the auto-scroll bar while auto-scroll is on.
const ValueKey<String> autoscrollBarKey = ValueKey<String>('autoscroll-bar');

/// The keys of the auto-scroll bar's controls.
const ValueKey<String> autoscrollPauseKey = ValueKey<String>(
  'autoscroll-pause',
);
const ValueKey<String> autoscrollFollowingKey = ValueKey<String>(
  'autoscroll-following',
);
const ValueKey<String> autoscrollSpeedKey = ValueKey<String>(
  'autoscroll-speed',
);
const ValueKey<String> autoscrollStopKey = ValueKey<String>('autoscroll-stop');

/// The key of the "switch to continuous view" button of the dialog that
/// the page view shows when auto-scroll is asked for.
const ValueKey<String> autoscrollSwitchKey = ValueKey<String>(
  'autoscroll-switch',
);

/// The step of the speed slider, in logical pixels per second.
const double autoscrollSpeedStep = 5;

/// Turns auto-scroll on from the reader. In the continuous view it starts
/// at once; in the page view it offers to switch to the continuous view
/// first, and the page view stays when the reader declines.
Future<void> startAutoscroll(BuildContext context, WidgetRef ref) async {
  final reader = ref.read(readerControllerProvider.notifier);
  if (ref.read(readerControllerProvider).mode != ReadingMode.continuous) {
    final l10n = AppLocalizations.of(context);
    final switchView = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.readerAutoscroll),
        content: Text(l10n.autoscrollSwitchMessage),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            key: autoscrollSwitchKey,
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.autoscrollSwitchConfirm),
          ),
        ],
      ),
    );
    if (switchView != true || !context.mounted) return;
    // The mode changes at once; persisting it can finish later.
    final persisted = reader.setMode(ReadingMode.continuous);
    ref.read(autoscrollControllerProvider.notifier).start();
    await persisted;
    return;
  }
  ref.read(autoscrollControllerProvider.notifier).start();
}

/// The auto-scroll bar under the continuous view while auto-scroll is on:
/// pause or resume, the speed slider, and a button that turns auto-scroll
/// off. It sits on the ground with a hairline rule above it, like the
/// player bar, and slides in and out with it.
class AutoscrollControls extends ConsumerWidget {
  const AutoscrollControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(autoscrollControllerProvider);
    return AnimatedSize(
      duration: AppMotion.resolve(context, AppMotion.medium),
      curve: AppMotion.standard,
      alignment: Alignment.bottomCenter,
      child: status == AutoscrollStatus.off
          ? const SizedBox(width: double.infinity)
          : _Bar(key: autoscrollBarKey, status: status),
    );
  }
}

class _Bar extends ConsumerStatefulWidget {
  const _Bar({super.key, required this.status});

  final AutoscrollStatus status;

  @override
  ConsumerState<_Bar> createState() => _BarState();
}

class _BarState extends ConsumerState<_Bar> {
  /// The slider's value while it is dragged, ahead of the stored setting.
  double? _dragged;

  /// Applies [value] at once (the driver reads the setting on every
  /// frame) and stores it.
  void _setSpeed(double value) {
    setState(() => _dragged = value);
    unawaited(ref.read(autoscrollSpeedProvider.notifier).set(value));
  }

  Future<void> _endDrag(double value) async {
    await ref.read(autoscrollSpeedProvider.notifier).set(value);
    if (mounted) setState(() => _dragged = null);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final colors = AppColors.of(context);
    final controller = ref.read(autoscrollControllerProvider.notifier);
    final double stored = ref.watch(autoscrollSpeedProvider);
    final speed = _dragged ?? stored;
    final status = widget.status;

    final Widget toggle;
    if (status == AutoscrollStatus.followingAudio) {
      // The recitation leads; a tap would not move anything.
      toggle = SizedBox.square(
        key: autoscrollFollowingKey,
        dimension: AppSizes.minTouchTarget,
        child: Tooltip(
          message: l10n.autoscrollFollowing,
          child: Semantics(
            label: l10n.autoscrollFollowing,
            liveRegion: true,
            child: Icon(Icons.graphic_eq, color: scheme.onSurfaceVariant),
          ),
        ),
      );
    } else {
      final running = status == AutoscrollStatus.running;
      toggle = IconButton(
        key: autoscrollPauseKey,
        tooltip: running ? l10n.autoscrollPause : l10n.autoscrollResume,
        icon: Icon(running ? Icons.pause : Icons.play_arrow),
        onPressed: controller.togglePause,
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          top: BorderSide(color: colors.rule, width: AppSizes.hairline),
        ),
      ),
      child: Semantics(
        container: true,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xs),
          child: Row(
            children: <Widget>[
              toggle,
              const SizedBox(width: AppSpacing.xs),
              ExcludeSemantics(
                child: Icon(
                  Icons.speed,
                  size: AppSizes.icon * 2 / 3,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              Expanded(
                child: Semantics(
                  label: l10n.autoscrollSpeed,
                  // Steps of 5 without a row of tick marks, which would
                  // clutter the bar under the text.
                  child: SliderTheme(
                    data: SliderTheme.of(
                      context,
                    ).copyWith(tickMarkShape: SliderTickMarkShape.noTickMark),
                    child: Slider(
                      key: autoscrollSpeedKey,
                      value: speed,
                      min: SettingsRepository.minAutoscrollSpeed,
                      max: SettingsRepository.maxAutoscrollSpeed,
                      divisions:
                          ((SettingsRepository.maxAutoscrollSpeed -
                                      SettingsRepository.minAutoscrollSpeed) /
                                  autoscrollSpeedStep)
                              .round(),
                      label: l10n.autoscrollSpeedValue(speed.round()),
                      semanticFormatterCallback: (value) =>
                          l10n.autoscrollSpeedValue(value.round()),
                      onChanged: _setSpeed,
                      onChangeEnd: _endDrag,
                    ),
                  ),
                ),
              ),
              IconButton(
                key: autoscrollStopKey,
                tooltip: l10n.autoscrollStop,
                icon: const Icon(Icons.close),
                onPressed: controller.stop,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
