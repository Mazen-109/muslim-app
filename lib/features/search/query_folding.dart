import 'package:search_folding/search_folding.dart';

/// Folds the reader's search query so that it matches
/// `ayahs.text_search_folded` (research R9).
///
/// The folding itself is [foldArabic], the one function that
/// `tool/quran_import` also applies to build that column, so a query typed
/// with diacritics, tatweel or another form of alef, alef maqsura or taa
/// marbuta folds to the same key as its plain spelling. After folding, white
/// space at the ends is removed and every run of white space becomes one
/// space, because the folded column separates words by exactly one space.
///
/// The result is a search key; it is never shown as ayah text.
String foldQuery(String query) =>
    foldArabic(query).trim().replaceAll(_whitespace, ' ');

final RegExp _whitespace = RegExp(r'\s+');
