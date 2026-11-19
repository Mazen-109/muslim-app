import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/settings/settings_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/reciter.dart';
import '../../data/quran_repository.dart';
import '../../data/reciter_repository.dart';
import '../mushaf/reader_controller.dart';
import 'playback_state.dart';
import 'recitation_controller.dart';
import 'reciter_picker.dart';

/// The key of the reader's app bar button that recites from the current
/// ayah.
const ValueKey<String> playFromHereKey = ValueKey<String>('play-from-here');

/// The key of the player bar while a recitation is active.
const ValueKey<String> playerBarKey = ValueKey<String>('player-bar');

/// The keys of the player bar's controls and texts.
const ValueKey<String> playerPlayPauseKey = ValueKey<String>(
  'player-play-pause',
);
const ValueKey<String> playerPreviousKey = ValueKey<String>('player-previous');
const ValueKey<String> playerNextKey = ValueKey<String>('player-next');
const ValueKey<String> playerStopKey = ValueKey<String>('player-stop');
const ValueKey<String> playerRetryKey = ValueKey<String>('player-retry');
const ValueKey<String> playerLoadingKey = ValueKey<String>('player-loading');
const ValueKey<String> playerOfflineKey = ValueKey<String>('player-offline');

/// The tappable reciter name, which opens the reciter picker.
const ValueKey<String> playerReciterKey = ValueKey<String>('player-reciter');
const ValueKey<String> playerReciterNameKey = ValueKey<String>(
  'player-reciter-name',
);
const ValueKey<String> playerPositionKey = ValueKey<String>('player-position');
const ValueKey<String> playerRepeatsKey = ValueKey<String>('player-repeats');

/// The name of [reciter] in the interface language.
String reciterName(BuildContext context, Reciter reciter) =>
    Localizations.localeOf(context).languageCode == 'ar'
    ? reciter.nameAr
    : reciter.nameEn;

/// The reader's play control: recites from the reader's current ayah to the
/// end of its surah with the chosen reciter. Pressed during a recitation,
/// it starts again from the current ayah, which is where the reader has
/// turned to. Disabled until the content database is open.
class PlayFromHereButton extends ConsumerWidget {
  const PlayFromHereButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ready = ref.watch(
      quranRepositoryProvider.select((value) => value.hasValue),
    );
    return IconButton(
      key: playFromHereKey,
      tooltip: AppLocalizations.of(context).playerPlayFromHere,
      icon: const Icon(Icons.play_circle_outline),
      onPressed: ready
          ? () {
              final quran = ref.read(quranRepositoryProvider).requireValue;
              final current = ref.read(readerControllerProvider).currentAyahId;
              ref
                  .read(recitationControllerProvider.notifier)
                  .playFrom(quran.refOf(current));
            }
          : null,
    );
  }
}

/// The reader's body with the player bar under it while a recitation is
/// active, and the audio follower.
///
/// The follower keeps the reader on the ayah being recited: it highlights
/// that ayah and makes it the current ayah, so the page view turns and the
/// continuous view scrolls to it. When the recitation ends, the highlight
/// is removed if it is still the follower's, and the reader stays on the
/// last ayah recited. After an error the highlight stays on the ayah that
/// failed, which is where retry continues.
class ReaderPlayback extends ConsumerStatefulWidget {
  const ReaderPlayback({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ReaderPlayback> createState() => _ReaderPlaybackState();
}

class _ReaderPlaybackState extends ConsumerState<ReaderPlayback> {
  /// The ayah id the follower last highlighted.
  int? _followed;

  void _follow(PlaybackState? previous, PlaybackState next) {
    final quran = ref.read(quranRepositoryProvider);
    if (!quran.hasValue) return;
    final reader = ref.read(readerControllerProvider.notifier);
    final ayah = next.ayah;
    if (next.isActive && ayah != null) {
      // Follow a new ayah, and a recitation starting or continuing (play,
      // resume, retry) even on the same ayah, since the reader may have
      // turned away meanwhile. A pause or an error moves nothing.
      final moved = previous?.ayah != ayah;
      final started =
          previous?.status != next.status &&
          (next.status == PlaybackStatus.loading ||
              next.status == PlaybackStatus.playing);
      if (!moved && !started) return;
      final id = quran.requireValue.ayahIdOf(ayah);
      _followed = id;
      reader
        ..setCurrentAyah(id)
        ..highlight(id);
    } else if (!next.isActive) {
      final followed = _followed;
      _followed = null;
      if (followed != null &&
          ref.read(readerControllerProvider).highlightedAyahId == followed) {
        reader.highlight(null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<PlaybackState>(recitationControllerProvider, _follow);
    return Column(
      children: <Widget>[
        Expanded(child: widget.child),
        const PlayerBar(),
      ],
    );
  }
}

/// The compact player bar: shown only while a recitation is active, under
/// the reader, on the ground with a hairline rule above it (DESIGN.md: the
/// audio bar sits over the ground, flat).
///
/// It names the reciter (tap to change) and the surah and ayah being
/// recited, and has previous, play or pause, next and stop. The transport
/// controls keep the platform's left-to-right media order in both
/// languages. When the audio cannot be loaded it shows the offline state
/// with retry instead; the Mushaf above it stays readable.
class PlayerBar extends ConsumerWidget {
  const PlayerBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(recitationControllerProvider);
    final duration = AppMotion.resolve(context, AppMotion.medium);
    return AnimatedSize(
      duration: duration,
      curve: AppMotion.standard,
      alignment: Alignment.bottomCenter,
      child: state.isActive && state.ayah != null
          ? _Bar(key: playerBarKey, state: state)
          : const SizedBox(width: double.infinity),
    );
  }
}

class _Bar extends ConsumerWidget {
  const _Bar({super.key, required this.state});

  final PlaybackState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = AppColors.of(context);

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
          padding: const EdgeInsetsDirectional.only(
            start: AppSpacing.xs,
            end: AppSpacing.xs,
            top: AppSpacing.xs,
            bottom: AppSpacing.xs,
          ),
          child: state.status == PlaybackStatus.error
              ? _OfflineRow(state: state)
              : _PlayingRow(state: state),
        ),
      ),
    );
  }
}

