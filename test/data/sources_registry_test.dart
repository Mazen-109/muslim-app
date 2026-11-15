import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muslim/data/sources_registry.dart';

const String _fontFamily = 'UthmanicHafs';
const String _fontAsset = 'assets/fonts/UthmanicHafs1Ver18.ttf';

/// A minimal valid entry; tests copy and alter it.
Map<String, Object?> _entry() => <String, Object?>{
  'id': 'example-source',
  'kind': 'audio',
  'name_ar': 'مصدر',
  'name_en': 'Example source',
  'provider': 'Example provider',
  'url': 'https://example.com',
  'license': 'Terms of use to be confirmed.',
  'verified': false,
};

String _registryJson(List<Map<String, Object?>> entries) =>
    jsonEncode(<String, Object?>{'schema_version': 1, 'sources': entries});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SourcesRegistry registry;

  setUpAll(() {
    registry = SourcesRegistry.parse(
      File(sourcesRegistryAsset).readAsStringSync(),
    );
  });

  group('bundled registry', () {
    test('loads from the asset bundle and through the provider', () async {
      final fromBundle = await SourcesRegistry.load(rootBundle);
      expect(fromBundle.sources.length, registry.sources.length);

      final container = ProviderContainer();
      addTearDown(container.dispose);
      final fromProvider = await container.read(sourcesRegistryProvider.future);
      expect(
        fromProvider.sources.map((s) => s.id),
        registry.sources.map((s) => s.id),
      );
    });

    test('has schema version 1 and the expected entries', () {
      expect(registry.schemaVersion, 1);
      expect(
        registry.sources.map((s) => s.id).toSet(),
        containsAll(<String>[
          'quran-com-api',
          'tafsir-muyassar',
          'quran-com-audio',
          'everyayah',
          'kfgqpc-uthmanic-hafs',
        ]),
      );
    });

    test('ids are unique', () {
      final ids = registry.sources.map((s) => s.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('every required field is non-empty', () {
      for (final s in registry.sources) {
        for (final value in <String>[
          s.id,
          s.nameAr,
          s.nameEn,
          s.provider,
          s.url,
          s.license,
        ]) {
          expect(value.trim(), isNotEmpty, reason: s.id);
        }
      }
    });

    test('kinds are within the enum', () {
      final raw = jsonDecode(
        File(sourcesRegistryAsset).readAsStringSync(),
      ) as Map<String, Object?>;
      final allowed = SourceKind.values.map((k) => k.jsonValue).toSet();
      expect(allowed, <String>{
        'quran_text',
        'tafsir',
        'audio',
        'font',
        'video',
        'icon',
      });
      for (final entry in (raw['sources']! as List<Object?>)) {
        final kind = (entry! as Map<String, Object?>)['kind'];
        expect(allowed, contains(kind));
      }
    });

    test('every url and terms_url is https', () {
      for (final s in registry.sources) {
        expect(s.url, startsWith('https://'), reason: s.id);
        final terms = s.termsUrl;
        if (terms != null) expect(terms, startsWith('https://'), reason: s.id);
      }
    });

    test('every asset_path exists and matches its sha256', () {
      final withAsset = registry.sources.where((s) => s.assetPath != null);
      expect(withAsset, isNotEmpty);
      for (final s in withAsset) {
        final file = File(s.assetPath!);
        expect(file.existsSync(), isTrue, reason: s.assetPath);
        expect(s.sha256, isNotNull, reason: s.id);
        expect(
          sha256.convert(file.readAsBytesSync()).toString(),
          s.sha256,
          reason: s.id,
        );
      }
    });

    test('the Quran font is registered and declared as UthmanicHafs', () {
      final font = registry.byId('kfgqpc-uthmanic-hafs');
      expect(font, isNotNull);
      expect(font!.kind, SourceKind.font);
      expect(font.assetPath, _fontAsset);

      final pubspec = File('pubspec.yaml').readAsStringSync();
      final declaration = RegExp(
        r'^\s*-\s*family:\s*' +
            _fontFamily +
            r'\s*\n\s*fonts:\s*\n\s*-\s*asset:\s*' +
            RegExp.escape(_fontAsset) +
            r'\s*$',
        multiLine: true,
      );
      expect(declaration.hasMatch(pubspec), isTrue);
    });

    test('every verified entry names who verified it and when', () {
      for (final s in registry.sources.where((s) => s.verified)) {
        expect(s.verifiedBy?.trim(), isNotEmpty, reason: s.id);
        expect(s.verifiedAt?.trim(), isNotEmpty, reason: s.id);
      }
    });
  });

  group('parser', () {
    test('accepts a minimal valid registry', () {
      final parsed = SourcesRegistry.parse(_registryJson([_entry()]));
      expect(parsed.sources.single.kind, SourceKind.audio);
      expect(parsed.sources.single.runtimeHosts, isEmpty);
    });

    void expectRejected(String json) =>
        expect(() => SourcesRegistry.parse(json), throwsFormatException);

    test('rejects an unknown kind', () {
      expectRejected(_registryJson([_entry()..['kind'] = 'podcast']));
    });

    for (final field in <String>[
      'id',
      'kind',
      'name_ar',
      'name_en',
      'provider',
      'url',
      'license',
      'verified',
    ]) {
      test('rejects a missing $field', () {
        expectRejected(_registryJson([_entry()..remove(field)]));
      });
    }

    test('rejects an empty required string', () {
      expectRejected(_registryJson([_entry()..['provider'] = ' ']));
    });

    test('rejects a non-https url and terms_url', () {
      expectRejected(_registryJson([_entry()..['url'] = 'http://example.com']));
      expectRejected(
        _registryJson([_entry()..['terms_url'] = 'ftp://example.com']),
      );
    });

    test('rejects a malformed sha256', () {
      expectRejected(_registryJson([_entry()..['sha256'] = 'abc123']));
      expectRejected(_registryJson([_entry()..['sha256'] = 'A' * 64]));
    });

    test('rejects a malformed id, duplicate ids and unknown fields', () {
      expectRejected(_registryJson([_entry()..['id'] = 'Bad_Id']));
      expectRejected(_registryJson([_entry(), _entry()]));
      expectRejected(_registryJson([_entry()..['licence'] = 'x']));
    });

    test('rejects a malformed verified_at', () {
      expectRejected(_registryJson([_entry()..['verified_at'] = '15/11/2026']));
    });

    test('rejects a wrong schema version, an empty list and bad JSON', () {
      expectRejected(
        jsonEncode({
          'schema_version': 2,
          'sources': [_entry()],
        }),
      );
      expectRejected(_registryJson([]));
      expectRejected('{');
    });
  });
}
