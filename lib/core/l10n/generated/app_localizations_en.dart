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
  String mushafHeadSurah(String name) {
    return 'Surah $name';
  }

  @override
  String mushafHeadJuz(int juz) {
    return 'Juz $juz';
  }

  @override
  String mushafPageNumber(int page) {
    return 'Page $page';
  }

  @override
  String get mushafFontErrorTitle => 'The Mushaf font could not be loaded';

  @override
  String get mushafFontErrorMessage =>
      'The Mushaf is never shown in a substitute font. Reinstall the app to fix this.';

  @override
  String get mushafDataErrorMessage => 'The Mushaf data could not be opened.';

  @override
  String get invalidLink =>
      'That place in the Mushaf could not be opened, so the index is shown.';

  @override
  String get indexTabSurahs => 'Surahs';

  @override
  String get indexTabJuz => 'Juz';

  @override
  String get surahMakki => 'Makki';

  @override
  String get surahMadani => 'Madani';

  @override
  String ayahCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ayahs',
      one: '1 ayah',
    );
    return '$_temp0';
  }

  @override
  String surahDetails(String place, String ayahs) {
    return '$place · $ayahs';
  }

  @override
  String pageNumber(int page) {
    return 'Page $page';
  }

  @override
  String juzTitle(int number) {
    return 'Juz $number';
  }

  @override
  String juzStart(String surah, int ayah) {
    return 'From $surah, ayah $ayah';
  }

  @override
  String tafsirSheetTitle(String surah, int ayah) {
    return '$surah, ayah $ayah';
  }

  @override
  String get tafsirPreviousAyah => 'Previous ayah';

  @override
  String get tafsirNextAyah => 'Next ayah';

  @override
  String tafsirSource(String name, String author) {
    return '$name · $author';
  }

  @override
  String tafsirCoversRange(String from, String to) {
    return 'This passage explains ayahs $from to $to together';
  }

  @override
  String get tafsirMissing => 'No tafsir is available for this ayah.';

  @override
  String get playerPlayFromHere => 'Listen from this ayah';

  @override
  String get playerPlay => 'Play';

  @override
  String get playerPause => 'Pause';

  @override
  String get playerPreviousAyah => 'Previous ayah';

  @override
  String get playerNextAyah => 'Next ayah';

  @override
  String get playerStop => 'Stop recitation';

  @override
  String playerPosition(String surah, int ayah) {
    return '$surah, ayah $ayah';
  }

  @override
  String playerRepeatsLeft(int count) {
    return '$count left';
  }

  @override
  String get playerOfflineMessage => 'Recitation needs a connection.';

  @override
  String get playerChooseReciter => 'Choose reciter';

  @override
  String get reciterPickerTitle => 'Reciter';

  @override
  String get reciterStyleMurattal => 'Murattal';

  @override
  String get reciterStyleMujawwad => 'Mujawwad';

  @override
  String get reciterStyleMuallim => 'Teaching (Mu\'allim)';

  @override
  String get readerShowContinuous => 'Continuous view';

  @override
  String get readerShowPages => 'Page view';

  @override
  String get readerTextSize => 'Text size';

  @override
  String get readerTextSmaller => 'Smaller text';

  @override
  String get readerTextLarger => 'Larger text';

  @override
  String readerTextSizeValue(int percent) {
    return '$percent%';
  }

  @override
  String get continuousPreviousSurah => 'Previous surah';

  @override
  String get continuousNextSurah => 'Next surah';
}
