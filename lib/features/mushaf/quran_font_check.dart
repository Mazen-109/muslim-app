import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_typography.dart';
import '../../data/quran_database.dart' show AssetLoader;
import '../../data/sources_registry.dart';

/// Thrown when the Quran font cannot be trusted: the asset is missing, the
/// sources registry has no checksum for it, or its SHA-256 differs from the
/// registry. The reader shows a blocking error instead of the page, because
/// Quran text is never drawn in a substitute font (constitution, I).
class QuranFontException implements Exception {
  const QuranFontException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => cause == null
      ? 'QuranFontException: $message'
      : 'QuranFontException: $message ($cause)';
}

/// Checks the bundled Quran font against the sources registry.
///
/// Loads [AppFonts.quranAsset] with [load] and compares its SHA-256 with the
/// `sha256` of the registry entry whose `asset_path` names it. Throws
/// [QuranFontException] on any mismatch or failure.
Future<void> verifyQuranFont({
  required AssetLoader load,
  required SourcesRegistry registry,
}) async {
  String? expected;
  for (final source in registry.sources) {
    if (source.assetPath == AppFonts.quranAsset) expected = source.sha256;
  }
  if (expected == null) {
    throw const QuranFontException(
      'The sources registry has no checksum for ${AppFonts.quranAsset}',
    );
  }

  final ByteData data;
  try {
    data = await load(AppFonts.quranAsset);
  } on Object catch (e) {
    throw QuranFontException('Cannot load ${AppFonts.quranAsset}', e);
  }
  final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  if (bytes.isEmpty) {
    throw const QuranFontException('${AppFonts.quranAsset} is empty');
  }
  final actual = sha256.convert(bytes).toString();
  if (actual != expected) {
    throw QuranFontException(
      '${AppFonts.quranAsset} has SHA-256 $actual, the registry expects '
      '$expected',
    );
  }
}

/// How the font check reads the font asset. Tests override it to simulate a
/// missing or altered font.
final quranFontAssetLoaderProvider = Provider<AssetLoader>(
  (ref) => rootBundle.load,
);

/// The startup font check. Completes when the Quran font matches the
/// registry; fails with [QuranFontException] otherwise. Not retried: a
/// bundled asset does not change while the app runs.
final quranFontCheckProvider = FutureProvider<void>(
  retry: (retryCount, error) => null,
  (ref) async {
    final SourcesRegistry registry;
    try {
      registry = await ref.watch(sourcesRegistryProvider.future);
    } on Object catch (e) {
      throw QuranFontException('Cannot read the sources registry', e);
    }
    await verifyQuranFont(
      load: ref.watch(quranFontAssetLoaderProvider),
      registry: registry,
    );
  },
);
