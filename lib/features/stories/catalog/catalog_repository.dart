import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'catalog_models.dart';
import 'catalog_parser.dart';

/// Asset path of the bundled catalog.
const String bundledCatalogAsset = 'assets/content/catalog.json';

/// The build-time define naming the remote catalog; empty means bundled
/// only.
const String catalogUrlDefine = String.fromEnvironment('CATALOG_URL');

/// The remote catalog URL for [define], or null when it is empty or not an
/// HTTPS URL.
Uri? catalogUrlFrom(String define) {
  if (define.isEmpty) return null;
  final uri = Uri.tryParse(define);
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return null;
  return uri;
}

/// Loads the story catalog and keeps the newest valid one.
///
/// The bundled catalog is the floor. A cached copy of an earlier remote
/// catalog replaces it when it parses and is newer by `updated_at`.
/// [refresh] fetches [remoteUrl], and adopts and caches the result only when
/// it parses and is newer still. Every failure of the cache or the network
/// keeps the current catalog without an error.
class CatalogRepository {
  CatalogRepository({
    required this._loadBundled,
    required this._cacheDirectory,
    this.remoteUrl,
    this._client,
    this.timeout = const Duration(seconds: 10),
  });

  /// File name of the cached remote catalog in the cache directory.
  static const String cacheFileName = 'story_catalog.json';

  final Future<String> Function() _loadBundled;
  final Future<Directory> Function() _cacheDirectory;
  final http.Client? _client;

  /// The remote catalog, or null for bundled only.
  final Uri? remoteUrl;

  /// How long [refresh] waits for the remote catalog.
  final Duration timeout;

  Catalog? _current;

  /// The catalog in use; null before [load] completes.
  Catalog? get current => _current;

  /// Whether [refresh] can reach a remote catalog.
  bool get canRefresh => remoteUrl != null && _client != null;

  /// Loads the bundled catalog and the cache, and returns the newer.
  ///
  /// Throws a [CatalogFormatException] only when the bundled catalog is
  /// invalid and there is no valid cache.
  Future<Catalog> load() async {
    Catalog? best;
    CatalogFormatException? bundledError;
    try {
      best = CatalogParser.parse(await _loadBundled());
    } on CatalogFormatException catch (e) {
      bundledError = e;
    }
    final cached = await _readCache();
    if (cached != null && (best == null || _isNewer(cached, best))) {
      best = cached;
    }
    if (best == null) throw bundledError!;
    return _current = best;
  }

  /// Fetches the remote catalog and returns the catalog now in use.
  Future<Catalog> refresh() async {
    final current = _current ?? await load();
    final url = remoteUrl;
    final client = _client;
    if (url == null || client == null) return current;
    try {
      final response = await client.get(url).timeout(timeout);
      if (response.statusCode != 200) return current;
      final text = utf8.decode(response.bodyBytes);
      final remote = CatalogParser.parse(text);
      if (!_isNewer(remote, current)) return current;
      _current = remote;
      await _writeCache(text);
      return remote;
    } on Exception {
      return _current ?? current;
    }
  }

  static bool _isNewer(Catalog a, Catalog b) =>
      a.updatedAt.isAfter(b.updatedAt);

  Future<Catalog?> _readCache() async {
    try {
      final file = await _cacheFile();
      if (!file.existsSync()) return null;
      return CatalogParser.parse(await file.readAsString());
    } on Exception {
      // A cache that is unreadable or no longer valid is ignored; the next
      // successful refresh overwrites it.
      return null;
    }
  }

  Future<void> _writeCache(String text) async {
    try {
      final file = await _cacheFile();
      final temp = File('${file.path}.tmp');
      await temp.writeAsString(text, flush: true);
      await temp.rename(file.path);
    } on Exception {
      // The catalog stays in use for this session; the next launch fetches
      // it again.
    }
  }

  Future<File> _cacheFile() async =>
      File(p.join((await _cacheDirectory()).path, cacheFileName));
}

/// The remote catalog URL from `CATALOG_URL`. Tests override it.
final catalogUrlProvider = Provider<Uri?>(
  (ref) => catalogUrlFrom(catalogUrlDefine),
);

/// The HTTP client for catalog refreshes. Tests override it with a fake.
final catalogHttpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

/// The directory holding the cached remote catalog. Tests override it with
/// a temporary directory.
final catalogCacheDirectoryProvider = Provider<Future<Directory> Function()>(
  (ref) => getApplicationSupportDirectory,
);

/// Reads the bundled catalog text. Tests may override it.
final bundledCatalogLoaderProvider = Provider<Future<String> Function()>(
  (ref) =>
      () => rootBundle.loadString(bundledCatalogAsset, cache: false),
);

/// The catalog repository.
final catalogRepositoryProvider = Provider<CatalogRepository>((ref) {
  final url = ref.watch(catalogUrlProvider);
  return CatalogRepository(
    loadBundled: ref.watch(bundledCatalogLoaderProvider),
    cacheDirectory: ref.watch(catalogCacheDirectoryProvider),
    remoteUrl: url,
    client: url == null ? null : ref.watch(catalogHttpClientProvider),
  );
});

/// The catalog in use. It starts from the bundled or cached catalog, then
/// refreshes once in the background and updates when a newer valid catalog
/// arrives.
class CatalogNotifier extends AsyncNotifier<Catalog> {
  @override
  Future<Catalog> build() async {
    final repository = ref.watch(catalogRepositoryProvider);
    final catalog = await repository.load();
    if (repository.canRefresh) unawaited(_refresh(repository));
    return catalog;
  }

  Future<void> _refresh(CatalogRepository repository) async {
    await future;
    final catalog = await repository.refresh();
    if (!ref.mounted) return;
    if (catalog != state.value) state = AsyncData<Catalog>(catalog);
  }
}

final catalogProvider = AsyncNotifierProvider<CatalogNotifier, Catalog>(
  CatalogNotifier.new,
);
