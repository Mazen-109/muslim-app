import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/settings/settings_providers.dart';
import '../../core/settings/settings_repository.dart';
import '../../data/models/ayah_ref.dart';
import '../../data/models/mushaf_page.dart';
import '../../data/models/word.dart';
import '../../data/quran_repository.dart';

/// Where `/mushaf` opens (contracts/routes.md): an ayah, optionally
/// highlighted, or a page.
@immutable
sealed class ReaderTarget {
  const ReaderTarget();

  /// The target of a `/mushaf` query that the router has already validated.
  /// Throws [FormatException] when it names neither an ayah nor a page.
  factory ReaderTarget.fromQuery(Map<String, String> query) {
    final ayah = query['ayah'];
    if (ayah != null) {
      return AyahTarget(
        AyahRef.parse(ayah),
        highlight: query['highlight'] == '1',
      );
    }
    final page = int.tryParse(query['page'] ?? '');
    if (page == null) {
      throw FormatException('Not a /mushaf query: $query');
    }
    return PageTarget(page);
  }
}

/// `/mushaf?ayah=S:A`, with `highlight=1` when [highlight] is set.
final class AyahTarget extends ReaderTarget {
  const AyahTarget(this.ref, {this.highlight = false});

  final AyahRef ref;
  final bool highlight;

  @override
  bool operator ==(Object other) =>
      other is AyahTarget && other.ref == ref && other.highlight == highlight;

  @override
  int get hashCode => Object.hash(ref, highlight);

  @override
  String toString() => 'AyahTarget($ref, highlight: $highlight)';
}

/// `/mushaf?page=N`.
final class PageTarget extends ReaderTarget {
  const PageTarget(this.page);

  final int page;

  @override
  bool operator ==(Object other) => other is PageTarget && other.page == page;

  @override
  int get hashCode => page.hashCode;

  @override
  String toString() => 'PageTarget($page)';
}

/// The reader's one position (plan.md, Architecture Notes).
@immutable
class ReaderState {
  const ReaderState({
    required this.currentAyahId,
    required this.page,
    required this.mode,
    this.highlightedAyahId,
    this.highlightIsFlash = false,
  });

  /// The ayah the reader is on, 1 to 6236. Every view keeps it on screen.
  final int currentAyahId;

  /// The page view's page, 1 to 604: the page that holds [currentAyahId]'s
  /// first word, or the page the reader turned to.
  final int page;

  final ReadingMode mode;

  /// The ayah drawn with the highlight wash, or null.
  final int? highlightedAyahId;

  /// Whether the highlight came from a `highlight=1` link: it then marks the
  /// ayah once and is cleared when the reader turns the page.
  final bool highlightIsFlash;

  ReaderState copyWith({
    int? currentAyahId,
    int? page,
    ReadingMode? mode,
    int? Function()? highlightedAyahId,
    bool? highlightIsFlash,
  }) => ReaderState(
    currentAyahId: currentAyahId ?? this.currentAyahId,
    page: page ?? this.page,
    mode: mode ?? this.mode,
    highlightedAyahId: highlightedAyahId != null
        ? highlightedAyahId()
        : this.highlightedAyahId,
    highlightIsFlash: highlightIsFlash ?? this.highlightIsFlash,
  );

  @override
  bool operator ==(Object other) =>
      other is ReaderState &&
      other.currentAyahId == currentAyahId &&
      other.page == page &&
      other.mode == mode &&
      other.highlightedAyahId == highlightedAyahId &&
      other.highlightIsFlash == highlightIsFlash;

  @override
  int get hashCode => Object.hash(
    currentAyahId,
    page,
    mode,
    highlightedAyahId,
    highlightIsFlash,
  );

  @override
  String toString() =>
      'ReaderState(ayah $currentAyahId, page $page, ${mode.name}, '
      'highlight $highlightedAyahId${highlightIsFlash ? ' (flash)' : ''})';
}

/// Owns the current ayah, the reading mode and the highlighted ayah. The
/// page view, the continuous view, the audio follower, the tafsir sheet and
/// deep links all read and write this one position.
///
/// Every method that takes an ayah or a page needs the content database:
/// call them only once [quranRepositoryProvider] has a value (the reader
/// screen shows its loading or error state until then).
class ReaderController extends Notifier<ReaderState> {
  @override
  ReaderState build() => ReaderState(
    currentAyahId: 1,
    page: 1,
    mode: ref.read(readingModeProvider),
  );

