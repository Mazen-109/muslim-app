import 'package:quran_import/quran_import.dart';
import 'package:test/test.dart';

// Placeholder tokens only (T1, T2, ...); no tafsir text.
void main() {
  TafsirEntry e(String key, String text, {int resource = 16}) =>
      TafsirEntry(resourceId: resource, verseKey: key, text: text);

  TafsirGroup g(List<String> keys, String text, {int resource = 16}) =>
      TafsirGroup(resourceId: resource, verseKeys: keys, text: text);

  List<String> run(int from, int to) => [
    for (var a = from; a <= to; a++) '4:$a',
  ];

  List<TafsirEntry> complete(
    List<TafsirEntry> listed,
    Map<String, TafsirGroup> groups, {
    int ayahCount = 5,
  }) => completeTafsirChapter(
    surah: 4,
    ayahCount: ayahCount,
    resourceId: 16,
    listed: listed,
    groups: groups,
  );

  test('unlistedTafsirKeys lists the gaps', () {
    expect(
      unlistedTafsirKeys(
        surah: 4,
        ayahCount: 5,
        resourceId: 16,
        listed: [e('4:1', 'T1'), e('4:2', 'T2'), e('4:5', 'T5')],
      ),
      ['4:3', '4:4'],
    );
  });

  test('a chapter listing every ayah needs no by_ayah response', () {
    final out = complete([for (var a = 1; a <= 5; a++) e('4:$a', 'T$a')], {});
    expect(out.map((x) => x.text), ['T1', 'T2', 'T3', 'T4', 'T5']);
  });

  test('each unlisted ayah gets the text of its group head', () {
    final out = complete(
      [e('4:1', 'T1'), e('4:2', 'T2'), e('4:5', 'T5')],
      {'4:3': g(run(2, 4), 'T2'), '4:4': g(run(2, 4), 'T2')},
    );
    expect(out.map((x) => x.verseKey), run(1, 5));
    expect(out.map((x) => x.text), ['T1', 'T2', 'T2', 'T2', 'T5']);
  });

  test('a verses map cut at 10 keys is accepted for later ayahs', () {
    final listed = [e('4:1', 'T1'), e('4:13', 'T13')];
    final cut = g(run(1, 10), 'T1');
    final out = complete(listed, {
      for (var a = 2; a <= 12; a++) '4:$a': cut,
    }, ayahCount: 13);
    expect(out.map((x) => x.text).toSet(), {'T1', 'T13'});
    expect(out.where((x) => x.text == 'T1'), hasLength(12));
  });

  test('a short map that does not contain the ayah fails', () {
    expect(
      () => complete(
        [e('4:1', 'T1'), e('4:2', 'T2'), e('4:5', 'T5')],
        {'4:3': g(run(2, 3), 'T2'), '4:4': g(run(2, 3), 'T2')},
      ),
      throwsA(isA<ImportException>()),
    );
  });

  test('fails when the text differs from the listed head', () {
    expect(
      () => complete(
        [e('4:1', 'T1'), e('4:2', 'T2'), e('4:4', 'T4'), e('4:5', 'T5')],
        {'4:3': g(run(2, 3), 'other')},
      ),
      throwsA(isA<ImportException>()),
    );
  });

  test('fails when the group does not start at the listed head', () {
    expect(
      () => complete(
        [e('4:1', 'T1'), e('4:2', 'T2'), e('4:4', 'T4'), e('4:5', 'T5')],
        {'4:3': g(run(3, 3), 'T2')},
      ),
      throwsA(isA<ImportException>()),
    );
  });

  test('fails when a by_ayah response is missing', () {
    expect(
      () => complete([e('4:1', 'T1'), e('4:2', 'T2')], {}),
      throwsA(isA<ImportException>()),
    );
  });

  test('fails on an entry of another resource', () {
    expect(
      () => complete([
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
