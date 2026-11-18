import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'core/l10n/generated/app_localizations.dart';
import 'core/routing/app_router.dart';
import 'core/settings/settings_providers.dart';
import 'core/theme/app_theme.dart';

/// The root widget: Arabic first, right-to-left, English as the second
/// locale. The theme and the locale come from the reader's settings and
/// apply to every screen.
class MuslimApp extends ConsumerWidget {
  const MuslimApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = AppTheme.of(ref.watch(themeProvider));
    final locale = Locale(ref.watch(localeProvider).storageValue);

    return MaterialApp.router(
      routerConfig: ref.watch(appRouterProvider),
      scaffoldMessengerKey: ref.watch(scaffoldMessengerKeyProvider),
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: theme,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
    );
  }
}
