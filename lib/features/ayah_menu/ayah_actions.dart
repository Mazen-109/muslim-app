import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../data/models/ayah.dart';
import '../../data/models/surah.dart';
import '../stories/catalog/catalog_models.dart';
import '../stories/catalog/catalog_repository.dart';

/// The actions of the ayah menu, in the order of FR-017, with Mark as
/// memorised (FR-018) next to Bookmark. The menu lists them in this order.
enum AyahAction {
  listen,
  repeat,
  tafsir,
  surahStory,
  bookmark,
  memorise,
  share,
  report,
}

/// The text shared for [ayah] of [surah] (FR-019): the ayah's `text_uthmani`
/// exactly as stored, a blank line, then a reference line with the surah
/// name in the interface language and the ayah number.
String formatAyahShareText({
  required Ayah ayah,
  required Surah surah,
  required AppLocalizations l10n,
}) {
  final surahName = l10n.localeName == 'ar' ? surah.nameAr : surah.nameEn;
  return '${ayah.textUthmani}\n\n'
      '${l10n.ayahShareReference(surahName, ayah.ayahNumber)}';
}

/// Hands text to the system share sheet. Tests override [sharePortProvider]
/// with a fake that records what was shared.
abstract interface class SharePort {
  /// Shares [text]. [origin] is the area, in global coordinates, that the
  /// share sheet points at where it is a popover (iPad).
  Future<void> shareText(String text, {Rect? origin});
}

/// The system share sheet through `share_plus`.
class SystemSharePort implements SharePort {
  const SystemSharePort();

  @override
  Future<void> shareText(String text, {Rect? origin}) async {
    await SharePlus.instance.share(
      ShareParams(text: text, sharePositionOrigin: origin),
    );
  }
}

/// The share sheet the ayah menu uses.
final sharePortProvider = Provider<SharePort>((ref) => const SystemSharePort());

/// The playable story of [surah], or null while the catalog loads, when it
/// failed to load, or when the surah has none (data-model.md section 5, as
/// decided by [Catalog.playableStoryForSurah]).
final playableSurahStoryProvider = Provider.family<SurahStory?, int>(
  (ref, surah) =>
      ref.watch(catalogProvider).value?.playableStoryForSurah(surah),
);

/// Reports an error in ayah [ayahId] from the ayah menu.
typedef AyahErrorReporter = Future<void> Function(
  BuildContext context,
  int ayahId,
);

/// The ayah menu's error report (T025). While it is null the Report an
/// error action is hidden.
final ayahErrorReporterProvider = Provider<AyahErrorReporter?>((ref) => null);
