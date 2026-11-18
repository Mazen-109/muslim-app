/// Builds `quran.db` and `manifest.json` from the Quran.com API v4.
///
/// Usage: `dart run bin/quran_import.dart --out <dir> [--cache <dir>]`
library;

import 'dart:io';
import 'dart:isolate';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:quran_import/quran_import.dart';
import 'package:sqlite3/sqlite3.dart';

const toolVersion = '1.0.0';
const datasetVersion = 1;
const apiBase = 'https://api.quran.com/api/v4';
const tafsirId = 16;

Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addOption('out', help: 'Output directory for quran.db and manifest.json')
    ..addOption(
      'cache',
      help:
          'Directory for cached raw API responses '
          '(default: tool/quran_import/.cache)',
    )
    ..addFlag('help', abbr: 'h', negatable: false);
  final ArgResults opts;
  try {
    opts = parser.parse(args);
  } on FormatException catch (e) {
    stderr.writeln('${e.message}\n${parser.usage}');
    exit(64);
  }
  if (opts.flag('help') || opts.option('out') == null) {
    stdout.writeln(
      'Usage: dart run bin/quran_import.dart --out <dir> [--cache <dir>]\n'
      '${parser.usage}',
    );
    exit(opts.flag('help') ? 0 : 64);
  }
  final stopwatch = Stopwatch()..start();
  final cacheDir = opts.option('cache') ?? await _defaultCacheDir();
  final client = ApiClient(cacheDir: Directory(cacheDir), log: stdout.writeln);
  try {
    await run(client, Directory(opts.option('out')!));
    stdout.writeln(
      'done in ${(stopwatch.elapsedMilliseconds / 1000).toStringAsFixed(1)}s: '
      '${client.requests.length} requests recorded, '
      '${client.networkRequests} network attempts, '
      '${client.cacheHits} cache hits',
    );
  } on ImportException catch (e) {
    stderr.writeln('IMPORT FAILED: ${e.message}');
    exitCode = 1;
  } finally {
    client.close();
  }
}

Future<void> run(ApiClient client, Directory outDir) async {
  final generatedAt = DateTime.now().toUtc().toIso8601String();

  stdout.writeln('chapters');
  final chapters = parseChapters(
    await client.getJson('$apiBase/chapters?language=ar'),
  )..sort((a, b) => a.id.compareTo(b.id));
  check(
    chapters.length == expectedSurahs,
    () => 'chapters: ${chapters.length}, expected $expectedSurahs',
  );
  for (final (i, c) in chapters.indexed) {
    check(c.id == i + 1, () => 'chapters: ids are not 1..114');
  }

  stdout.writeln('verses by page (1..$expectedPages)');
  final pageJson = await client.getJsonAll([
    for (var page = 1; page <= expectedPages; page++)
      '$apiBase/verses/by_page/$page?words=true&per_page=300'
          '&word_fields=text_qpc_hafs,line_number,page_number,v1_page,line_v1'
          '&fields=text_qpc_hafs,text_uthmani,text_imlaei_simple',
  ]);
  final verses = mergeVerses([
    for (final (i, json) in pageJson.indexed) parseVersesByPage(json, i + 1),
  ]);

  stdout.writeln('juzs');
  final juzs = dedupeJuzs(parseJuzs(await client.getJson('$apiBase/juzs')));

  stdout.writeln('tafsir $tafsirId');
  final tafsir = parseTafsirResource(
    await client.getJson('$apiBase/resources/tafsirs?language=ar'),
    tafsirId,
  );
  final tafsirEntries = <TafsirEntry>[];
  var tafsirListed = 0;
  for (final c in chapters) {
    final listed = await _allPages(
      client,
      '$apiBase/tafsirs/$tafsirId/by_chapter/${c.id}?per_page=300',
      (json, ctx) => parseTafsirPage(json, ctx),
    );
    tafsirListed += listed.length;
    tafsirEntries.addAll(
      await completeTafsirChapter(
        surah: c.id,
        ayahCount: c.versesCount,
        resourceId: tafsirId,
        listed: listed,
        fetchGroup: (key) async {
          final url = '$apiBase/tafsirs/$tafsirId/by_ayah/$key';
          return parseTafsirByAyah(await client.getJson(url), url);
        },
      ),
    );
  }
  stdout.writeln(
    '  ${tafsirEntries.length} ayahs; '
    '${tafsirEntries.length - tafsirListed} share a grouped entry',
  );

  stdout.writeln('recitations');
  final recitations = parseRecitations(
    await client.getJson('$apiBase/resources/recitations?language=ar'),
    reciterPlans.map((r) => r.id),
  );
  final resolved = <ResolvedReciter>[];
  for (final (i, plan) in reciterPlans.indexed) {
    stdout.writeln('  recitation ${plan.id}: 114 chapters');
    final template = await _reciterTemplate(client, plan, chapters);
    resolved.add(ResolvedReciter(recitations[plan.id]!, template, i + 1));
  }

  stdout.writeln('assembling and validating');
  final dataset = assembleDataset(
    chapters: chapters,
    verses: verses,
    juzs: juzs,
    tafsir: tafsir,
    tafsirEntries: tafsirEntries,
    reciters: resolved,
  );
  validateDataset(dataset);

  stdout.writeln('probing audio for 1:1 and 114:6');
  final lastSurah = chapters.last;
  final bySortOrder = [...dataset.reciters]
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  for (final r in bySortOrder) {
    for (final (s, a) in [(1, 1), (lastSurah.id, lastSurah.versesCount)]) {
      await client.probe(expandTemplate(r.urlTemplate, s, a));
    }
  }

  stdout.writeln('writing database');
  outDir.createSync(recursive: true);
  final dbPath = p.join(outDir.path, 'quran.db');
  final tmpPath = '$dbPath.tmp';
  writeDatabase(tmpPath, dataset, {
    'dataset_version': '$datasetVersion',
    'generated_at': generatedAt,
    'source': apiBase,
  });

  // Hash what is stored and require it to equal the hash of the in-memory
  // rows: this proves SQLite stored every value unaltered.
  final db = sqlite3.open(tmpPath, mode: OpenMode.readOnly);
  final Map<String, String> hashes;
  final Map<String, int> counts;
  try {
    hashes = hashAllTables(db);
    counts = countRows(db);
  } finally {
    db.close();
  }
  for (final MapEntry(key: table, value: rows) in dataset.tables.entries) {
    final memory = hashRows(rows.map((r) => r.values));
    check(
      memory == hashes[table],
      () => '$table: hash of stored rows differs from the imported rows',
    );
  }
  checkManifestCounts(counts);

  final manifest = buildManifest(
    datasetVersion: datasetVersion,
    generatedAt: generatedAt,
    toolVersion: toolVersion,
    requests: client.requests,
    counts: counts,
    tableHashes: hashes,
  );
  File(tmpPath).renameSync(dbPath);
  File(p.join(outDir.path, 'manifest.json')).writeAsStringSync(manifest);

  stdout.writeln('counts: $counts');
  for (final e in hashes.entries) {
    stdout.writeln('  ${e.key.padRight(13)} ${e.value}');
  }
  stdout.writeln('quran.db: ${File(dbPath).lengthSync()} bytes');
}

