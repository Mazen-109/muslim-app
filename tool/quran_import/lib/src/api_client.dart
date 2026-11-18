/// HTTP access with retry, an on-disk response cache and a request log.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:path/path.dart' as p;

import 'errors.dart';

/// One HTTP request as recorded in the manifest.
class RequestRecord {
  RequestRecord(this.url, this.sha256, this.bytes);

  final String url;
  final String sha256;
  final int bytes;

  Map<String, Object> toJson() => {
    'url': url,
    'sha256': sha256,
    'bytes': bytes,
  };
}

/// Fetches URLs politely: bounded concurrency, exponential backoff on 429,
/// 5xx and network errors, and a cache of raw response bodies keyed by URL.
///
/// Every request made through [getJson], [getJsonAll] and [probe] is
/// appended to [requests] in a deterministic order (the order the caller
/// asked for them), whether it was served from the network or the cache.
class ApiClient {
  ApiClient({
    required this.cacheDir,
    http.Client? client,
    this.maxAttempts = 7,
    this.baseDelay = const Duration(seconds: 1),
    this.timeout = const Duration(seconds: 90),
    this.log = _noLog,
  }) : _client = client ?? _defaultClient();

  final Directory cacheDir;
  final int maxAttempts;
  final Duration baseDelay;
  final Duration timeout;
  final void Function(String) log;
  final http.Client _client;

  final List<RequestRecord> requests = [];
  int networkRequests = 0;
  int cacheHits = 0;

  static void _noLog(String _) {}

  static http.Client _defaultClient() {
    final c = HttpClient()
      ..findProxy = HttpClient.findProxyFromEnvironment
      ..connectionTimeout = const Duration(seconds: 30)
      ..userAgent = 'quran_import/1.0.0';
    return IOClient(c);
  }

  void close() => _client.close();

  File _cacheFile(String url) =>
      File(p.join(cacheDir.path, '${sha256.convert(utf8.encode(url))}.body'));

  /// GETs [url] (from the cache when present) and returns the body bytes,
  /// without recording it.
  Future<Uint8List> _fetchCached(String url) async {
    final file = _cacheFile(url);
    if (file.existsSync()) {
      cacheHits++;
      return file.readAsBytes();
    }
    final res = await _send(url, 'GET', const {}, {200});
    final body = res.bodyBytes;
    check(body.isNotEmpty, () => 'GET $url returned an empty body');
    cacheDir.createSync(recursive: true);
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsBytes(body, flush: true);
    await tmp.rename(file.path);
    return body;
  }

  Future<http.Response> _send(
    String url,
    String method,
    Map<String, String> headers,
    Set<int> okStatuses,
  ) async {
    check(url.startsWith('https://'), () => 'refusing non-HTTPS URL $url');
    for (var attempt = 1; ; attempt++) {
      String failure;
      try {
        networkRequests++;
        final req = http.Request(method, Uri.parse(url))
          ..headers.addAll(headers)
          ..followRedirects = true;
        final streamed = await _client.send(req).timeout(timeout);
        final res = await http.Response.fromStream(streamed).timeout(timeout);
        if (okStatuses.contains(res.statusCode)) return res;
        final retryable = res.statusCode == 429 || res.statusCode >= 500;
        failure = 'HTTP ${res.statusCode}';
        if (!retryable) {
          throw ImportException('$method $url failed: $failure');
        }
      } on ImportException {
        rethrow;
      } on Object catch (e) {
        if (e is! IOException &&
            e is! http.ClientException &&
            e is! TimeoutException &&
            e is! HandshakeException) {
          rethrow;
        }
        failure = '${e.runtimeType}: $e';
      }
      if (attempt >= maxAttempts) {
        throw ImportException(
          '$method $url failed after $attempt attempts: $failure',
        );
      }
      final delay = baseDelay * (1 << (attempt - 1));
      log(
        'retry $attempt/$maxAttempts in ${delay.inSeconds}s: $method $url '
        '($failure)',
      );
      await Future<void>.delayed(delay);
    }
  }

  RequestRecord _record(String url, Uint8List body) {
    final r = RequestRecord(url, sha256.convert(body).toString(), body.length);
    requests.add(r);
    return r;
  }

  Object? _decode(String url, Uint8List body) {
    try {
      return jsonDecode(utf8.decode(body));
    } on FormatException catch (e) {
      throw ImportException('GET $url: invalid UTF-8 JSON: ${e.message}');
    }
  }

  /// GETs [url] and decodes its JSON body.
  Future<Object?> getJson(String url) async {
    final body = await _fetchCached(url);
    _record(url, body);
    return _decode(url, body);
  }

  /// GETs every URL with at most [concurrency] requests in flight, and
  /// returns the decoded bodies in the order of [urls]. Records them in that
  /// order once all have completed.
  Future<List<Object?>> getJsonAll(
    List<String> urls, {
    int concurrency = 4,
  }) async {
    final bodies = List<Uint8List?>.filled(urls.length, null);
    var next = 0;
    var done = 0;
    Future<void> worker() async {
      while (next < urls.length) {
        final i = next++;
        bodies[i] = await _fetchCached(urls[i]);
        done++;
        if (done % 100 == 0) log('  $done/${urls.length}');
      }
    }

    await Future.wait([
      for (var w = 0; w < concurrency && w < urls.length; w++) worker(),
    ]);
    return [
      for (final (i, url) in urls.indexed)
        () {
          _record(url, bodies[i]!);
          return _decode(url, bodies[i]!);
        }(),
    ];
  }

  /// Checks that [url] is served, with a ranged GET of its first byte (never
  /// cached). Accepts 200 or 206 and a non-empty body; records the request.
  Future<RequestRecord> probe(String url) async {
    final res = await _send(
      url,
      'GET',
      const {'Range': 'bytes=0-0'},
      {200, 206},
    );
    check(res.bodyBytes.isNotEmpty, () => 'GET $url returned an empty body');
    log('  probe ${res.statusCode} ${res.bodyBytes.length} byte(s): $url');
    return _record(url, res.bodyBytes);
  }
}
