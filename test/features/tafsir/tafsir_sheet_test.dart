import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:muslim/core/l10n/generated/app_localizations.dart';
import 'package:muslim/core/routing/app_router.dart';
import 'package:muslim/core/settings/settings_repository.dart';
import 'package:muslim/core/theme/app_typography.dart';
import 'package:muslim/data/models/ayah_ref.dart';
import 'package:muslim/data/models/mushaf_page.dart';
import 'package:muslim/data/quran_repository.dart';
import 'package:muslim/data/tafsir_repository.dart';
import 'package:muslim/features/mushaf/page_view/page_line_widgets.dart';
import 'package:muslim/features/mushaf/reader_controller.dart';
import 'package:muslim/features/tafsir/tafsir_sheet.dart';

import '../../helpers/fonts.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/quran_database.dart';

// The tafsir sheet (T014). Every assertion compares ids, keys, styles or
// equality with values read from the bundled database; no Quran text,
// tafsir text or surah name appears here.

final AppLocalizations ar = lookupAppLocalizations(const Locale('ar'));

const Size phone = Size(400, 800);

/// Fails every attempt to open an HTTP connection, and counts them.
class _NoNetwork extends HttpOverrides {
  int attempts = 0;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    attempts++;
    throw const SocketException('Network unavailable in this test');
  }
}

