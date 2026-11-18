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
