import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Asset path of the bundled sources registry.
const String sourcesRegistryAsset = 'assets/sources.json';

/// The kind of third-party asset a registry entry describes.
enum SourceKind {
  quranText('quran_text'),
  tafsir('tafsir'),
  audio('audio'),
  font('font'),
  video('video'),
  icon('icon');

  const SourceKind(this.jsonValue);

  /// The value used in `sources.json`.
  final String jsonValue;

  /// Returns the kind for [value], or throws [FormatException].
  static SourceKind parse(String value) {
    for (final kind in values) {
      if (kind.jsonValue == value) return kind;
    }
    throw FormatException('Unknown source kind "$value"');
  }
}

/// One entry of the sources registry (`contracts/sources.schema.json`).
@immutable
class SourceEntry {
  SourceEntry({
    required this.id,
    required this.kind,
    required this.nameAr,
    required this.nameEn,
    required this.provider,
    required this.url,
    required this.license,
    required this.verified,
    this.termsUrl,
    this.attributionAr,
    this.attributionEn,
    this.sha256,
    this.assetPath,
    List<String> runtimeHosts = const <String>[],
    this.verifiedBy,
    this.verifiedAt,
    this.notes,
  }) : runtimeHosts = List<String>.unmodifiable(runtimeHosts);

  final String id;
  final SourceKind kind;
  final String nameAr;
  final String nameEn;
  final String provider;
  final String url;
  final String license;
  final bool verified;
  final String? termsUrl;
  final String? attributionAr;
  final String? attributionEn;
  final String? sha256;
  final String? assetPath;
  final List<String> runtimeHosts;
  final String? verifiedBy;
  final String? verifiedAt;
  final String? notes;
}

/// The parsed sources registry.
@immutable
class SourcesRegistry {
  SourcesRegistry({
    required this.schemaVersion,
    required List<SourceEntry> sources,
  }) : sources = List<SourceEntry>.unmodifiable(sources);

  /// The only schema version this parser accepts.
  static const int supportedSchemaVersion = 1;

  final int schemaVersion;
  final List<SourceEntry> sources;

  /// The entry with [id], or null.
  SourceEntry? byId(String id) {
    for (final source in sources) {
      if (source.id == id) return source;
    }
    return null;
  }

  /// Loads and parses the registry from [bundle].
  static Future<SourcesRegistry> load(AssetBundle bundle) async {
    final text = await bundle.loadString(sourcesRegistryAsset, cache: false);
    return parse(text);
  }

  /// Parses registry JSON strictly; throws [FormatException] on any violation
  /// of the schema.
  static SourcesRegistry parse(String jsonText) {
    final Object? decoded;
    try {
      decoded = jsonDecode(jsonText);
    } on FormatException catch (e) {
      throw FormatException('Sources registry is not valid JSON: ${e.message}');
    }
    final root = _asMap(decoded, 'registry');
    _rejectUnknownKeys(root, const {'schema_version', 'sources'}, 'registry');

    final version = root['schema_version'];
    if (version != supportedSchemaVersion) {
      throw FormatException('Unsupported schema_version "$version"');
    }

    final rawSources = root['sources'];
    if (rawSources is! List<Object?>) {
      throw const FormatException('"sources" must be an array');
    }
    if (rawSources.isEmpty) {
      throw const FormatException('"sources" must not be empty');
    }

    final sources = <SourceEntry>[];
    final ids = <String>{};
    for (var i = 0; i < rawSources.length; i++) {
      final entry = _parseEntry(rawSources[i], 'sources[$i]');
      if (!ids.add(entry.id)) {
        throw FormatException('Duplicate source id "${entry.id}"');
      }
      sources.add(entry);
    }
    return SourcesRegistry(schemaVersion: version as int, sources: sources);
  }

  static const Set<String> _entryKeys = {
    'id',
    'kind',
    'name_ar',
    'name_en',
    'provider',
    'url',
    'license',
    'terms_url',
    'attribution_ar',
    'attribution_en',
    'sha256',
    'asset_path',
    'runtime_hosts',
    'verified',
    'verified_by',
    'verified_at',
    'notes',
  };