  QuranRepository get _repository =>
      ref.read(quranRepositoryProvider).requireValue;

  /// Applies a `/mushaf` link.
  void open(ReaderTarget target) {
    switch (target) {
      case AyahTarget(:final ref, :final highlight):
        final id = _repository.ayahIdOf(ref);
        goToAyah(id);
        if (highlight) {
          state = state.copyWith(
            highlightedAyahId: () => id,
            highlightIsFlash: true,
          );
        }
      case PageTarget(:final page):
        showPage(page);
    }
  }

  /// Moves to ayah [ayahId] and its page. Keeps the highlight unless it was
  /// a one-time flash.
  void goToAyah(int ayahId) {
    final page = _repository.pageOf(ayahId);
    state = _dropFlash(state).copyWith(currentAyahId: ayahId, page: page);
  }

  /// The reader turned to [page] in the page view. The current ayah becomes
  /// the first ayah that starts on that page, so that switching to the
  /// continuous view and back returns here. Does nothing when [page] is
  /// already the current page, so the current ayah set by a link or by
  /// playback stays as it is. A one-time flash highlight is cleared.
  void showPage(int page) {
    if (page == state.page) return;
    state = _dropFlash(state).copyWith(
      page: page,
      currentAyahId: firstAyahStartingOn(_repository.page(page)),
    );
  }

  /// Sets the current ayah without clearing the highlight, for the
  /// continuous view's scrolling and the audio follower. The page view turns
  /// to the ayah's page.
  void setCurrentAyah(int ayahId) {
    if (ayahId == state.currentAyahId) return;
    state = state.copyWith(
      currentAyahId: ayahId,
      page: _repository.pageOf(ayahId),
    );
  }

  /// Draws [ayahId] with the highlight wash; null removes the highlight.
  void highlight(int? ayahId) {
    state = state.copyWith(
      highlightedAyahId: () => ayahId,
      highlightIsFlash: false,
    );
  }

  /// Switches between the page view and the continuous view and persists the
  /// choice. The current ayah is kept.
  Future<void> setMode(ReadingMode mode) async {
    state = state.copyWith(mode: mode);
    await ref.read(readingModeProvider.notifier).set(mode);
  }

  static ReaderState _dropFlash(ReaderState s) => s.highlightIsFlash
      ? s.copyWith(highlightedAyahId: () => null, highlightIsFlash: false)
      : s;
}

/// The id of the first ayah whose first word is on [page]; when no ayah
/// starts there, the first ayah on it.
int firstAyahStartingOn(MushafPage page) {
  int? first;
  for (final line in page.lines) {
    if (line is! AyahLine) continue;
    for (final word in line.words) {
      first ??= word.ayahId;
      if (word.position == 1 && word.charType == WordCharType.word) {
        return word.ayahId;
      }
    }
  }
  if (first == null) {
    throw StateError('Page ${page.number} has no ayah lines');
  }
  return first;
}

/// The reader's state and controller.
final readerControllerProvider =
    NotifierProvider<ReaderController, ReaderState>(ReaderController.new);

/// Highlights [ayahId] in the reader while [body] runs, for a sheet that
/// works on one ayah (the tafsir sheet, the ayah menu).
///
/// [body] gets a callback that moves the highlight to another ayah, for a
/// sheet that can change its ayah. When [body] completes, the highlight
/// returns to what it was before, unless something else (such as the audio
/// follower) has moved it meanwhile. A one-time link highlight counts as
/// already seen and is not restored.
Future<T> whileHighlighting<T>(
  ProviderContainer container,
  int ayahId,
  Future<T> Function(void Function(int ayahId) moveTo) body,
) async {
  final reader = container.read(readerControllerProvider.notifier);
  final before = container.read(readerControllerProvider);
  final restore = before.highlightIsFlash ? null : before.highlightedAyahId;

  var shown = ayahId;
  reader.highlight(ayahId);
  try {
    return await body((id) {
      shown = id;
      reader.highlight(id);
    });
  } finally {
    if (container.read(readerControllerProvider).highlightedAyahId == shown) {
      reader.highlight(restore);
    }
  }
}