/// `.cache` inside this package, wherever the tool is run from.
Future<String> _defaultCacheDir() async {
  final lib = await Isolate.resolvePackageUri(
    Uri.parse('package:quran_import/quran_import.dart'),
  );
  return p.join(p.dirname(p.dirname(lib!.toFilePath())), '.cache');
}

/// Fetches every page of a paginated endpoint, following `next_page`.
Future<List<T>> _allPages<T>(
  ApiClient client,
  String url,
  Paged<T> Function(Object? json, String ctx) parse,
) async {
  final items = <T>[];
  int? page = 1;
  while (page != null) {
    final pageUrl = page == 1 ? url : '$url&page=$page';
    final result = parse(await client.getJson(pageUrl), pageUrl);
    items.addAll(result.items);
    check(
      result.nextPage == null || result.nextPage! > page,
      () => '$pageUrl: next_page ${result.nextPage} does not advance',
    );
    page = result.nextPage;
  }
  return items;
}

/// Fetches all 114 chapters of a recitation and checks that every audio
/// file follows one template, with one file per ayah.
Future<ResolvedTemplate> _reciterTemplate(
  ApiClient client,
  ReciterPlan plan,
  List<Chapter> chapters,
) async {
  final perChapter = <List<AudioFile>>[];
  for (final c in chapters) {
    perChapter.add(
      await _allPages(
        client,
        '$apiBase/recitations/${plan.id}/by_chapter/${c.id}?per_page=300',
        (json, ctx) => parseAudioPage(json, ctx),
      ),
    );
  }
  ResolvedTemplate? template;
  for (final (i, files) in perChapter.indexed) {
    final c = chapters[i];
    final keys = <String>{};
    for (final f in files) {
      final (s, _) = parseVerseKey(f.verseKey);
      check(
        s == c.id,
        () => 'recitation ${plan.id} chapter ${c.id}: file for ${f.verseKey}',
      );
      check(
        keys.add(f.verseKey),
        () => 'recitation ${plan.id}: two files for ${f.verseKey}',
      );
      final t = resolveTemplate(f.url, f.verseKey);
      template ??= t;
      check(
        t == template,
        () =>
            'recitation ${plan.id}: ${f.verseKey} resolves to $t, '
            'other ayahs to $template',
      );
    }
    check(
      keys.length == c.versesCount,
      () =>
          'recitation ${plan.id} chapter ${c.id}: ${keys.length} files, '
          'expected ${c.versesCount}',
    );
  }
  check(
    template!.sourceId == plan.sourceId,
    () =>
        'recitation ${plan.id}: served by ${template!.sourceId}, expected '
        '${plan.sourceId}',
  );
  return template;
}