void main() {
  late QuranRepository quran;
  late TafsirRepository tafsirs;
  late void Function() close;

  setUpAll(() async {
    await loadAppFonts();
    final database = openBundledQuranDatabase();
    final repository = QuranRepository(database);
    quran = repository;
    tafsirs = TafsirRepository(database);
    close = () {
      repository.dispose();
      database.close();
    };
  });
  tearDownAll(() => close());

  int idOf(String key) => quran.ayahIdOf(AyahRef.parse(key));

  /// The first ayah id whose stored tafsir text equals the next ayah's in
  /// the same surah: the start of a grouped entry. Read with SQL so that
  /// the expectation does not come from the code under test.
  int firstGroupedAyah(int tafsirId) {
    final database = openBundledQuranDatabase();
    addTearDown(database.close);
    return database.db.select(
          'SELECT a.ayah_id AS id FROM tafsir_texts a '
          'JOIN tafsir_texts b ON b.tafsir_id = a.tafsir_id '
          'AND b.ayah_id = a.ayah_id + 1 '
          'JOIN ayahs x ON x.id = a.ayah_id '
          'JOIN ayahs y ON y.id = b.ayah_id '
          'WHERE a.tafsir_id = ? AND x.surah_id = y.surah_id '
          'AND a.text = b.text ORDER BY a.ayah_id LIMIT 1',
          <Object?>[tafsirId],
        ).single['id']
        as int;
  }

  Future<ProviderContainer> openReader(
    WidgetTester tester,
    int page, {
    Map<String, Object> preferences = const <String, Object>{},
  }) async {
    final container = await pumpApp(
      tester,
      size: phone,
      preferences: preferences,
    );
    container.read(appRouterProvider).go(AppRoutes.mushafPage(page));
    await tester.pumpAndSettle();
    return container;
  }

  int shownPage(WidgetTester tester) {
    final view = tester.widget<PageView>(find.byType(PageView));
    return view.controller!.page!.round() + 1;
  }

  /// Taps the first word of [ayahId] on the shown page.
  Future<void> tapAyah(WidgetTester tester, int ayahId) async {
    final word = quran
        .page(quran.pageOf(ayahId))
        .lines
        .whereType<AyahLine>()
        .expand((l) => l.words)
        .firstWhere((w) => w.ayahId == ayahId);
    await tester.tap(find.byKey(MushafWordKey(word.id)));
    await tester.pumpAndSettle();
  }

  int sheetAyah(WidgetTester tester) =>
      tester.state<TafsirSheetState>(find.byType(TafsirSheet)).ayahId;

  IconButton button(WidgetTester tester, Key key) =>
      tester.widget<IconButton>(find.byKey(key));

  String? textOf(WidgetTester tester, Key key) =>
      tester.widget<Text>(find.byKey(key)).data;

  Future<void> dismiss(WidgetTester tester) async {
    // A tap on the scrim above the sheet closes it.
    await tester.tapAt(const Offset(200, 20));
    await tester.pumpAndSettle();
    expect(find.byType(TafsirSheet), findsNothing);
  }

  testWidgets('a tap opens the sheet on that ayah with its text, tafsir and '
      'attribution from the database', (tester) async {
    final id = idOf('2:255');
    final c = await openReader(tester, quran.pageOf(id));
    await tapAyah(tester, id);

    expect(find.byType(TafsirSheet), findsOneWidget);
    expect(sheetAyah(tester), id);
    expect(c.read(readerControllerProvider).highlightedAyahId, id);

    final tafsir = tafsirs.tafsirs().first;
    expect(
      textOf(tester, TafsirSheet.sourceKey),
      ar.tafsirSource(tafsir.nameAr, tafsir.author),
    );

    final ayah = tester.widget<Text>(find.byKey(TafsirSheet.ayahKey));
    expect(ayah.data, quran.ayah(id).textQpcHafs);
    expect(ayah.style!.fontFamily, AppFonts.quran);
    expect(ayah.style!.fontFamilyFallback, isEmpty);

    final body = tester.widget<SelectableText>(find.byKey(TafsirSheet.textKey));
    expect(body.data, tafsirs.text(tafsir.id, id));

    final surah = quran.surah(quran.refOf(id).surah);
    expect(
      find.text(ar.tafsirSheetTitle(surah.nameAr, quran.refOf(id).ayah)),
      findsOneWidget,
    );
  });

  testWidgets('next and previous move by one ayah across a surah boundary '
      'and move the highlight', (tester) async {
    final last = idOf('1:${quran.surah(1).ayahCount}');
    final c = await openReader(tester, quran.pageOf(last));
    await tapAyah(tester, last);
    expect(sheetAyah(tester), last);

    await tester.tap(find.byKey(TafsirSheet.nextKey));
    await tester.pumpAndSettle();
    expect(sheetAyah(tester), last + 1);
    expect(quran.refOf(last + 1), AyahRef(2, 1));
    expect(c.read(readerControllerProvider).highlightedAyahId, last + 1);
    expect(
      tester.widget<Text>(find.byKey(TafsirSheet.ayahKey)).data,
      quran.ayah(last + 1).textQpcHafs,
    );
    expect(
      tester.widget<SelectableText>(find.byKey(TafsirSheet.textKey)).data,
      tafsirs.text(tafsirs.tafsirs().first.id, last + 1),
    );

    await tester.tap(find.byKey(TafsirSheet.previousKey));
    await tester.pumpAndSettle();
    expect(sheetAyah(tester), last);
    expect(c.read(readerControllerProvider).highlightedAyahId, last);
  });

  testWidgets('previous is disabled on the first ayah of the Quran', (
    tester,
  ) async {
    await openReader(tester, quran.pageOf(1));
    await tapAyah(tester, 1);
    expect(sheetAyah(tester), 1);
    expect(button(tester, TafsirSheet.previousKey).onPressed, isNull);
    expect(button(tester, TafsirSheet.nextKey).onPressed, isNotNull);
  });

  testWidgets('next is disabled on the last ayah of the Quran', (tester) async {
    final last = quran.ayahTotal;
    await openReader(tester, quran.pageOf(last));
    await tapAyah(tester, last);
    expect(sheetAyah(tester), last);
    expect(button(tester, TafsirSheet.nextKey).onPressed, isNull);
    expect(button(tester, TafsirSheet.previousKey).onPressed, isNotNull);

    await tester.tap(find.byKey(TafsirSheet.previousKey));
    await tester.pumpAndSettle();
    expect(sheetAyah(tester), last - 1);
    expect(button(tester, TafsirSheet.nextKey).onPressed, isNotNull);
  });

  testWidgets('the reader stays on its page while the sheet moves to another '
      'page, and the highlight clears on dismissal', (tester) async {
    const page = 50;
    final c = await openReader(tester, page);
    final before = c.read(readerControllerProvider);
    expect(before.highlightedAyahId, isNull);

    // The last ayah that starts on the page; next goes to the next page.
    final last = quran
        .page(page)
        .lines
        .whereType<AyahLine>()
        .expand((l) => l.words)
        .where((w) => quran.pageOf(w.ayahId) == page)
        .last
        .ayahId;
    await tapAyah(tester, last);
    expect(shownPage(tester), page);

    await tester.tap(find.byKey(TafsirSheet.nextKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(TafsirSheet.nextKey));
    await tester.pumpAndSettle();
    expect(sheetAyah(tester), last + 2);
    expect(quran.pageOf(last + 2), greaterThan(page));
    expect(shownPage(tester), page);
    expect(c.read(readerControllerProvider).page, page);

    await dismiss(tester);
    final after = c.read(readerControllerProvider);
    expect(shownPage(tester), page);
    expect(after.page, before.page);
    expect(after.currentAyahId, before.currentAyahId);
    expect(after.highlightedAyahId, isNull);
    expect(after, before);
  });

  testWidgets('dismissal returns the highlight to its earlier ayah', (
    tester,
  ) async {
    final earlier = idOf('2:255');
    final c = await openReader(tester, quran.pageOf(earlier));
    c.read(readerControllerProvider.notifier).highlight(earlier);
    await tester.pumpAndSettle();

    await tapAyah(tester, earlier + 1);
    expect(c.read(readerControllerProvider).highlightedAyahId, earlier + 1);
    await dismiss(tester);
    expect(c.read(readerControllerProvider).highlightedAyahId, earlier);
  });

  testWidgets('a grouped entry names the ayahs it covers; a single one does '
      'not', (tester) async {
    final tafsir = tafsirs.tafsirs().first;
    final grouped = firstGroupedAyah(tafsir.id);
    final range = tafsirs.sharedRange(tafsir.id, grouped)!;
    expect(range.isSingle, isFalse);
    expect(range.contains(quran.refOf(grouped + 1)), isTrue);

    final c = await openReader(tester, quran.pageOf(grouped));
    await tapAyah(tester, grouped);
    expect(
      textOf(tester, TafsirSheet.rangeKey),
      ar.tafsirCoversRange(range.from.key, range.to.key),
    );

    // 1:1 has an entry of its own in the source (research R6).
    c.read(appRouterProvider).go(AppRoutes.mushafPage(1));
    await dismiss(tester);
    await tester.pumpAndSettle();
    expect(tafsirs.sharedRange(tafsir.id, 1)!.isSingle, isTrue);
    await tapAyah(tester, 1);
    expect(find.byKey(TafsirSheet.rangeKey), findsNothing);
  });

  testWidgets('the tafsir text is selectable and follows the font size '
      'setting', (tester) async {
    const scale = 1.5;
    final id = idOf('2:255');
    await openReader(
      tester,
      quran.pageOf(id),
      preferences: <String, Object>{SettingsRepository.fontScaleKey: scale},
    );
    await tapAyah(tester, id);

    final body = tester.widget<SelectableText>(find.byKey(TafsirSheet.textKey));
    final base = AppTypography.baseTextTheme.bodyLarge!.fontSize!;
    expect(body.style!.fontSize, base * scale);
    final ayah = tester.widget<Text>(find.byKey(TafsirSheet.ayahKey));
    expect(ayah.style!.fontSize, AppTypography.quranFontSize * scale);
  });

  testWidgets('works with the network unavailable and makes no network call', (
    tester,
  ) async {
    final previous = HttpOverrides.current;
    final network = _NoNetwork();
    HttpOverrides.global = network;
    addTearDown(() => HttpOverrides.global = previous);

    final id = idOf('2:255');
    await openReader(tester, quran.pageOf(id));
    await tapAyah(tester, id);
    await tester.tap(find.byKey(TafsirSheet.nextKey));
    await tester.pumpAndSettle();

    expect(sheetAyah(tester), id + 1);
    expect(
      tester.widget<SelectableText>(find.byKey(TafsirSheet.textKey)).data,
      tafsirs.text(tafsirs.tafsirs().first.id, id + 1),
    );
    expect(network.attempts, 0);
  });
}
