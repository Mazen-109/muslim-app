import 'package:quran_import/quran_import.dart';
import 'package:test/test.dart';

void main() {
  group('resolveTemplate', () {
    test('relative paths resolve against verses.quran.com', () {
      expect(
        resolveTemplate('Folder/mp3/002001.mp3', '2:1'),
        const ResolvedTemplate(
          'https://verses.quran.com/Folder/mp3/{surah3}{ayah3}.mp3',
          'quran-com-audio',
        ),
      );
    });

    test('the EveryAyah mirror maps to the everyayah.com origin', () {
      expect(
        resolveTemplate(
          '//mirrors.quranicaudio.com/everyayah/Some_Folder_64kbps/114006.mp3',
          '114:6',
        ),
        const ResolvedTemplate(
          'https://everyayah.com/data/Some_Folder_64kbps/{surah3}{ayah3}.mp3',
          'everyayah',
        ),
      );
    });

    test('the same folder gives the same template for every ayah', () {
      expect(
        resolveTemplate('A/mp3/001001.mp3', '1:1'),
        resolveTemplate('A/mp3/286286.mp3', '286:286'),
      );
    });

    for (final (name, url, key) in [
      ('file name of another ayah', 'A/mp3/002002.mp3', '2:1'),
      ('unpadded file name', 'A/mp3/21.mp3', '2:1'),
      ('another protocol-relative host', '//cdn.example/A/001001.mp3', '1:1'),
      ('an absolute URL', 'https://cdn.example/A/001001.mp3', '1:1'),
      ('a root-relative path', '/A/001001.mp3', '1:1'),
      ('a parent directory', 'A/../B/001001.mp3', '1:1'),
      ('no folder', '001001.mp3', '1:1'),
      ('an invalid verse key', 'A/001001.mp3', '1-1'),
    ]) {
      test('fails on $name', () {
        expect(
          () => resolveTemplate(url, key),
          throwsA(isA<ImportException>()),
        );
      });
    }
  });

  test('expandTemplate pads surah and ayah to three digits', () {
    expect(
      expandTemplate('https://h/x/{surah3}{ayah3}.mp3', 1, 1),
      'https://h/x/001001.mp3',
    );
    expect(
      expandTemplate('https://h/x/{surah3}{ayah3}.mp3', 114, 6),
      'https://h/x/114006.mp3',
    );
  });

  test('normaliseStyle lower-cases known styles and keeps null', () {
    expect(normaliseStyle('Muallim', 12), 'muallim');
    expect(normaliseStyle('Murattal', 9), 'murattal');
    expect(normaliseStyle('Mujawwad', 1), 'mujawwad');
    expect(normaliseStyle(null, 7), isNull);
    expect(() => normaliseStyle('Other', 3), throwsA(isA<ImportException>()));
  });

  test('reciter plan order and sources', () {
    expect(reciterPlans.map((r) => r.id), [12, 6, 9, 7, 2]);
    expect(reciterPlans.map((r) => r.sourceId), [
      'everyayah',
      'everyayah',
      'quran-com-audio',
      'quran-com-audio',
      'quran-com-audio',
    ]);
  });
}
