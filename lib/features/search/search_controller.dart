import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/quran_repository.dart';
import 'query_folding.dart';

/// How long typing must pause before the query is searched.
const Duration searchDebounce = Duration(milliseconds: 300);

/// The search query that results are shown for, as the reader typed it.
///
/// [edit] applies a query once typing pauses for [searchDebounce]; [submit]
/// applies it at once. The query outlives the screen, so returning to search
/// from the Mushaf shows the same results again.
class SearchQueryController extends Notifier<String> {
  Timer? _debounce;

  @override
  String build() {
    ref.onDispose(() => _debounce?.cancel());
    return '';
  }

  /// The reader changed the text to [query]: search it after a pause.
  void edit(String query) {
    _debounce?.cancel();
    _debounce = Timer(searchDebounce, () => state = query);
  }

  /// Searches [query] now, for the keyboard's search action, the clear
  /// button and a `q` route parameter.
  void submit(String query) {
    _debounce?.cancel();
    state = query;
  }
}

/// The applied search query.
final searchQueryProvider = NotifierProvider<SearchQueryController, String>(
  SearchQueryController.new,
);

/// The results of the applied query: null while it is too short to search
/// (fewer than [QuranRepository.minSearchLetters] letters after folding),
/// otherwise the matching ayahs. Loading and errors come from the content
/// database.
final searchResultsProvider = Provider<AsyncValue<AyahSearchResult?>>((ref) {
  final folded = foldQuery(ref.watch(searchQueryProvider));
  if (!QuranRepository.isSearchable(folded)) {
    return const AsyncData<AyahSearchResult?>(null);
  }
  return ref
      .watch(quranRepositoryProvider)
      .whenData<AyahSearchResult?>((repo) => repo.searchAyahs(folded));
});
