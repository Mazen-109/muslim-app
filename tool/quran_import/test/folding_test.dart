import 'package:quran_import/quran_import.dart';
import 'package:test/test.dart';

// The folding rule (research R9) as the import applies it. The rule itself
// lives in packages/search_folding, shared with the app's query folding.
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

  for (final MapEntry(key: name, value: (input, expected)) in vectors.entries) {
    test(name, () => expect(foldArabic(input), expected));
  }

  test('removes both ends of every removed range', () {
    const removed = [
      0x0610, 0x061A, 0x064B, 0x065F, 0x0670, 0x06D6, 0x06DC, 0x06DF, //
      0x06E8, 0x06EA, 0x06ED, 0x0640,
    ];
    for (final c in removed) {
      expect(
        foldArabic('$b${String.fromCharCode(c)}$b'),
        '$b$b',
        reason: 'U+${c.toRadixString(16)}',
      );
    }
  });

  test('keeps the code points just outside every removed range', () {
    const kept = [
      0x060F, 0x061B, 0x064A, 0x0660, 0x066F, 0x0672, 0x06D5, 0x06DD, //
      0x06DE, 0x06E9, 0x06EE, 0x063F, 0x0641,
    ];
    for (final c in kept) {
      final s = '$b${String.fromCharCode(c)}$b';
      expect(foldArabic(s), s, reason: 'U+${c.toRadixString(16)}');
    }
  });

  test('is idempotent', () {
    for (final (input, _) in vectors.values) {
      expect(foldArabic(foldArabic(input)), foldArabic(input));
    }
  });

  test('keeps code points outside the rule, including astral ones', () {
    expect(foldArabic('x\u{1F600}y'), 'x\u{1F600}y');
  });
}
