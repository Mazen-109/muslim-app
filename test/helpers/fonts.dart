import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:muslim/core/theme/app_typography.dart';

bool _loaded = false;

/// Loads the real fonts so goldens show glyphs instead of the test font's
/// boxes: the interface and Quran fonts from `assets/fonts/`, and the
/// Material icon font from the bundle's font manifest. Safe to call more
/// than once; call it from `setUpAll`.
Future<void> loadAppFonts() async {
  if (_loaded) return;
  await _load(AppFonts.ui, <String>[AppFonts.uiAsset]);
  await _load(AppFonts.quran, <String>[AppFonts.quranAsset]);
  await _load('MaterialIcons', await _manifestAssets('MaterialIcons'));
  _loaded = true;
}

Future<void> _load(String family, List<String> assets) async {
  if (assets.isEmpty) {
    throw StateError('No font files for the $family family.');
  }
  final loader = FontLoader(family);
  for (final asset in assets) {
    loader.addFont(rootBundle.load(asset));
  }
  await loader.load();
}

/// The asset paths of [family] in `FontManifest.json`.
Future<List<String>> _manifestAssets(String family) async {
  final manifest = json.decode(
    await rootBundle.loadString('FontManifest.json'),
  ) as List<dynamic>;
  return <String>[
    for (final entry in manifest.cast<Map<String, dynamic>>())
      if (entry['family'] == family)
        for (final font in (entry['fonts'] as List<dynamic>))
          (font as Map<String, dynamic>)['asset'] as String,
  ];
}