  static final RegExp _idPattern = RegExp(r'^[a-z0-9-]+$');
  static final RegExp _sha256Pattern = RegExp(r'^[a-f0-9]{64}$');
  static final RegExp _datePattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  static SourceEntry _parseEntry(Object? raw, String where) {
    final map = _asMap(raw, where);
    _rejectUnknownKeys(map, _entryKeys, where);

    final id = _requiredString(map, 'id', where);
    if (!_idPattern.hasMatch(id)) {
      throw FormatException(
        '$where: id "$id" must match ${_idPattern.pattern}',
      );
    }
    final at = '$where ($id)';

    final verified = map['verified'];
    if (verified is! bool) {
      throw FormatException(
        '$at: "verified" is required and must be a boolean',
      );
    }

    final sha256 = _optionalString(map, 'sha256', at);
    if (sha256 != null && !_sha256Pattern.hasMatch(sha256)) {
      throw FormatException('$at: "sha256" must be 64 lowercase hex digits');
    }

    final verifiedAt = _optionalString(map, 'verified_at', at);
    if (verifiedAt != null &&
        (!_datePattern.hasMatch(verifiedAt) ||
            DateTime.tryParse(verifiedAt) == null)) {
      throw FormatException('$at: "verified_at" must be a date (YYYY-MM-DD)');
    }

    final rawHosts = map['runtime_hosts'];
    final hosts = <String>[];
    if (rawHosts != null) {
      if (rawHosts is! List<Object?>) {
        throw FormatException('$at: "runtime_hosts" must be an array');
      }
      for (final host in rawHosts) {
        if (host is! String) {
          throw FormatException('$at: "runtime_hosts" must hold strings');
        }
        hosts.add(host);
      }
    }

    return SourceEntry(
      id: id,
      kind: SourceKind.parse(_requiredString(map, 'kind', at)),
      nameAr: _requiredString(map, 'name_ar', at),
      nameEn: _requiredString(map, 'name_en', at),
      provider: _requiredString(map, 'provider', at),
      url: _httpsUrl(_requiredString(map, 'url', at), 'url', at),
      license: _requiredString(map, 'license', at),
      verified: verified,
      termsUrl: _optionalHttpsUrl(map, 'terms_url', at),
      attributionAr: _optionalString(map, 'attribution_ar', at),
      attributionEn: _optionalString(map, 'attribution_en', at),
      sha256: sha256,
      assetPath: _optionalString(map, 'asset_path', at),
      runtimeHosts: hosts,
      verifiedBy: _optionalString(map, 'verified_by', at),
      verifiedAt: verifiedAt,
      notes: _optionalString(map, 'notes', at),
    );
  }

  static Map<String, Object?> _asMap(Object? raw, String where) {
    if (raw is! Map<String, Object?>) {
      throw FormatException('$where must be a JSON object');
    }
    return raw;
  }

  static void _rejectUnknownKeys(
    Map<String, Object?> map,
    Set<String> allowed,
    String where,
  ) {
    for (final key in map.keys) {
      if (!allowed.contains(key)) {
        throw FormatException('$where: unknown field "$key"');
      }
    }
  }

  static String _requiredString(
    Map<String, Object?> map,
    String key,
    String where,
  ) {
    final value = map[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('$where: "$key" is required and must be non-empty');
    }
    return value;
  }

  static String? _optionalString(
    Map<String, Object?> map,
    String key,
    String where,
  ) {
    if (!map.containsKey(key)) return null;
    final value = map[key];
    if (value is! String) {
      throw FormatException('$where: "$key" must be a string');
    }
    return value;
  }

  static String? _optionalHttpsUrl(
    Map<String, Object?> map,
    String key,
    String where,
  ) {
    final value = _optionalString(map, key, where);
    return value == null ? null : _httpsUrl(value, key, where);
  }

  static String _httpsUrl(String value, String key, String where) {
    final uri = Uri.tryParse(value);
    if (!value.startsWith('https://') || uri == null || uri.host.isEmpty) {
      throw FormatException('$where: "$key" must be an https URL');
    }
    return value;
  }
}

/// The bundled sources registry.
final sourcesRegistryProvider = FutureProvider<SourcesRegistry>(
  (ref) => SourcesRegistry.load(rootBundle),
);
