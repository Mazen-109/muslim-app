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
  String get settingsSectionAppearance => 'Appearance';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get themeLight => 'Light';

  @override
  String get themeNight => 'Night';

  @override
  String get themeBlackOnWhite => 'Black on white';

  @override
  String get themeWhiteOnBlack => 'White on black';

  @override
  String get settingsLanguage => 'Interface language';

  @override
  String get languageArabic => 'العربية';

  @override
  String get languageEnglish => 'English';

  @override
  String get settingsSectionReading => 'Reading and listening';

  @override
  String get settingsTextSize => 'Continuous view text size';

  @override
  String get settingsReciter => 'Default reciter';

  @override
  String get reciterStyleMurattal => 'Murattal';

  @override
  String get reciterStyleMujawwad => 'Mujawwad';

  @override
  String get reciterStyleMuallim => 'Mu\'allim (teaching)';

  @override
  String reciterWithStyle(String name, String style) {
    return '$name · $style';
  }

  @override
  String get settingsSectionVideo => 'Video';

  @override
  String get settingsVideoGrayscale => 'Black and white videos';

  @override
  String get settingsVideoGrayscaleHint =>
      'When this is off, videos keep their colours in every theme.';

  @override
  String get settingsSectionAbout => 'About';

  @override
  String get settingsSourcesHint =>
      'Where the text, tafsir and recitations come from, and their licences';

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

  @override
  String get readerGoTo => 'Go to';

  @override
  String get goToByPage => 'Page';

  @override
  String get goToBySurah => 'Surah and ayah';

  @override
  String get goToPageLabel => 'Page number';

  @override
  String get goToSurahLabel => 'Surah';

  @override
  String get goToAyahLabel => 'Ayah number';

  @override
  String goToRange(int max) {
    return '1 to $max';
  }

  @override
  String goToPageOutOfRange(int max) {
    return 'Enter a page number from 1 to $max.';
  }

  @override
  String goToAyahOutOfRange(int max) {
    return 'Enter an ayah number from 1 to $max, the number of ayahs in this surah.';
  }

  @override
  String get goToSurahMissing => 'Choose a surah from the list.';

  @override
  String goToSurahOption(int number, String name) {
    return '$number. $name';
  }

  @override
  String get goToSubmit => 'Go';
}
