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
}
