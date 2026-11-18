import 'package:flutter_test/flutter_test.dart';
import 'package:muslim/data/models/ayah_ref.dart';

void main() {
  // Synthetic counts: every surah has 7 ayahs, except surah 2 with 286.
  final counts = List<int>.generate(114, (i) => i == 1 ? 286 : 7);

  group('AyahRef', () {
    test('parses and formats keys', () {
      final ref = AyahRef.parse('2:255');
      expect(ref, AyahRef(2, 255));
      expect(ref.surah, 2);
      expect(ref.ayah, 255);
      expect(ref.key, '2:255');
      expect(ref.toString(), '2:255');
      expect(AyahRef.parse('114:6').key, '114:6');
      expect(AyahRef.parse('1:1'), AyahRef(1, 1));
    });

    test('rejects malformed keys', () {
      for (final key in <String>[
        '',
        '2',
        '2:',
        ':5',
        '2:255:1',
        ' 2:255',
        '2:255 ',
        '02:255',
        '2:0255',
        '-2:5',
        '+2:5',
        '2.0:5',
        'a:b',
        '2-255',
        '1000:1',
      ]) {
        expect(
          () => AyahRef.parse(key),
          throwsFormatException,
          reason: '"$key"',
        );
        expect(AyahRef.tryParse(key), isNull, reason: '"$key"');
      }
    });

    test('rejects surahs outside 1 to 114 and ayahs below 1', () {
      expect(() => AyahRef(0, 1), throwsRangeError);
      expect(() => AyahRef(115, 1), throwsRangeError);
      expect(() => AyahRef(1, 0), throwsRangeError);
      expect(() => AyahRef(1, -1), throwsRangeError);
      expect(AyahRef.tryParse('0:1'), isNull);
      expect(AyahRef.tryParse('115:1'), isNull);
      expect(AyahRef.tryParse('1:0'), isNull);
    });

    test('validates the ayah against surah ayah counts', () {
      expect(AyahRef(2, 286).isValidFor(counts), isTrue);
      expect(AyahRef(2, 287).isValidFor(counts), isFalse);
      expect(AyahRef(1, 7).isValidFor(counts), isTrue);
      expect(AyahRef(1, 8).isValidFor(counts), isFalse);
      expect(() => AyahRef(1, 8).checkAgainst(counts), throwsRangeError);
      AyahRef(1, 7).checkAgainst(counts);
      expect(() => AyahRef(1, 1).checkAgainst(<int>[7]), throwsArgumentError);
      expect(AyahRef.parse('2:286', ayahCounts: counts), AyahRef(2, 286));
      expect(
        () => AyahRef.parse('2:287', ayahCounts: counts),
        throwsFormatException,
      );
      expect(AyahRef.tryParse('1:8', ayahCounts: counts), isNull);
    });

    test('compares in Mushaf order and has value equality', () {
      expect(AyahRef(1, 7) < AyahRef(2, 1), isTrue);
      expect(AyahRef(2, 10) > AyahRef(2, 9), isTrue);
      expect(AyahRef(2, 10) <= AyahRef(2, 10), isTrue);
      expect(AyahRef(3, 1) >= AyahRef(2, 286), isTrue);
      expect(AyahRef(2, 10).compareTo(AyahRef(2, 10)), 0);
      expect(AyahRef(2, 10), AyahRef(2, 10));
      expect(AyahRef(2, 10).hashCode, AyahRef(2, 10).hashCode);
      expect(AyahRef(2, 10), isNot(AyahRef(10, 2)));
      final sorted = <AyahRef>[AyahRef(3, 1), AyahRef(1, 2), AyahRef(1, 1)]
        ..sort();
      expect(sorted, <AyahRef>[AyahRef(1, 1), AyahRef(1, 2), AyahRef(3, 1)]);
    });
  });

  group('AyahRange', () {
    test('contains its ends and everything between', () {
      final range = AyahRange(AyahRef(4, 66), AyahRef(4, 68));
      expect(range.contains(AyahRef(4, 66)), isTrue);
      expect(range.contains(AyahRef(4, 67)), isTrue);
      expect(range.contains(AyahRef(4, 68)), isTrue);
      expect(range.contains(AyahRef(4, 65)), isFalse);
      expect(range.contains(AyahRef(4, 69)), isFalse);
      expect(range.contains(AyahRef(5, 67)), isFalse);
      expect(range.isSingle, isFalse);
      expect(range.toString(), '4:66-4:68');
    });

    test('spans surahs in Mushaf order', () {
      final range = AyahRange(AyahRef(1, 7), AyahRef(2, 5));
      expect(range.contains(AyahRef(2, 1)), isTrue);
      expect(range.contains(AyahRef(1, 6)), isFalse);
    });

    test('rejects from after to', () {
      expect(
        () => AyahRange(AyahRef(4, 68), AyahRef(4, 66)),
        throwsArgumentError,
      );
    });

    test('single ranges and value equality', () {
      final single = AyahRange.single(AyahRef(2, 255));
      expect(single.isSingle, isTrue);
      expect(single, AyahRange(AyahRef(2, 255), AyahRef(2, 255)));
      expect(single.hashCode, AyahRange.single(AyahRef(2, 255)).hashCode);
    });
  });
}
