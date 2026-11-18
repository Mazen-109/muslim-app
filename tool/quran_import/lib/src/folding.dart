/// The search folding rule of research R9.
library;

/// Folds Arabic text for search matching (research R9).
///
/// Used at import time to derive `ayahs.text_search_folded` from
/// `ayahs.text_search`, and meant to be applied unchanged to the user's query
/// in the app, so both sides match. The result is a search key only and is
/// never displayed.
///
/// The rule works one Unicode code point at a time and applies exactly these
/// mappings; every other code point, including spaces and punctuation, is
/// kept unchanged:
///
/// Removed (diacritics and tatweel):
/// - U+0610..U+061A  Arabic honorific and small Quranic signs above/below
/// - U+064B..U+065F  fathatan, dammatan, kasratan, fatha, damma, kasra,
///   shadda, sukun, maddah above, hamza above, hamza below, and the other
///   combining marks of that block
/// - U+0670          superscript (dagger) alef
/// - U+06D6..U+06DC  small high Quranic annotation signs
/// - U+06DF..U+06E8  small high/low signs, small waw, small yeh, small high
///   noon and related marks
/// - U+06EA..U+06ED  small low/high Quranic marks
/// - U+0640          tatweel
///
/// Replaced:
/// - U+0622 alef with madda above, U+0623 alef with hamza above,
///   U+0625 alef with hamza below, U+0671 alef wasla -> U+0627 alef
/// - U+0649 alef maqsura -> U+064A yeh
/// - U+0629 taa marbuta -> U+0647 heh
///
/// The function is pure: same input, same output, no locale dependence.
String foldArabic(String input) {
  final out = StringBuffer();
  for (final rune in input.runes) {
    if (_isRemoved(rune)) continue;
    out.writeCharCode(_replacement(rune));
  }
  return out.toString();
}

bool _isRemoved(int c) =>
    (c >= 0x0610 && c <= 0x061A) ||
    (c >= 0x064B && c <= 0x065F) ||
    c == 0x0670 ||
    (c >= 0x06D6 && c <= 0x06DC) ||
    (c >= 0x06DF && c <= 0x06E8) ||
    (c >= 0x06EA && c <= 0x06ED) ||
    c == 0x0640;

int _replacement(int c) => switch (c) {
  0x0622 || 0x0623 || 0x0625 || 0x0671 => 0x0627,
  0x0649 => 0x064A,
  0x0629 => 0x0647,
  _ => c,
};
