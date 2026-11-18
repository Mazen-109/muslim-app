/// Reciter selection and audio URL templates (research R7).
library;

import 'errors.dart';

/// Placeholder for the zero-padded 3-digit surah number.
const surahPlaceholder = '{surah3}';

/// Placeholder for the zero-padded 3-digit ayah number.
const ayahPlaceholder = '{ayah3}';

/// Base for relative audio paths returned by the Quran.com API.
const quranComAudioBase = 'https://verses.quran.com/';

/// The EveryAyah mirror prefix the API returns for some recitations. It is
/// never requested: such paths are mapped to [everyAyahBase].
const everyAyahMirrorPrefix = '//mirrors.quranicaudio.com/everyayah/';

/// The EveryAyah origin used instead of the mirror.
const everyAyahBase = 'https://everyayah.com/data/';

/// Sources-registry id for files served by EveryAyah.
const sourceEveryAyah = 'everyayah';

/// Sources-registry id for files served by verses.quran.com.
const sourceQuranComAudio = 'quran-com-audio';

/// One reciter the import includes, in display order.
class ReciterPlan {
  const ReciterPlan(this.id, this.sourceId);

  final int id;
  final String sourceId;
}

/// The MVP reciters (research R7); `sort_order` is the index plus one.
const reciterPlans = [
  ReciterPlan(12, sourceEveryAyah),
  ReciterPlan(6, sourceEveryAyah),
  ReciterPlan(9, sourceQuranComAudio),
  ReciterPlan(7, sourceQuranComAudio),
  ReciterPlan(2, sourceQuranComAudio),
];

/// Allowed values of `reciters.style`.
const reciterStyles = {'murattal', 'mujawwad', 'muallim'};

/// Lower-cases the API's recitation style and checks it is allowed, or
/// returns null when the API gives none.
String? normaliseStyle(String? apiStyle, int recitationId) {
  if (apiStyle == null) return null;
  final s = apiStyle.toLowerCase();
  check(
    reciterStyles.contains(s),
    () => 'recitation $recitationId: unknown style "$apiStyle"',
  );
  return s;
}

String pad3(int n) => n.toString().padLeft(3, '0');

/// The file name an audio file for [surah]:[ayah] must have.
String audioFileName(int surah, int ayah) => '${pad3(surah)}${pad3(ayah)}.mp3';

/// A URL template and the source that serves it.
class ResolvedTemplate {
  const ResolvedTemplate(this.template, this.sourceId);

  final String template;
  final String sourceId;

  @override
  bool operator ==(Object other) =>
      other is ResolvedTemplate &&
      other.template == template &&
      other.sourceId == sourceId;

  @override
  int get hashCode => Object.hash(template, sourceId);

  @override
  String toString() => 'ResolvedTemplate($template, $sourceId)';
}

final _folderPattern = RegExp(r'^[A-Za-z0-9_./-]+/$');

/// Derives the URL template from one audio URL as returned by the API.
///
/// - The URL must end with `/{SSS}{AAA}.mp3` matching [verseKey].
/// - A path starting with [everyAyahMirrorPrefix] maps to
///   `https://everyayah.com/data/<folder>/{surah3}{ayah3}.mp3` (source
///   [sourceEveryAyah]).
/// - A relative path (no scheme, no leading slash) resolves against
///   [quranComAudioBase] (source [sourceQuranComAudio]).
/// - Anything else fails.
ResolvedTemplate resolveTemplate(String url, String verseKey) {
  final (surah, ayah) = parseVerseKey(verseKey);
  final fileName = audioFileName(surah, ayah);
  check(
    url.endsWith('/$fileName'),
    () => 'audio URL for $verseKey does not end with /$fileName: "$url"',
  );
  final dir = url.substring(0, url.length - fileName.length);
  final String base;
  final String folder;
  final String sourceId;
  if (dir.startsWith(everyAyahMirrorPrefix)) {
    base = everyAyahBase;
    folder = dir.substring(everyAyahMirrorPrefix.length);
    sourceId = sourceEveryAyah;
  } else {
    check(
      !dir.startsWith('/') && !dir.contains(':'),
      () => 'audio URL for $verseKey has an unexpected host or scheme: "$url"',
    );
    base = quranComAudioBase;
    folder = dir;
    sourceId = sourceQuranComAudio;
  }
  check(
    _folderPattern.hasMatch(folder) && !folder.contains('..'),
    () => 'audio URL for $verseKey has an unexpected folder "$folder"',
  );
  return ResolvedTemplate(
    '$base$folder$surahPlaceholder$ayahPlaceholder.mp3',
    sourceId,
  );
}

/// Fills [template] for [surah]:[ayah].
String expandTemplate(String template, int surah, int ayah) => template
    .replaceAll(surahPlaceholder, pad3(surah))
    .replaceAll(ayahPlaceholder, pad3(ayah));
