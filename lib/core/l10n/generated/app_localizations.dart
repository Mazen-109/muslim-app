import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// The app name, shown in the title bar and the task switcher.
  ///
  /// In ar, this message translates to:
  /// **'مسلم'**
  String get appTitle;

  /// Bottom navigation label: the Mushaf reader.
  ///
  /// In ar, this message translates to:
  /// **'المصحف'**
  String get navMushaf;

  /// Bottom navigation label: the stories section.
  ///
  /// In ar, this message translates to:
  /// **'القصص'**
  String get navStories;

  /// Bottom navigation label: bookmarks and the memorised list.
  ///
  /// In ar, this message translates to:
  /// **'العلامات'**
  String get navBookmarks;

  /// Bottom navigation label and screen title: settings.
  ///
  /// In ar, this message translates to:
  /// **'الإعدادات'**
  String get navSettings;

  /// Screen title of the surah and juz index, and the tooltip of the button that opens it.
  ///
  /// In ar, this message translates to:
  /// **'الفهرس'**
  String get screenIndex;

  /// Screen title of search, and the tooltip of the button that opens it.
  ///
  /// In ar, this message translates to:
  /// **'البحث'**
  String get screenSearch;

  /// Screen title of the surah story player.
  ///
  /// In ar, this message translates to:
  /// **'قصة السورة'**
  String get screenSurahStory;

  /// Screen title of the episode list of a story.
  ///
  /// In ar, this message translates to:
  /// **'الحلقات'**
  String get screenEpisodes;

  /// Screen title of the episode player.
  ///
  /// In ar, this message translates to:
  /// **'الحلقة'**
  String get screenEpisode;

  /// Screen title of the sources page, and the settings row that opens it.
  ///
  /// In ar, this message translates to:
  /// **'المصادر'**
  String get screenSources;

  /// Shown on a screen that a later version fills in.
  ///
  /// In ar, this message translates to:
  /// **'هذه الشاشة قيد الإعداد.'**
  String get placeholderMessage;

  /// Screen reader label of the loading indicator.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ التحميل'**
  String get stateLoading;

  /// Heading of the generic error state.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ'**
  String get stateErrorTitle;

  /// Heading of the offline state.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد اتصال'**
  String get stateOfflineTitle;

  /// Body of the offline state.
  ///
  /// In ar, this message translates to:
  /// **'تحقّق من اتصالك بالإنترنت ثم أعد المحاولة.'**
  String get stateOfflineMessage;

  /// Button that retries a failed action.
  ///
  /// In ar, this message translates to:
  /// **'إعادة المحاولة'**
  String get retry;

  /// Screen reader label of the surah name in the Mushaf page's running head. The name comes from the database.
  ///
  /// In ar, this message translates to:
  /// **'سورة {name}'**
  String mushafHeadSurah(String name);

  /// The juz number in the Mushaf page's running head.
  ///
  /// In ar, this message translates to:
  /// **'الجزء {juz}'**
  String mushafHeadJuz(int juz);

  /// Screen reader label of the page number below a Mushaf page.
  ///
  /// In ar, this message translates to:
  /// **'الصفحة {page}'**
  String mushafPageNumber(int page);

  /// Heading of the blocking error shown instead of the Mushaf when its font is missing or altered.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحميل خط المصحف'**
  String get mushafFontErrorTitle;

  /// Body of the font error: the Mushaf is never shown in another font; reinstalling fixes it.
  ///
  /// In ar, this message translates to:
  /// **'لا يُعرض المصحف بخط بديل. أعد تثبيت التطبيق لإصلاح ذلك.'**
  String get mushafFontErrorMessage;

  /// Body of the blocking error shown when the Mushaf data cannot be opened.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر فتح بيانات المصحف.'**
  String get mushafDataErrorMessage;

  /// Snackbar shown when a link into the Mushaf names an ayah or page that does not exist, and the index opens instead.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر فتح هذا الموضع، فعُرض الفهرس.'**
  String get invalidLink;

  /// Index tab that lists the 114 surahs.
  ///
  /// In ar, this message translates to:
  /// **'السور'**
  String get indexTabSurahs;

  /// Index tab that lists the 30 juz.
  ///
  /// In ar, this message translates to:
  /// **'الأجزاء'**
  String get indexTabJuz;

  /// Index row label: the surah was revealed in Makkah.
  ///
  /// In ar, this message translates to:
  /// **'مكية'**
  String get surahMakki;

  /// Index row label: the surah was revealed in Madinah.
  ///
  /// In ar, this message translates to:
  /// **'مدنية'**
  String get surahMadani;

  /// The number of ayahs in a surah, on its index row.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{آية واحدة} =2{آيتان} few{{count} آيات} many{{count} آية} other{{count} آية}}'**
  String ayahCount(int count);

  /// Second line of a surah row in the index: the Makki or Madani label, then the ayah count.
  ///
  /// In ar, this message translates to:
  /// **'{place} · {ayahs}'**
  String surahDetails(String place, String ayahs);

  /// The Mushaf page where a surah or juz starts, at the end of its index row.
  ///
  /// In ar, this message translates to:
  /// **'صفحة {page}'**
  String pageNumber(int page);

  /// Title of a juz row in the index.
  ///
  /// In ar, this message translates to:
  /// **'الجزء {number}'**
  String juzTitle(int number);

  /// Second line of a juz row: the surah name (from the content database) and the ayah number where the juz starts.
  ///
  /// In ar, this message translates to:
  /// **'من {surah}، الآية {ayah}'**
  String juzStart(String surah, int ayah);

  /// Heading of the tafsir sheet: the surah name (from the content database) and the number of the ayah shown.
  ///
  /// In ar, this message translates to:
  /// **'{surah}، الآية {ayah}'**
  String tafsirSheetTitle(String surah, int ayah);

  /// Tooltip and screen reader label of the tafsir sheet button that shows the previous ayah's tafsir.
  ///
  /// In ar, this message translates to:
  /// **'الآية السابقة'**
  String get tafsirPreviousAyah;

  /// Tooltip and screen reader label of the tafsir sheet button that shows the next ayah's tafsir.
  ///
  /// In ar, this message translates to:
  /// **'الآية التالية'**
  String get tafsirNextAyah;

  /// Attribution line of the tafsir sheet: the tafsir's name and its author, both from the content database.
  ///
  /// In ar, this message translates to:
  /// **'{name} · {author}'**
  String tafsirSource(String name, String author);

  /// Shown when one tafsir entry explains several consecutive ayahs together. from and to are ayah keys such as 4:66 and 4:68.
  ///
  /// In ar, this message translates to:
  /// **'يشرح هذا الموضع الآيات من {from} إلى {to} معًا'**
  String tafsirCoversRange(String from, String to);

  /// Shown in the tafsir sheet when the content database has no tafsir text for the ayah.
  ///
  /// In ar, this message translates to:
  /// **'لا يتوفر تفسير لهذه الآية.'**
  String get tafsirMissing;

  /// Tooltip and screen reader label of the reader's app bar button that starts a recitation from the current ayah.
  ///
  /// In ar, this message translates to:
  /// **'الاستماع من هذه الآية'**
  String get playerPlayFromHere;

  /// Tooltip of the player bar button that resumes a paused recitation.
  ///
  /// In ar, this message translates to:
  /// **'تشغيل'**
  String get playerPlay;

  /// Tooltip of the player bar button that pauses the recitation.
  ///
  /// In ar, this message translates to:
  /// **'إيقاف مؤقت'**
  String get playerPause;

  /// Tooltip of the player bar button that moves the recitation to the previous ayah.
  ///
  /// In ar, this message translates to:
  /// **'الآية السابقة'**
  String get playerPreviousAyah;

  /// Tooltip of the player bar button that moves the recitation to the next ayah.
  ///
  /// In ar, this message translates to:
  /// **'الآية التالية'**
  String get playerNextAyah;

  /// Tooltip of the player bar button that ends the recitation and closes the bar.
  ///
  /// In ar, this message translates to:
  /// **'إيقاف التلاوة'**
  String get playerStop;

  /// The player bar's position line: the surah name (from the content database) and the number of the ayah being recited.
  ///
  /// In ar, this message translates to:
  /// **'{surah}، الآية {ayah}'**
  String playerPosition(String surah, int ayah);

  /// In the player bar while one ayah is repeated: how many recitations of it are left, counting the current one.
  ///
  /// In ar, this message translates to:
  /// **'المتبقي {count}'**
  String playerRepeatsLeft(int count);

  /// Shown in the player bar when the recitation could not be loaded or played, beside the retry button. Reading is not affected.
  ///
  /// In ar, this message translates to:
  /// **'تحتاج التلاوة إلى اتصال بالإنترنت.'**
  String get playerOfflineMessage;

  /// Screen reader hint of the player bar's reciter name, which opens the reciter list.
  ///
  /// In ar, this message translates to:
  /// **'اختيار القارئ'**
  String get playerChooseReciter;

  /// Title of the sheet that lists the reciters.
  ///
  /// In ar, this message translates to:
  /// **'القارئ'**
  String get reciterPickerTitle;

  /// Recitation style of a reciter: murattal (measured recitation).
  ///
  /// In ar, this message translates to:
  /// **'مرتّل'**
  String get reciterStyleMurattal;

  /// Recitation style of a reciter: mujawwad (melodic recitation).
  ///
  /// In ar, this message translates to:
  /// **'مجوّد'**
  String get reciterStyleMujawwad;

  /// Recitation style of a reciter: mu'allim, a teaching recitation for learning pronunciation.
  ///
  /// In ar, this message translates to:
  /// **'معلّم'**
  String get reciterStyleMuallim;

  /// Tooltip and screen reader label of the reader button that switches from the page view to the continuous view, where the ayahs of a surah flow as text.
  ///
  /// In ar, this message translates to:
  /// **'العرض المتصل'**
  String get readerShowContinuous;

  /// Tooltip and screen reader label of the reader button that switches from the continuous view back to the printed-page view.
  ///
  /// In ar, this message translates to:
  /// **'عرض الصفحات'**
  String get readerShowPages;

  /// Tooltip of the reader button that opens the text size control of the continuous view, and the title of that control's sheet.
  ///
  /// In ar, this message translates to:
  /// **'حجم الخط'**
  String get readerTextSize;

  /// Screen reader label and tooltip of the button that makes the continuous view's text one step smaller.
  ///
  /// In ar, this message translates to:
  /// **'تصغير الخط'**
  String get readerTextSmaller;

  /// Screen reader label and tooltip of the button that makes the continuous view's text one step larger.
  ///
  /// In ar, this message translates to:
  /// **'تكبير الخط'**
  String get readerTextLarger;

  /// The continuous view's text size as a percentage of the default size, shown in the text size sheet.
  ///
  /// In ar, this message translates to:
  /// **'{percent}٪'**
  String readerTextSizeValue(int percent);

  /// Button at the top of the continuous view that opens the previous surah.
  ///
  /// In ar, this message translates to:
  /// **'السورة السابقة'**
  String get continuousPreviousSurah;

  /// Button at the end of the continuous view that opens the next surah.
  ///
  /// In ar, this message translates to:
  /// **'السورة التالية'**
  String get continuousNextSurah;

  /// Tooltip of the reader button that opens the go-to sheet, and the title of that sheet, where the reader jumps to a page number or to a surah and ayah number.
  ///
  /// In ar, this message translates to:
  /// **'انتقال إلى'**
  String get readerGoTo;

  /// Segment of the go-to sheet that chooses going to a Mushaf page number.
  ///
  /// In ar, this message translates to:
  /// **'صفحة'**
  String get goToByPage;

  /// Segment of the go-to sheet that chooses going to an ayah by surah and ayah number.
  ///
  /// In ar, this message translates to:
  /// **'سورة وآية'**
  String get goToBySurah;

  /// Label of the page number field in the go-to sheet.
  ///
  /// In ar, this message translates to:
  /// **'رقم الصفحة'**
  String get goToPageLabel;

  /// Label of the surah picker in the go-to sheet. The list shows each surah's number and name from the content database.
  ///
  /// In ar, this message translates to:
  /// **'السورة'**
  String get goToSurahLabel;

  /// Label of the ayah number field in the go-to sheet.
  ///
  /// In ar, this message translates to:
  /// **'رقم الآية'**
  String get goToAyahLabel;

  /// Helper text under a number field of the go-to sheet: the numbers it accepts. max is the last page (604) or the surah's ayah count.
  ///
  /// In ar, this message translates to:
  /// **'من 1 إلى {max}'**
  String goToRange(int max);

  /// Error under the page number field when it is empty or outside the Mushaf's pages. max is 604.
  ///
  /// In ar, this message translates to:
  /// **'أدخل رقم صفحة من 1 إلى {max}.'**
  String goToPageOutOfRange(int max);

  /// Error under the ayah number field when it is empty or outside the chosen surah. max is that surah's ayah count.
  ///
  /// In ar, this message translates to:
  /// **'أدخل رقم آية من 1 إلى {max}، فهذا عدد آيات السورة.'**
  String goToAyahOutOfRange(int max);

  /// Error under the surah picker when the typed text does not match a surah.
  ///
  /// In ar, this message translates to:
  /// **'اختر سورة من القائمة.'**
  String get goToSurahMissing;

  /// One surah in the go-to sheet's surah picker. number is the surah number; name is the surah name from the content database.
  ///
  /// In ar, this message translates to:
  /// **'{number}. {name}'**
  String goToSurahOption(int number, String name);

  /// The go-to sheet's button that opens the Mushaf at the chosen page or ayah.
  ///
  /// In ar, this message translates to:
  /// **'انتقال'**
  String get goToSubmit;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
