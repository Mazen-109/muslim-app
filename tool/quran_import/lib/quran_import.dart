/// Builds the Muslim app's Quran content database from the Quran.com API.
library;

// The search folding rule lives in a package shared with the app.
export 'package:search_folding/search_folding.dart' show foldArabic;

export 'src/api_client.dart';
export 'src/dataset.dart';
export 'src/db_writer.dart';
export 'src/errors.dart';
export 'src/hashing.dart';
export 'src/layout.dart';
export 'src/manifest.dart';
export 'src/parsers.dart';
export 'src/reciters.dart';
export 'src/validate.dart';
