// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'مسلم';

  @override
  String get navMushaf => 'المصحف';

  @override
  String get navStories => 'القصص';

  @override
  String get navBookmarks => 'العلامات';

  @override
  String get navSettings => 'الإعدادات';

  @override
  String get screenIndex => 'الفهرس';

  @override
  String get screenSearch => 'البحث';

  @override
  String get screenSurahStory => 'قصة السورة';

  @override
  String get screenEpisodes => 'الحلقات';

  @override
  String get screenEpisode => 'الحلقة';

  @override
  String get screenSources => 'المصادر';

  @override
  String get settingsSectionAppearance => 'المظهر';

  @override
  String get settingsTheme => 'السمة';

  @override
  String get themeLight => 'فاتح';

  @override
  String get themeNight => 'ليلي';

  @override
  String get themeBlackOnWhite => 'أسود على أبيض';

  @override
  String get themeWhiteOnBlack => 'أبيض على أسود';

  @override
  String get settingsLanguage => 'لغة الواجهة';

  @override
  String get languageArabic => 'العربية';

  @override
  String get languageEnglish => 'English';

  @override
  String get settingsSectionReading => 'القراءة والاستماع';

  @override
  String get settingsTextSize => 'حجم الخط في العرض المتصل';

  @override
  String get settingsReciter => 'القارئ الافتراضي';

  @override
  String reciterWithStyle(String name, String style) {
    return '$name · $style';
  }

  @override
  String get settingsSectionVideo => 'الفيديو';

  @override
  String get settingsVideoGrayscale => 'فيديو بالأبيض والأسود';

  @override
  String get settingsVideoGrayscaleHint =>
      'عند إيقافه تبقى ألوان الفيديو كما هي في كل السمات.';

  @override
  String get settingsSectionAbout => 'عن التطبيق';

  @override
  String get settingsSourcesHint => 'مصادر النص والتفسير والتلاوات وتراخيصها';

  @override
  String get placeholderMessage => 'هذه الشاشة قيد الإعداد.';

  @override
  String get stateLoading => 'جارٍ التحميل';

  @override
  String get stateErrorTitle => 'حدث خطأ';

  @override
  String get stateOfflineTitle => 'لا يوجد اتصال';

  @override
  String get stateOfflineMessage =>
      'تحقّق من اتصالك بالإنترنت ثم أعد المحاولة.';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String mushafHeadSurah(String name) {
    return 'سورة $name';
  }

  @override
  String mushafHeadJuz(int juz) {
    return 'الجزء $juz';
  }

  @override
  String mushafPageNumber(int page) {
    return 'الصفحة $page';
  }

  @override
  String get mushafFontErrorTitle => 'تعذّر تحميل خط المصحف';

  @override
  String get mushafFontErrorMessage =>
      'لا يُعرض المصحف بخط بديل. أعد تثبيت التطبيق لإصلاح ذلك.';

  @override
  String get mushafDataErrorMessage => 'تعذّر فتح بيانات المصحف.';

  @override
  String get invalidLink => 'تعذّر فتح هذا الموضع، فعُرض الفهرس.';

  @override
  String get indexTabSurahs => 'السور';

  @override
  String get indexTabJuz => 'الأجزاء';

  @override
  String get surahMakki => 'مكية';

  @override
  String get surahMadani => 'مدنية';

  @override
  String ayahCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count آية',
      many: '$count آية',
      few: '$count آيات',
      two: 'آيتان',
      one: 'آية واحدة',
    );
    return '$_temp0';
  }

  @override
  String surahDetails(String place, String ayahs) {
    return '$place · $ayahs';
  }

  @override
  String pageNumber(int page) {
    return 'صفحة $page';
  }

  @override
  String juzTitle(int number) {
    return 'الجزء $number';
  }

  @override
  String juzStart(String surah, int ayah) {
    return 'من $surah، الآية $ayah';
  }

  @override
  String tafsirSheetTitle(String surah, int ayah) {
    return '$surah، الآية $ayah';
  }

  @override
  String get tafsirPreviousAyah => 'الآية السابقة';

  @override
  String get tafsirNextAyah => 'الآية التالية';

  @override
  String tafsirSource(String name, String author) {
    return '$name · $author';
  }

  @override
  String tafsirCoversRange(String from, String to) {
    return 'يشرح هذا الموضع الآيات من $from إلى $to معًا';
  }

  @override
  String get tafsirMissing => 'لا يتوفر تفسير لهذه الآية.';

  @override
  String get playerPlayFromHere => 'الاستماع من هذه الآية';

  @override
  String get playerPlay => 'تشغيل';

  @override
  String get playerPause => 'إيقاف مؤقت';

  @override
  String get playerPreviousAyah => 'الآية السابقة';

  @override
  String get playerNextAyah => 'الآية التالية';

  @override
  String get playerStop => 'إيقاف التلاوة';

  @override
  String playerPosition(String surah, int ayah) {
    return '$surah، الآية $ayah';
  }

  @override
  String playerRepeatsLeft(int count) {
    return 'المتبقي $count';
  }

  @override
  String get playerOfflineMessage => 'تحتاج التلاوة إلى اتصال بالإنترنت.';

  @override
  String get playerChooseReciter => 'اختيار القارئ';

  @override
  String get reciterPickerTitle => 'القارئ';

  @override
  String get reciterStyleMurattal => 'مرتّل';

  @override
  String get reciterStyleMujawwad => 'مجوّد';

  @override
  String get reciterStyleMuallim => 'معلّم';

  @override
  String get readerShowContinuous => 'العرض المتصل';

  @override
  String get readerShowPages => 'عرض الصفحات';

  @override
  String get readerTextSize => 'حجم الخط';

  @override
  String get readerTextSmaller => 'تصغير الخط';

  @override
  String get readerTextLarger => 'تكبير الخط';

  @override
  String readerTextSizeValue(int percent) {
    return '$percent٪';
  }

  @override
  String get continuousPreviousSurah => 'السورة السابقة';

  @override
  String get continuousNextSurah => 'السورة التالية';

  @override
  String get readerGoTo => 'انتقال إلى';

  @override
  String get goToByPage => 'صفحة';

  @override
  String get goToBySurah => 'سورة وآية';

  @override
  String get goToPageLabel => 'رقم الصفحة';

  @override
  String get goToSurahLabel => 'السورة';

  @override
  String get goToAyahLabel => 'رقم الآية';

  @override
  String goToRange(int max) {
    return 'من 1 إلى $max';
  }

  @override
  String goToPageOutOfRange(int max) {
    return 'أدخل رقم صفحة من 1 إلى $max.';
  }

  @override
  String goToAyahOutOfRange(int max) {
    return 'أدخل رقم آية من 1 إلى $max، فهذا عدد آيات السورة.';
  }

  @override
  String get goToSurahMissing => 'اختر سورة من القائمة.';

  @override
  String goToSurahOption(int number, String name) {
    return '$number. $name';
  }

  @override
  String get goToSubmit => 'انتقال';
}
