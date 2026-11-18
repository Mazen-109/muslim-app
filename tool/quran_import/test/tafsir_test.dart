import 'package:quran_import/quran_import.dart';
import 'package:test/test.dart';

// Placeholder tokens only (T1, T2, ...); no tafsir text.
void main() {
  TafsirEntry e(String key, String text, {int resource = 16}) =>
      TafsirEntry(resourceId: resource, verseKey: key, text: text);

  Future<List<TafsirEntry>> complete(
    List<TafsirEntry> listed,
    Map<String, TafsirGroup> groups, {
    int ayahCount = 5,
    List<String>? asked,
  }) => completeTafsirChapter(
    surah: 4,
    ayahCount: ayahCount,
    resourceId: 16,
    listed: listed,
    fetchGroup: (key) async {
      asked?.add(key);
      final g = groups[key];
      if (g == null) throw StateError('unexpected fetch $key');
      return g;
    },
  );

  TafsirGroup g(List<String> keys, String text, {int resource = 16}) =>
      TafsirGroup(resourceId: resource, verseKeys: keys, text: text);

  test('a chapter listing every ayah needs no extra request', () async {
    final asked = <String>[];
    final out = await complete(
      [for (var a = 1; a <= 5; a++) e('4:$a', 'T$a')],
      {},
      asked: asked,
    );
    expect(out.map((x) => x.text), ['T1', 'T2', 'T3', 'T4', 'T5']);
    expect(asked, isEmpty);
  });

  test('a grouped entry is given to every ayah of its group', () async {
    final asked = <String>[];
    final out = await complete(
      [e('4:1', 'T1'), e('4:2', 'T2'), e('4:5', 'T5')],
      {
        '4:3': g(['4:2', '4:3', '4:4'], 'T2'),
      },
      asked: asked,
    );
    expect(out.map((x) => x.verseKey), ['4:1', '4:2', '4:3', '4:4', '4:5']);
    expect(out.map((x) => x.text), ['T1', 'T2', 'T2', 'T2', 'T5']);
    expect(asked, ['4:3']);
  });

  test('fails when the group text differs from the listed entry', () async {
    await expectLater(
      complete(
        [e('4:1', 'T1'), e('4:2', 'T2'), e('4:4', 'T4'), e('4:5', 'T5')],
        {
          '4:3': g(['4:2', '4:3'], 'other'),
        },
      ),
      throwsA(isA<ImportException>()),
    );
  });

  test('fails when the group does not start at the listed ayah', () async {
    await expectLater(
      complete(
        [e('4:1', 'T1'), e('4:2', 'T2'), e('4:4', 'T4'), e('4:5', 'T5')],
        {
          '4:3': g(['4:3'], 'T2'),
        },
      ),
      throwsA(isA<ImportException>()),
    );
  });

  test('fails when the group does not cover the missing ayah', () async {
    await expectLater(
      complete(
        [e('4:1', 'T1'), e('4:2', 'T2'), e('4:5', 'T5')],
        {
          '4:3': g(['4:2', '4:3'], 'T2'),
          '4:4': g(['4:2', '4:3', '4:4'], 'T2'),
        },
      ),
      throwsA(isA<ImportException>()),
    );
  });

  test('fails on an entry of another resource', () async {
    await expectLater(
      complete([
        for (var a = 1; a <= 5; a++) e('4:$a', 'T$a', resource: 15),
      ], {}),
      throwsA(isA<ImportException>()),
    );
  });

  test('parseTafsirByAyah reads the verses map in order', () {
    final group = parseTafsirByAyah({
      'tafsir': {
        'verses': {
          '4:2': {'id': 2},
          '4:3': {'id': 3},
        },
        'resource_id': 16,
        'resource_name': 'r',
        'language_id': 9,
        'slug': 's',
        'text': 'T2',
      },
    }, 'ctx');
    expect(group.verseKeys, ['4:2', '4:3']);
    expect(group.text, 'T2');
    expect(group.resourceId, 16);
  });
}
