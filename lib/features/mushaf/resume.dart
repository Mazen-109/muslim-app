import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/settings/settings_providers.dart';
import 'reader_controller.dart';

/// How long the current ayah must stay unchanged before it is saved as
/// `last_ayah_id`. Turning pages or scrolling saves once the reader rests,
/// not on every step.
const Duration resumeSaveDelay = Duration(seconds: 1);

/// Saves an ayah id at most once per quiet period of [delay].
///
/// [schedule] restarts the wait with the newest id; [flush] saves the pending
/// id at once. An id equal to the last one saved is not written again.
class ResumeRecorder {
  ResumeRecorder({required this.save, this.delay = resumeSaveDelay});

  /// Persists an ayah id.
  final Future<void> Function(int ayahId) save;

  final Duration delay;

  Timer? _timer;
  int? _pending;
  int? _saved;

  /// Whether an id is waiting for the quiet period to end.
  bool get hasPending => _pending != null;

  /// Saves [ayahId] once [delay] passes with no newer id.
  void schedule(int ayahId) {
    _pending = ayahId;
    _timer?.cancel();
    _timer = Timer(delay, flush);
  }

  /// Saves the pending id now, or [ayahId] when given.
  Future<void> flush([int? ayahId]) async {
    _timer?.cancel();
    _timer = null;
    final id = ayahId ?? _pending;
    _pending = null;
    if (id == null || id == _saved) return;
    _saved = id;
    await save(id);
  }

  /// Drops the pending id without saving it.
  void cancel() {
    _timer?.cancel();
    _timer = null;
    _pending = null;
  }
}

/// Keeps `last_ayah_id` (data-model.md section 4) in step with the reader's
/// current ayah while [child] is shown, so that the next launch reopens the
/// Mushaf there (contracts/routes.md, `/`).
///
/// The id is saved when the current ayah has been still for
/// [resumeSaveDelay], at once when the app is paused, and when this widget
/// leaves the tree. Mount it only once the reader has opened its target, so
/// the controller's initial position never overwrites the saved one.
class ResumeRecorderScope extends ConsumerStatefulWidget {
  const ResumeRecorderScope({
    super.key,
    required this.child,
    this.delay = resumeSaveDelay,
  });

  final Widget child;
  final Duration delay;

  @override
  ConsumerState<ResumeRecorderScope> createState() =>
      _ResumeRecorderScopeState();
}

class _ResumeRecorderScopeState extends ConsumerState<ResumeRecorderScope> {
  late final ResumeRecorder _recorder;
  late final AppLifecycleListener _lifecycle;
  late final ProviderSubscription<int> _subscription;

  @override
  void initState() {
    super.initState();
    // The notifier is captured so that the last save, from dispose, does
    // not need the widget's ref.
    final lastAyah = ref.read(lastAyahIdProvider.notifier);
    _recorder = ResumeRecorder(save: lastAyah.set, delay: widget.delay);
    _subscription = ref.listenManual<int>(
      readerControllerProvider.select((s) => s.currentAyahId),
      (previous, next) => _recorder.schedule(next),
      fireImmediately: true,
    );
    _lifecycle = AppLifecycleListener(
      onPause: () => _recorder.flush(_subscription.read()),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _subscription.close();
    if (_recorder.hasPending) unawaited(_recorder.flush());
    _recorder.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
