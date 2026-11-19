import 'package:material_ui/material_ui.dart';

import '../l10n/generated/app_localizations.dart';
import '../theme/app_spacing.dart';

/// Full-area states shared by every screen: loading, empty, error and
/// offline (plan.md, Errors).
///
/// They are deliberately quiet: one icon in Faded Ink, a title, an optional
/// line of explanation and at most one action, centred within the reading
/// measure. Error is shown by wording and icon, not by colour, so the states
/// read the same in the black and white themes.

/// A centred progress indicator with a screen reader label.
class LoadingStateView extends StatelessWidget {
  const LoadingStateView({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        label: AppLocalizations.of(context).stateLoading,
        liveRegion: true,
        child: const ExcludeSemantics(child: CircularProgressIndicator()),
      ),
    );
  }
}

/// Nothing to show yet, for example an empty bookmarks list.
class EmptyStateView extends StatelessWidget {
  const EmptyStateView({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
    this.announce = false,
  });

  final IconData icon;
  final String title;
  final String? message;

  /// An optional way forward, such as a button that opens the index.
  final Widget? action;

  /// Whether a screen reader announces the state when it appears, for a
  /// state that replaces content in answer to the reader, such as a search
  /// with no results.
  final bool announce;

  @override
  Widget build(BuildContext context) {
    return _StateLayout(
      icon: icon,
      title: title,
      message: message,
      action: action,
      announce: announce,
    );
  }
}

/// Something failed. [onRetry], when given, shows a retry button.
class ErrorStateView extends StatelessWidget {
  const ErrorStateView({super.key, this.title, this.message, this.onRetry});

  /// Defaults to the generic error heading.
  final String? title;
  final String? message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _StateLayout(
      icon: Icons.error_outline,
      title: title ?? l10n.stateErrorTitle,
      message: message,
      action: onRetry == null ? null : RetryButton(onPressed: onRetry!),
      announce: true,
    );
  }
}

/// A network-dependent feature (audio, video, catalog refresh) has no
/// connection. Reading is never blocked by this state.
class OfflineStateView extends StatelessWidget {
  const OfflineStateView({super.key, this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _StateLayout(
      icon: Icons.cloud_off_outlined,
      title: l10n.stateOfflineTitle,
      message: l10n.stateOfflineMessage,
      action: onRetry == null ? null : RetryButton(onPressed: onRetry!),
      announce: true,
    );
  }
}

/// The retry action used by the error and offline states.
class RetryButton extends StatelessWidget {
  const RetryButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.refresh),
      label: Text(AppLocalizations.of(context).retry),
    );
  }
}

class _StateLayout extends StatelessWidget {
  const _StateLayout({
    required this.icon,
    required this.title,
    this.message,
    this.action,
    this.announce = false,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  /// Whether a screen reader announces the state when it appears.
  final bool announce;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = theme.textTheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.gutter,
          vertical: AppSpacing.xl,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSizes.readingMeasure),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Semantics(
                liveRegion: announce,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    ExcludeSemantics(
                      child: Icon(
                        icon,
                        size: AppSizes.stateIcon,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      title,
                      style: text.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    if (message != null) ...<Widget>[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        message!,
                        style: text.bodyMedium!.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
              if (action != null) ...<Widget>[
                const SizedBox(height: AppSpacing.xl),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
