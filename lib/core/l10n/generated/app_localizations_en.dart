// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Muslim';

  @override
  String get navMushaf => 'Mushaf';

  @override
  String get navStories => 'Stories';

  @override
  String get navBookmarks => 'Bookmarks';

  @override
  String get navSettings => 'Settings';

  @override
  String get screenIndex => 'Index';

  @override
  String get screenSearch => 'Search';

  @override
  String get screenSurahStory => 'Surah story';

  @override
  String get screenEpisodes => 'Episodes';

  @override
  String get screenEpisode => 'Episode';

  @override
  String get screenSources => 'Sources';

  @override
  String get placeholderMessage => 'This screen is not ready yet.';

  @override
  String get stateLoading => 'Loading';

  @override
  String get stateErrorTitle => 'Something went wrong';

  @override
  String get stateOfflineTitle => 'No connection';

  @override
  String get stateOfflineMessage =>
      'Check your internet connection and try again.';

  @override
  String get retry => 'Try again';

  @override
  String get invalidLink =>
      'That place in the Mushaf could not be opened, so the index is shown.';
}