/// The reciter and position, then the transport controls.
class _PlayingRow extends ConsumerWidget {
  const _PlayingRow({required this.state});

  final PlaybackState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(recitationControllerProvider.notifier);
    final quran = ref.watch(quranRepositoryProvider).value;
    final ayah = state.ayah!;
    final surahLength = quran?.ayahCounts[ayah.surah - 1] ?? ayah.ayah;
    final canStep =
        state.status == PlaybackStatus.playing ||
        state.status == PlaybackStatus.paused;

    return Row(
      children: <Widget>[
        Expanded(child: _NowPlaying(state: state)),
        // Media transport keeps its left-to-right order in Arabic too, as
        // Material's bidirectional guidance asks for playback controls.
        Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              IconButton(
                key: playerPreviousKey,
                tooltip: l10n.playerPreviousAyah,
                icon: const Icon(Icons.skip_previous),
                onPressed: canStep && ayah.ayah > 1
                    ? controller.previous
                    : null,
              ),
              _PlayPause(state: state),
              IconButton(
                key: playerNextKey,
                tooltip: l10n.playerNextAyah,
                icon: const Icon(Icons.skip_next),
                onPressed: canStep && ayah.ayah < surahLength
                    ? controller.next
                    : null,
              ),
            ],
          ),
        ),
        IconButton(
          key: playerStopKey,
          tooltip: l10n.playerStop,
          icon: const Icon(Icons.stop),
          onPressed: controller.stop,
        ),
      ],
    );
  }
}

/// The one filled, circular control of the bar; a progress indicator in
/// its place while the audio loads.
class _PlayPause extends ConsumerWidget {
  const _PlayPause({required this.state});

  final PlaybackState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(recitationControllerProvider.notifier);
    if (state.status == PlaybackStatus.loading) {
      return SizedBox.square(
        key: playerLoadingKey,
        dimension: AppSizes.minTouchTarget,
        child: Center(
          child: Semantics(
            label: l10n.stateLoading,
            liveRegion: true,
            child: const ExcludeSemantics(
              child: SizedBox.square(
                dimension: AppSizes.icon,
                child: CircularProgressIndicator(),
              ),
            ),
          ),
        ),
      );
    }
    final playing = state.status == PlaybackStatus.playing;
    return IconButton.filled(
      key: playerPlayPauseKey,
      tooltip: playing ? l10n.playerPause : l10n.playerPlay,
      icon: Icon(playing ? Icons.pause : Icons.play_arrow),
      onPressed: playing ? controller.pause : controller.resume,
    );
  }
}

/// The reciter's name over the surah and ayah being recited. Tapping it
/// opens the reciter picker.
class _NowPlaying extends ConsumerWidget {
  const _NowPlaying({required this.state});

  final PlaybackState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final scheme = theme.colorScheme;
    final quran = ref.watch(quranRepositoryProvider).value;
    final reciters = ref.watch(reciterRepositoryProvider).value;
    final reciter = reciters?.reciter(
      state.reciterId ?? ref.watch(reciterIdProvider),
    );
    final ayah = state.ayah!;
    final surah = quran?.surah(ayah.surah);
    final surahName = surah == null
        ? null
        : Localizations.localeOf(context).languageCode == 'ar'
        ? surah.nameAr
        : surah.nameEn;
    final remaining = state.mode == PlaybackMode.repeat
        ? state.remainingRepeats
        : null;
    final secondary = text.labelMedium!.copyWith(
      color: scheme.onSurfaceVariant,
    );

    return Semantics(
      button: true,
      hint: l10n.playerChooseReciter,
      child: InkWell(
        key: playerReciterKey,
        borderRadius: AppRadii.mdAll,
        onTap: () => showReciterPicker(context),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSizes.minTouchTarget),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        reciter == null ? '' : reciterName(context, reciter),
                        key: playerReciterNameKey,
                        style: text.labelLarge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xxs),
                    ExcludeSemantics(
                      child: Icon(
                        Icons.expand_more,
                        size: AppSizes.icon * 2 / 3,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        surahName == null
                            ? ''
                            : l10n.playerPosition(surahName, ayah.ayah),
                        key: playerPositionKey,
                        style: secondary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (remaining != null) ...<Widget>[
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        l10n.playerRepeatsLeft(remaining),
                        key: playerRepeatsKey,
                        style: secondary,
                        maxLines: 1,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The offline state at bar size: what failed, retry, and stop.
class _OfflineRow extends ConsumerWidget {
  const _OfflineRow({required this.state});

  final PlaybackState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final controller = ref.read(recitationControllerProvider.notifier);

    return Row(
      key: playerOfflineKey,
      children: <Widget>[
        const SizedBox(width: AppSpacing.md),
        ExcludeSemantics(
          child: Icon(Icons.cloud_off_outlined, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Semantics(
            liveRegion: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  l10n.stateOfflineTitle,
                  style: theme.textTheme.labelLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  l10n.playerOfflineMessage,
                  style: theme.textTheme.labelMedium!.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        RetryButton(key: playerRetryKey, onPressed: controller.retry),
        IconButton(
          key: playerStopKey,
          tooltip: l10n.playerStop,
          icon: const Icon(Icons.stop),
          onPressed: controller.stop,
        ),
      ],
    );
  }
}
