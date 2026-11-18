import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/generated/app_localizations.dart';
import '../theme/app_spacing.dart';

/// The scaffold of one screen: a quiet app bar with a start-aligned title
/// (right in Arabic) over the screen's body.
///
/// The navigation bar is not part of it; [AppNavigationShell] wraps every
/// screen that sits under one of the four destinations.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions = const <Widget>[],
  });

  final String title;
  final Widget body;

  /// App bar actions. Each needs a tooltip, which is its screen reader label.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      body: SafeArea(top: false, bottom: false, child: body),
    );
  }
}

/// The frame around every screen: the navigation bar on compact widths, a
/// navigation rail from [AppSizes.railBreakpoint] up (DESIGN.md, Layout).
///
/// Each destination keeps its own navigation stack. Selecting the current
/// destination again returns to its start; for the Mushaf that start is the
/// launch rule of `/` (the last ayah read, or the index).
class AppNavigationShell extends StatelessWidget {
  const AppNavigationShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _select(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final destinations = <(IconData, IconData, String)>[
      (Icons.menu_book_outlined, Icons.menu_book, l10n.navMushaf),
      (Icons.video_library_outlined, Icons.video_library, l10n.navStories),
      (Icons.bookmark_border, Icons.bookmark, l10n.navBookmarks),
      (Icons.settings_outlined, Icons.settings, l10n.navSettings),
    ];
    final selected = navigationShell.currentIndex;
    final useRail = MediaQuery.sizeOf(context).width >= AppSizes.railBreakpoint;

    if (useRail) {
      return Scaffold(
        body: Row(
          children: <Widget>[
            SafeArea(
              child: NavigationRail(
                selectedIndex: selected,
                onDestinationSelected: _select,
                destinations: <NavigationRailDestination>[
                  for (final (icon, selectedIcon, label) in destinations)
                    NavigationRailDestination(
                      icon: Icon(icon),
                      selectedIcon: Icon(selectedIcon),
                      label: Text(label),
                    ),
                ],
              ),
            ),
            const VerticalDivider(),
            Expanded(child: navigationShell),
          ],
        ),
      );
    }

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected,
        onDestinationSelected: _select,
        destinations: <Widget>[
          for (final (icon, selectedIcon, label) in destinations)
            NavigationDestination(
              icon: Icon(icon),
              selectedIcon: Icon(selectedIcon),
              label: label,
            ),
        ],
      ),
    );
  }
}
