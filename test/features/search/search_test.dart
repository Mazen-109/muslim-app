import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:muslim/core/l10n/generated/app_localizations.dart';
import 'package:muslim/core/routing/app_router.dart';
import 'package:muslim/core/settings/settings_repository.dart';
import 'package:muslim/core/theme/app_typography.dart';
import 'package:muslim/core/widgets/state_views.dart';
import 'package:muslim/data/models/ayah_ref.dart';
import 'package:muslim/data/quran_repository.dart';
import 'package:muslim/features/mushaf/quran_font_check.dart';
import 'package:muslim/features/mushaf/reader_controller.dart';
import 'package:muslim/features/search/query_folding.dart';
import 'package:muslim/features/search/search_controller.dart';
import 'package:muslim/features/search/search_screen.dart';
import 'package:search_folding/search_folding.dart';

import '../../helpers/fonts.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/quran_database.dart';

// Search (spec US6, tasks.md T019) over the real content database.
//
// The folding vectors below are ordinary modern Arabic words and synthetic
// code point sequences, never Quran text. Every query that has to match the
// Quran is taken at runtime from the database (a word of an ayah's search
// text), and the tests compare ayah ids, keys and repository values; none of
// them is written here.

void main() {
  // BEGIN shared folding vectors
  //
  // These vectors are identical in tool/quran_import/test/folding_test.dart
  // and test/features/search/search_test.dart, which checks that the two
  // copies match. The first group are synthetic code point sequences: the
  // letter U+0628 stands in for "any base letter". The second group are
  // ordinary modern Arabic words chosen for their letters; none is Quran
  // text.
  const b = '\u0628';

  final vectors = <String, (String, String)>{
    'fatha and sukun removed': ('$b\u064E$b\u0652', '$b$b'),
    'tanween removed': ('$b\u064B$b\u064C$b\u064D', '$b$b$b'),
    'shadda removed, taa marbuta to heh': ('$b\u0651\u0629', '$b\u0647'),
    'alef with hamza above to alef': ('\u0623$b', '\u0627$b'),
    'alef with hamza below to alef': ('\u0625$b', '\u0627$b'),
    'alef with madda to alef': ('\u0622$b', '\u0627$b'),
    'alef wasla to alef': ('\u0671$b', '\u0627$b'),
    'alef maqsura to yeh': ('$b\u0649', '$b\u064A'),
    'tatweel removed': ('$b\u0640\u0640\u0640$b', '$b$b'),
    'superscript alef U+0670 removed': ('$b\u0670$b', '$b$b'),
    'small high signs U+06D6 and U+06E5 removed': ('$b\u06D6$b\u06E5', '$b$b'),
    'plain letters unchanged': ('$b\u0627$b', '$b\u0627$b'),
    'hamza on waw, on yeh and alone kept': (
      '\u0624 \u0626 \u0621',
      '\u0624 \u0626 \u0621',
    ),
    'spaces and latin kept': ('a  b 12', 'a  b 12'),
    'empty': ('', ''),
    'diacritics on a word removed': ('مُهَنْدِسٌ', 'مهندس'),
    'shadda removed and taa marbuta to heh in a word': ('مُدَرِّسَة', 'مدرسه'),
    'alef with hamza above to alef in a word': ('أستاذ', 'استاذ'),
    'alef with hamza below to alef in a word': ('إنترنت', 'انترنت'),
    'alef with madda to alef in a word': ('آلة', 'اله'),
    'alef wasla to alef in a word': ('ٱلحاسوب', 'الحاسوب'),
    'alef maqsura to yeh in a word': ('مستشفى', 'مستشفي'),
    'tatweel removed in a word': ('حاســوب', 'حاسوب'),
    'superscript alef removed in a word': ('هٰكذا', 'هكذا'),
    'hamza on waw and on yeh kept in words': ('مسؤول رئيس', 'مسؤول رئيس'),
    'a phrase with diacritics and taa marbuta': (
      'مَكْتَبَةُ الجامِعَةِ',
      'مكتبه الجامعه',
    ),
  };
  // END shared folding vectors

  group('foldQuery', () {
    String spacesNormalised(String s) =>
        s.trim().replaceAll(RegExp(r'\s+'), ' ');

    for (final MapEntry(key: name, value: (input, expected))
        in vectors.entries) {
      test(name, () {
        // The shared rule, unchanged...
        expect(foldArabic(input), expected);
        // ...and the query on top of it only tidies white space.
        expect(foldQuery(input), spacesNormalised(expected));
      });
    }

    test('trims and collapses white space', () {
      expect(foldQuery('  $b$b \t\n $b  '), '$b$b $b');
      expect(foldQuery(' \u0640 '), '');
    });

    test('is idempotent', () {
      for (final (input, _) in vectors.values) {
        expect(foldQuery(foldQuery(input)), foldQuery(input));
      }
    });

    test('the vectors are the same as the import tool test', () {
      String block(String path) {
        final source = File(path).readAsStringSync();
        const begin = '// BEGIN shared folding vectors';
        const end = '// END shared folding vectors';
        final from = source.indexOf(begin);
        final to = source.indexOf(end);
        expect(from, isNonNegative, reason: path);
        expect(to, greaterThan(from), reason: path);
        return source.substring(from, to + end.length);
      }

      expect(
        block('test/features/search/search_test.dart'),
        block('tool/quran_import/test/folding_test.dart'),
      );
    });
  });

  late QuranRepository repository;
  late void Function() closeRepository;

  /// A word of the folded search column that matches a handful of ayahs,
  /// found at runtime: the first word of four or more letters in 2:255 with
  /// three to forty matches.
  late String word;

  /// Two adjacent words of the same ayah.
  late String phrase;

  List<int> idsFor(String query) =>
      repository.searchAyahs(foldQuery(query)).ayahIds;

  /// Every ayah whose folded search text contains [folded], by scanning all
  /// 6236 rows in order.
  List<int> scan(String folded) => <int>[
    for (var id = 1; id <= repository.ayahTotal; id++)
      if (repository.ayah(id).textSearchFolded.contains(folded)) id,
  ];

  setUpAll(() async {
    await loadAppFonts();
    (repository, closeRepository) = openBundledQuranRepository();
    final source = repository.ayahByRef(AyahRef(2, 255)).textSearchFolded;
    final words = source.split(' ');
    word = words.firstWhere((w) {
      if (w.runes.length < 4) return false;
      final total = repository.searchAyahs(w).total;
      return total >= 3 && total <= 40;
    });
    final i = words.indexOf(word);
    phrase = i + 1 < words.length
        ? '$word ${words[i + 1]}'
        : '${words[i - 1]} $word';
  });
  tearDownAll(() => closeRepository());

  group('repository search', () {
    test('matches exactly the ayahs that contain the query', () {
      final expected = scan(word);
      expect(expected, contains(repository.ayahIdOf(AyahRef(2, 255))));
      expect(idsFor(word), expected);

      final phraseExpected = scan(phrase);
      expect(phraseExpected, isNotEmpty);
      expect(idsFor(phrase), phraseExpected);
    });

    test('returns results in Mushaf order with their total', () {
      final pair = word.substring(0, 2);
      final result = repository.searchAyahs(pair);
      expect(result.total, greaterThan(40));
      expect(result.total, result.ayahIds.length);
      for (var i = 1; i < result.ayahIds.length; i++) {
        expect(result.ayahIds[i], greaterThan(result.ayahIds[i - 1]));
      }
      expect(result.ayahIds, scan(pair));
    });

    test('queries shorter than two letters return nothing', () {
      final letter = word.substring(0, 1);
      for (final query in <String>[
        '',
        ' ',
        letter,
        ' $letter ',
        '$letter\u064E\u0651',
        '\u0640$letter\u0640',
      ]) {
        expect(idsFor(query), isEmpty, reason: 'query "$query"');
      }
      // The letter alone is in thousands of ayahs, so the rule is what
      // returns nothing.
      expect(scan(letter), isNotEmpty);
      expect(idsFor(word.substring(0, 2)), isNotEmpty);
      expect(QuranRepository.isSearchable('$letter $letter'), isTrue);
    });

    test('escapes LIKE wildcards and the escape character', () {
      expect(QuranRepository.escapeLike(r'a%b_c\d'), r'a\%b\_c\\d');

      // Unescaped, each of these would match every ayah or many of them;
      // the search column holds no % or _ or backslash.
      final head = word.substring(0, 2);
      final tail = word.substring(2);
      for (final query in <String>[
        '%%',
        '__',
        '%_',
        r'\%',
        r'\\',
        '$head%$tail',
        '$head${'_' * tail.length}',
      ]) {
        expect(idsFor(query), isEmpty, reason: 'query "$query"');
      }
    });

    test('diacritics and tatweel give the same ayahs as the plain form', () {
      final plain = idsFor(word);
      expect(plain, isNotEmpty);
      final letters = word.split('');
      expect(idsFor(letters.map((c) => '$c\u064E').join()), plain);
      expect(idsFor(letters.map((c) => '$c\u0651\u0650').join()), plain);
      expect(idsFor(letters.join('\u0640')), plain);
      expect(idsFor('  $word  '), plain);
    });

    test('letter variants give the same ayahs as the plain form', () {
      // For each letter that the rule folds and the source's search text
      // still uses (taa marbuta and alef maqsura; its alefs are already
      // bare), a word of the database's own unfolded search text that is
      // spelled with it.
      const variants = <int>[0x0629, 0x0649];
      final found = <int, String>{};
      for (var id = 1; id <= repository.ayahTotal; id++) {
        for (final w in repository.ayah(id).textSearch.split(' ')) {
          for (final v in variants) {
            if (w.runes.length >= 3 && w.runes.contains(v)) {
              found.putIfAbsent(v, () => w);
            }
          }
        }
        if (found.length == variants.length) break;
      }
      expect(found.keys, unorderedEquals(variants));
      for (final MapEntry(key: variant, value: spelled) in found.entries) {
        final plain = foldArabic(spelled);
        expect(plain, isNot(spelled));
        final ids = idsFor(spelled);
        expect(ids, isNotEmpty, reason: 'U+${variant.toRadixString(16)}');
        expect(ids, idsFor(plain), reason: 'U+${variant.toRadixString(16)}');
      }

      // And the other way: the hamza, madda and wasla forms of alef in a
      // query match the bare alef of the search text.
      final alefWord = repository
          .ayah(1)
          .textSearchFolded
          .split(' ')
          .firstWhere((w) => w.contains('\u0627') && w.runes.length >= 3);
      for (final alef in <String>['\u0622', '\u0623', '\u0625', '\u0671']) {
        expect(
          idsFor(alefWord.replaceAll('\u0627', alef)),
          idsFor(alefWord),
          reason: alef.runes.single.toRadixString(16),
        );
      }
    });

    test('a query with no match returns an empty result', () {
      expect(repository.searchAyahs('zz'), const AyahSearchResult('zz', []));
    });
  });

  group('screen', () {
    final AppLocalizations ar = lookupAppLocalizations(const Locale('ar'));
    const Size phone = Size(400, 800);

    Uri location(ProviderContainer container) => container
        .read(appRouterProvider)
        .routerDelegate
        .currentConfiguration
        .uri;

    Future<ProviderContainer> openSearch(
      WidgetTester tester, {
      String path = AppRoutes.search,
      Map<String, Object> preferences = const <String, Object>{},
    }) async {
      final container = await pumpApp(
        tester,
        size: phone,
        preferences: preferences,
      );
      container.read(appRouterProvider).go(path);
      await tester.pumpAndSettle();
      return container;
    }

    Future<void> type(WidgetTester tester, String query) async {
      await tester.enterText(find.byKey(SearchScreen.fieldKey), query);
      await tester.pump(searchDebounce);
      await tester.pumpAndSettle();
    }

    String fieldText(WidgetTester tester) => tester
        .widget<TextField>(find.byKey(SearchScreen.fieldKey))
        .controller!
        .text;

    testWidgets('starts with a prompt and no results', (tester) async {
      await openSearch(tester);

      expect(find.text(ar.searchStartTitle), findsOneWidget);
      expect(find.byKey(SearchResultRow.countKey), findsNothing);
      expect(find.byType(SearchResultRow), findsNothing);
    });

    testWidgets('one letter keeps the prompt', (tester) async {
      await openSearch(tester);
      await type(tester, word.substring(0, 1));

      expect(find.text(ar.searchStartTitle), findsOneWidget);
      expect(find.byType(SearchResultRow), findsNothing);
    });

    testWidgets('searches once typing pauses, and shows the count', (
      tester,
    ) async {
      await openSearch(tester);
      final ids = idsFor(word);

      await tester.enterText(find.byKey(SearchScreen.fieldKey), word);
      await tester.pump(searchDebounce - const Duration(milliseconds: 10));
      expect(find.byType(SearchResultRow), findsNothing);

      await tester.pump(const Duration(milliseconds: 10));
      await tester.pumpAndSettle();
      expect(find.text(ar.searchResultCount(ids.length)), findsOneWidget);
      expect(find.byKey(SearchResultRow.keyOf(ids.first)), findsOneWidget);
    });

    testWidgets('a result shows the canonical text, surah and ayah number', (
      tester,
    ) async {
      await openSearch(tester);
      await type(tester, word);

      final id = idsFor(word).first;
      final ayah = repository.ayah(id);
      final row = find.byKey(SearchResultRow.keyOf(id));
      expect(
        find.descendant(
          of: row,
          matching: find.text(
            ar.searchResultPlace(
              repository.surah(ayah.surahId).nameAr,
              ayah.ayahNumber,
            ),
          ),
        ),
        findsOneWidget,
      );

      final text = tester.widget<Text>(
        find.byKey(SearchResultRow.textKeyOf(id)),
      );
      expect(text.data, ayah.textQpcHafs);
      expect(text.style!.fontFamily, AppFonts.quran);
      expect(text.style!.fontFamilyFallback, isEmpty);
    });

    testWidgets('a query with diacritics shows the same results', (
      tester,
    ) async {
      await openSearch(tester);
      final ids = idsFor(word);
      await type(tester, word.split('').map((c) => '$c\u064E').join());

      expect(find.text(ar.searchResultCount(ids.length)), findsOneWidget);
      expect(find.byKey(SearchResultRow.keyOf(ids.first)), findsOneWidget);
    });

    testWidgets('builds the result list lazily', (tester) async {
      await openSearch(tester);
      final pair = word.substring(0, 2);
      final total = repository.searchAyahs(pair).total;
      await type(tester, pair);

      expect(find.text(ar.searchResultCount(total)), findsOneWidget);
      expect(
        tester.widgetList(find.byType(SearchResultRow)).length,
        lessThan(total),
      );
    });

    testWidgets('a result opens the Mushaf on its ayah with a highlight', (
      tester,
    ) async {
      final container = await openSearch(tester);
      await type(tester, word);
      final id = idsFor(word).first;

      await tester.tap(find.byKey(SearchResultRow.keyOf(id)));
      await tester.pumpAndSettle();

      expect(location(container).path, AppRoutes.mushaf);
      expect(location(container).queryParameters, <String, String>{
        'ayah': repository.refOf(id).key,
        'highlight': '1',
      });
      final reader = container.read(readerControllerProvider);
      expect(reader.currentAyahId, id);
      expect(reader.highlightedAyahId, id);
      expect(reader.highlightIsFlash, isTrue);

      // Search from the reader again shows the same query and results.
      await tester.tap(find.byTooltip(ar.screenSearch));
      await tester.pumpAndSettle();
      expect(fieldText(tester), word);
      expect(find.byKey(SearchResultRow.keyOf(id)), findsOneWidget);
    });

    testWidgets('no match says so and keeps the query editable', (
      tester,
    ) async {
      await openSearch(tester);
      await type(tester, 'zz');

      expect(find.text(ar.searchNoResultsTitle), findsOneWidget);
      expect(find.byType(SearchResultRow), findsNothing);
      final field = tester.widget<TextField>(find.byKey(SearchScreen.fieldKey));
      expect(field.enabled ?? true, isTrue);
      expect(fieldText(tester), 'zz');

      await type(tester, word);
      expect(find.text(ar.searchNoResultsTitle), findsNothing);
      expect(find.byType(SearchResultRow), findsWidgets);
    });

    testWidgets('the clear button empties the query', (tester) async {
      await openSearch(tester);
      await type(tester, word);

      await tester.tap(find.byTooltip(ar.searchClear));
      await tester.pumpAndSettle();

      expect(fieldText(tester), isEmpty);
      expect(find.text(ar.searchStartTitle), findsOneWidget);
    });

    testWidgets('the q parameter searches at once', (tester) async {
      final query = Uri.encodeQueryComponent(word);
      await openSearch(tester, path: '${AppRoutes.search}?q=$query');

      expect(fieldText(tester), word);
      expect(
        find.text(ar.searchResultCount(idsFor(word).length)),
        findsOneWidget,
      );
    });

    testWidgets('shows an error, not results, when the font check fails', (
      tester,
    ) async {
      final container = await pumpApp(
        tester,
        size: phone,
        overrides: [
          quranFontAssetLoaderProvider.overrideWithValue(
            (key) async => throw StateError('missing'),
          ),
        ],
      );
      container.read(appRouterProvider).go(AppRoutes.search);
      await tester.pumpAndSettle();
      await type(tester, word);

      expect(find.text(ar.mushafFontErrorTitle), findsOneWidget);
      expect(find.byType(SearchResultRow), findsNothing);
    });

    testWidgets('shows an error when the database cannot be opened', (
      tester,
    ) async {
      final container = await pumpApp(
        tester,
        size: phone,
        overrides: [
          quranRepositoryProvider.overrideWith(
            (ref) async => throw StateError('unavailable'),
          ),
        ],
      );
      container.read(appRouterProvider).go(AppRoutes.search);
      await tester.pumpAndSettle();
      await type(tester, word);

      expect(find.byType(ErrorStateView), findsOneWidget);
      expect(find.byType(RetryButton), findsOneWidget);
    });

    group('golden', () {
      for (final preference in ThemePreference.values) {
        testWidgets('results in the ${preference.storageValue} theme', (
          tester,
        ) async {
          await openSearch(
            tester,
            path: '${AppRoutes.search}?q=${Uri.encodeQueryComponent(word)}',
            preferences: <String, Object>{
              SettingsRepository.themeKey: preference.storageValue,
            },
          );

          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile(
              '../../goldens/search/results_${preference.storageValue}.png',
            ),
          );
        });
      }
    });
  });
}
