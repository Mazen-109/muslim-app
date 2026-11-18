/// Derivation of `page_lines` (research R3).
library;

import 'errors.dart';

/// Number of lines on a Mushaf page: 8 on pages 1 and 2, 15 elsewhere.
int linesOnPage(int page) => page <= 2 ? 8 : 15;

const lineTypeAyah = 'ayah';
const lineTypeSurahName = 'surah_name';
const lineTypeBasmala = 'basmala';

/// The position of one word row, as needed for layout.
class LayoutWord {
  const LayoutWord({
    required this.id,
    required this.ayahId,
    required this.surah,
    required this.ayah,
    required this.position,
    required this.page,
    required this.line,
  });

  /// Source word id; it does not follow reading order.
  final int id;

  /// Ayah id (1..6236 in Mushaf order). With [position] it gives reading
  /// order.
  final int ayahId;
  final int surah;
  final int ayah;
  final int position;
  final int page;
  final int line;
}

/// A surah's layout-relevant metadata.
class LayoutSurah {
  const LayoutSurah({required this.id, required this.bismillahPre});

  final int id;
  final bool bismillahPre;
}

/// One row of the `page_lines` table.
class PageLine {
  const PageLine(this.page, this.line, this.lineType, this.surahId);

  final int page;
  final int line;
  final String lineType;
  final int? surahId;

  @override
  bool operator ==(Object other) =>
      other is PageLine &&
      other.page == page &&
      other.line == line &&
      other.lineType == lineType &&
      other.surahId == surahId;

  @override
  int get hashCode => Object.hash(page, line, lineType, surahId);

  @override
  String toString() => 'PageLine($page, $line, $lineType, $surahId)';
}

/// Derives every line of every page (research R3).
///
/// Rules:
/// - Page `p` has [linesOnPage] lines; every word must sit on one of them.
/// - Lines are read in Mushaf order (page by page, line by line). A line with
///   words is an `ayah` line. A line with no words belongs to the next surah
///   that starts after it, possibly on a later page.
/// - A surah whose `bismillahPre` is true owns exactly two empty lines
///   directly before the line of its first word: surah name, then basmala. A
///   surah whose `bismillahPre` is false owns exactly one: the surah name.
/// - A surah's first word (ayah 1, position 1) must be the first word on its
///   line.
/// - Reading order is (ayah id, position); (page, line) must never decrease
///   along it. Word ids are source ids and play no part in the order.
///
/// Any violation throws an [ImportException]; nothing is guessed.
List<PageLine> derivePageLines({
  required List<LayoutWord> words,
  required List<LayoutSurah> surahs,
  int pageCount = 604,
}) {
  // Global slot index of (page, line).
  final slotStart = <int>[0]; // slotStart[p - 1] = index of (p, 1)
  for (var p = 1; p <= pageCount; p++) {
    slotStart.add(slotStart.last + linesOnPage(p));
  }
  final slotCount = slotStart.last;
  int slotOf(int page, int line) => slotStart[page - 1] + line - 1;
  (int, int) pageLineOf(int slot) {
    var p = 1;
    while (slotStart[p] <= slot) {
      p++;
    }
    return (p, slot - slotStart[p - 1] + 1);
  }

  final hasWords = List<bool>.filled(slotCount, false);
  final sorted = [...words]
    ..sort(
      (a, b) => a.ayahId != b.ayahId
          ? a.ayahId.compareTo(b.ayahId)
          : a.position.compareTo(b.position),
    );
  var previousSlot = -1;
  LayoutWord? previous;
  for (final w in sorted) {
    check(
      w.page >= 1 && w.page <= pageCount,
      () =>
          'word ${w.id} (${w.surah}:${w.ayah} position ${w.position}) is '
          'on page ${w.page}, outside 1..$pageCount',
    );
    check(
      w.line >= 1 && w.line <= linesOnPage(w.page),
      () =>
          'word ${w.id} (${w.surah}:${w.ayah} position ${w.position}) is '
          'on line ${w.line} of page ${w.page}, which has '
          '${linesOnPage(w.page)} lines',
    );
    final slot = slotOf(w.page, w.line);
    check(
      slot >= previousSlot,
      () =>
          'word ${w.id} (${w.surah}:${w.ayah} position ${w.position}, page '
          '${w.page} line ${w.line}) follows word ${previous!.id} '
          '(${previous.surah}:${previous.ayah} position ${previous.position}, '
          'page ${previous.page} line ${previous.line}) in reading order but '
          'is placed before it',
    );
    hasWords[slot] = true;
    previousSlot = slot;
    previous = w;
  }

  final firstWords = <int, LayoutWord>{};
  for (final w in sorted) {
    if (w.ayah == 1 && w.position == 1) {
      check(
        !firstWords.containsKey(w.surah),
        () =>
            'surah ${w.surah} has more than one first word (ayah 1, '
            'position 1)',
      );
      firstWords[w.surah] = w;
    }
  }

  final readingIndex = <int, int>{for (final (i, w) in sorted.indexed) w.id: i};
  final owner = List<PageLine?>.filled(slotCount, null);
  for (final s in surahs) {
    final first = firstWords[s.id];
    check(first != null, () => 'surah ${s.id} has no word at 1, position 1');
    final slot = slotOf(first!.page, first.line);
    // The word just before it in reading order must be on an earlier line.
    final i = readingIndex[first.id]!;
    final earlierOnLine = [
      if (i > 0 &&
          sorted[i - 1].page == first.page &&
          sorted[i - 1].line == first.line)
        sorted[i - 1],
    ];
    check(
      earlierOnLine.isEmpty,
      () =>
          'surah ${s.id} starts mid-line: page ${first.page} line '
          '${first.line} already holds word ${earlierOnLine.first.id}',
    );
    var empty = 0;
    for (var j = slot - 1; j >= 0 && !hasWords[j]; j--) {
      empty++;
    }
    final expected = s.bismillahPre ? 2 : 1;
    check(empty == expected, () {
      final kind = s.bismillahPre
          ? 'surah name and basmala'
          : 'surah name only, bismillah_pre is false';
      return 'surah ${s.id}: expected $expected empty line(s) ($kind) '
          'directly before its first ayah line (page ${first.page} line '
          '${first.line}), found $empty';
    });
    final (np, nl) = pageLineOf(slot - expected);
    owner[slot - expected] = PageLine(np, nl, lineTypeSurahName, s.id);
    if (s.bismillahPre) {
      final (bp, bl) = pageLineOf(slot - 1);
      owner[slot - 1] = PageLine(bp, bl, lineTypeBasmala, s.id);
    }
  }

  final result = <PageLine>[];
  for (var p = 1; p <= pageCount; p++) {
    for (var l = 1; l <= linesOnPage(p); l++) {
      final slot = slotOf(p, l);
      if (hasWords[slot]) {
        result.add(PageLine(p, l, lineTypeAyah, null));
      } else {
        final o = owner[slot];
        check(
          o != null,
          () =>
              'page $p line $l has no words and is not the surah name or '
              'basmala line of the next surah',
        );
        result.add(o!);
      }
    }
  }
  return result;
}
