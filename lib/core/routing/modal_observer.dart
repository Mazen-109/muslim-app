import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// How many modal surfaces are open over the app: bottom sheets, dialogs
/// and popup menus, on any navigator that has a [ModalRouteObserver].
///
/// Features that must hold still while the reader looks at a sheet or a
/// menu (auto-scroll, data-model.md section 6) watch this instead of every
/// sheet reporting itself, so a new sheet is covered without extra code.
final openModalCountProvider = NotifierProvider<OpenModalCount, int>(
  OpenModalCount.new,
);

/// The count behind [openModalCountProvider].
class OpenModalCount extends Notifier<int> {
  @override
  int build() => 0;

  void opened() => state = state + 1;

  void closed() {
    if (state > 0) state = state - 1;
  }
}

/// Reports [PopupRoute]s (modal bottom sheets, dialogs, popup menus) pushed
/// on and popped from its navigator to [onOpened] and [onClosed].
///
/// The router registers one as its observer; go_router passes the router's
/// observers on to the shell's branch navigators as well, so sheets opened
/// on any navigator are seen.
class ModalRouteObserver extends NavigatorObserver {
  ModalRouteObserver({required this.onOpened, required this.onClosed});

  final VoidCallback onOpened;
  final VoidCallback onClosed;

  static bool _isModal(Route<dynamic>? route) => route is PopupRoute;

  /// Runs [callback] now, or after the frame when the navigator reports
  /// during a build (a route removed because the pages changed), since
  /// listeners may not rebuild while the tree is building.
  static void _report(VoidCallback callback) {
    final binding = SchedulerBinding.instance;
    if (binding.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      binding.addPostFrameCallback((_) => callback());
    } else {
      callback();
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_isModal(route)) _report(onOpened);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_isModal(route)) _report(onClosed);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_isModal(route)) _report(onClosed);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (_isModal(oldRoute)) _report(onClosed);
    if (_isModal(newRoute)) _report(onOpened);
  }
}
