import 'package:muslim/data/quran_database.dart';
import 'package:muslim/data/quran_repository.dart';

/// Opens the bundled content database (`assets/data/quran.db`) read-only,
/// straight from the repository checkout. The caller closes it.
QuranDatabase openBundledQuranDatabase() =>
    QuranDatabase.openFile(QuranDatabase.assetKey);

/// A repository over a fresh connection to the bundled database, and a
/// function that releases both.
(QuranRepository, void Function()) openBundledQuranRepository() {
  final database = openBundledQuranDatabase();
  final repository = QuranRepository(database);
  return (
    repository,
    () {
      repository.dispose();
      database.close();
    },
  );
}
