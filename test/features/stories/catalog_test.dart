import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:muslim/features/stories/catalog/catalog_models.dart';
import 'package:muslim/features/stories/catalog/catalog_parser.dart';
import 'package:muslim/features/stories/catalog/catalog_repository.dart';

// Fixtures hold structure only: neutral names, no titles, no story text.

const String _stream = 'https://media.example.com/item.m3u8';

Map<String, Object?> _review(String status) => <String, Object?>{
  'status': status,
  if (status == 'approved') ...<String, Object?>{
    'reviewer': 'Reviewer A',
    'approved_at': '2026-01-02',
  },
};

Map<String, Object?> _surah(
  int surah, {
  String status = 'approved',
  bool attested = true,
  bool media = true,
}) => <String, Object?>{
  'id': 'surah-${surah.toString().padLeft(3, '0')}',
  'surah': surah,
  'review': _review(status),
  'no_prophet_depiction': attested,
  if (media) 'media': <String, Object?>{'type': 'stream', 'url': _stream},
};

Map<String, Object?> _episode(
  String prophet,
  int order,
  List<List<String>> ranges, {
  String status = 'approved',
  bool attested = true,
  bool media = true,
}) => <String, Object?>{
  'id': '$prophet-ep${order.toString().padLeft(2, '0')}',
  'order': order,
  'review': _review(status),
  'no_prophet_depiction': attested,
  if (media)
    'media': <String, Object?>{'type': 'youtube', 'video_id': 'abcdefghijk'},
  'related_ayahs': <Object?>[
    for (final r in ranges) <String, Object?>{'from': r[0], 'to': r[1]},
  ],
};

Map<String, Object?> _prophet(
  String id,
  int order, [
  List<Map<String, Object?>> episodes = const <Map<String, Object?>>[],
]) => <String, Object?>{
  'id': id,
  'order': order,
  'name_ar': 'Item $order',
  'name_en': 'Item $order',
  'episodes': episodes,
};

Map<String, Object?> _catalog({
  String updatedAt = '2026-06-01T00:00:00Z',
  List<Map<String, Object?>>? surahs,
  List<Map<String, Object?>>? prophets,
}) => <String, Object?>{
  'schema_version': 1,
  'updated_at': updatedAt,
  'surah_stories': surahs ?? <Map<String, Object?>>[_surah(112)],
  'prophet_series': prophets ?? <Map<String, Object?>>[],
};

Catalog _parse(Map<String, Object?> json) =>
    CatalogParser.parse(jsonEncode(json));

/// Waits, with real time, until [condition] holds or two seconds pass.
Future<void> _until(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 2));
  while (!condition() && DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

/// Asserts that [json] is rejected with a [T].
void _rejects<T extends CatalogFormatException>(Object? json) {
  expect(
    () => CatalogParser.parse(json is String ? json : jsonEncode(json)),
    throwsA(isA<T>()),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('bundled catalog', () {
    late Catalog catalog;

    setUpAll(() {
      catalog = CatalogParser.parse(
        File(bundledCatalogAsset).readAsStringSync(),
      );
    });

    test('is registered as an asset and parses', () async {
      final text = await rootBundle.loadString(bundledCatalogAsset);
      expect(CatalogParser.parse(text), catalog);
    });

    test('lists every surah of Juz Amma once, all planned', () {
      expect(catalog.surahStories, hasLength(37));
      expect(catalog.juzAmmaStories.map((s) => s.surah), <int>[
        for (var s = juzAmmaFirstSurah; s <= juzAmmaLastSurah; s++) s,
      ]);
      for (final story in catalog.surahStories) {
        expect(story.review, const Review(status: ReviewStatus.planned));
        expect(story.noProphetDepiction, isFalse);
        expect(story.media, isNull);
        expect(story.isPlayable, isFalse);
      }
    });

    test('lists the five default prophet stories with no episodes', () {
      expect(catalog.prophetSeriesInOrder.map((s) => s.id), <String>[
        'prophet-adam',
        'prophet-nuh',
        'prophet-ibrahim',
        'prophet-yusuf',
        'prophet-musa',
      ]);
      expect(catalog.prophetSeriesInOrder.map((s) => s.order), <int>[
        1,
        2,
        3,
        4,
        5,
      ]);
      for (final story in catalog.prophetSeries) {
        expect(story.episodes, isEmpty);
        expect(story.nameAr, isNotEmpty);
        expect(story.nameEn, isNotEmpty);
      }
    });

    test('has nothing playable', () {
      for (var surah = 1; surah <= 114; surah++) {
        expect(catalog.playableStoryForSurah(surah), isNull);
      }
      expect(catalog.playableEpisodesFor(const AyahKey(12, 4)), isEmpty);
    });
  });

  group('isPlayable', () {
    final cases = <(ReviewStatus, bool, bool)>[
      for (final status in ReviewStatus.values)
        for (final attested in <bool>[false, true])
          for (final media in <bool>[false, true]) (status, attested, media),
    ];

    for (final (status, attested, media) in cases) {
      final expected = status == ReviewStatus.approved && attested && media;
      test('${status.jsonValue}, attested $attested, media $media '
          'is ${expected ? '' : 'not '}playable', () {
        final catalog = _parse(
          _catalog(
            surahs: <Map<String, Object?>>[
              _surah(
                100,
                status: status.jsonValue,
                attested: attested,
                media: media,
              ),
            ],
            prophets: <Map<String, Object?>>[
              _prophet('prophet-a', 1, <Map<String, Object?>>[
                _episode(
                  'prophet-a',
                  1,
                  <List<String>>[
                    <String>['2:1', '2:5'],
                  ],
                  status: status.jsonValue,
                  attested: attested,
                  media: media,
                ),
              ]),
            ],
          ),
        );
        final surahStory = catalog.surahStories.single;
        final episode = catalog.prophetSeries.single.episodes.single;
        expect(surahStory.isPlayable, expected);
        expect(episode.isPlayable, expected);
        expect(
          catalog.playableStoryForSurah(100),
          expected ? surahStory : null,
        );
        expect(
          catalog.playableEpisodesFor(const AyahKey(2, 3)).length,
          expected ? 1 : 0,
        );
      });
    }

    test('covers all twelve combinations', () => expect(cases, hasLength(12)));
  });

  group('parser accepts', () {
    test('a full catalog with every optional field', () {
      final catalog = _parse(
        _catalog(
          updatedAt: '2026-06-01T12:30:15.250+02:00',
          surahs: <Map<String, Object?>>[
            {
              ..._surah(78),
              'media': <String, Object?>{
                'type': 'stream',
                'url': _stream,
                'poster_url': 'https://media.example.com/poster.jpg',
                'duration_seconds': 120,
              },
            },
            _surah(79, status: 'in_review', media: false),
          ],
          prophets: <Map<String, Object?>>[
            _prophet('prophet-a', 1, <Map<String, Object?>>[
              {
                ..._episode('prophet-a', 1, <List<String>>[
                  <String>['1:1', '1:1'],
                ]),
                'title_ar': 'Item A',
                'title_en': 'Item A',
                'media': <String, Object?>{
                  'type': 'youtube',
                  'video_id': 'A-b_c123456',
                  'channel_name': 'Channel A',
                  'duration_seconds': 60,
                },
              },
            ]),
          ],
        ),
      );
      expect(catalog.updatedAt, DateTime.utc(2026, 6, 1, 10, 30, 15, 250));
      expect(
        catalog.surahStories.first.media,
        StreamMedia(
          url: Uri.parse(_stream),
          posterUrl: Uri.parse('https://media.example.com/poster.jpg'),
          durationSeconds: 120,
        ),
      );
      final episode = catalog.prophetSeries.single.episodes.single;
      expect(episode.titleEn, 'Item A');
      expect(
        episode.media,
        const YoutubeMedia(
          videoId: 'A-b_c123456',
          channelName: 'Channel A',
          durationSeconds: 60,
        ),
      );
      expect(
        episode.review,
        Review(
          status: ReviewStatus.approved,
          reviewer: 'Reviewer A',
          approvedAt: DateTime.utc(2026, 1, 2),
        ),
      );
      expect(episode.relatedAyahs, <AyahKeyRange>[
        const AyahKeyRange(AyahKey(1, 1), AyahKey(1, 1)),
      ]);
    });

    test('equal JSON into equal catalogs', () {
      expect(_parse(_catalog()), _parse(_catalog()));
      expect(_parse(_catalog()).hashCode, _parse(_catalog()).hashCode);
      expect(
        _parse(_catalog()),
        isNot(_parse(_catalog(updatedAt: '2026-06-02T00:00:00Z'))),
      );
    });

    test('ayah keys at the edges of the pattern', () {
      for (final key in <String>['1:1', '114:6', '2:286', '26:227', '9:99']) {
        expect(
          () => _parse(
            _catalog(
              prophets: <Map<String, Object?>>[
                _prophet('prophet-a', 1, <Map<String, Object?>>[
                  _episode('prophet-a', 1, <List<String>>[
                    <String>[key, key],
                  ]),
                ]),
              ],
            ),
          ),
          returnsNormally,
          reason: key,
        );
      }
    });
  });

  group('parser rejects', () {
    Map<String, Object?> withEpisode(Map<String, Object?> episode) => _catalog(
      prophets: <Map<String, Object?>>[
        _prophet('prophet-a', 1, <Map<String, Object?>>[episode]),
      ],
    );
    Map<String, Object?> withRange(Object? from, Object? to) => withEpisode(
      _episode('prophet-a', 1, const <List<String>>[])
        ..['related_ayahs'] = <Object?>[
          <String, Object?>{'from': from, 'to': to},
        ],
    );
    Map<String, Object?> withSurah(Map<String, Object?> surah) =>
        _catalog(surahs: <Map<String, Object?>>[surah]);
    Map<String, Object?> withMedia(Object? media) =>
        withSurah(_surah(100)..['media'] = media);

    test('text that is not JSON', () {
      _rejects<CatalogJsonException>('{"schema_version": 1,');
    });

    test('an unknown or missing schema version', () {
      for (final version in <Object?>[2, 0, '1', 1.5, null]) {
        _rejects<UnsupportedSchemaVersionException>(
          _catalog()..['schema_version'] = version,
        );
      }
      _rejects<MissingFieldException>(_catalog()..remove('schema_version'));
    });

    test('a newer schema version even with unknown fields', () {
      _rejects<UnsupportedSchemaVersionException>(<String, Object?>{
        'schema_version': 2,
        'something_new': true,
      });
    });

    test('a missing required field anywhere', () {
      for (final key in <String>[
        'updated_at',
        'surah_stories',
        'prophet_series',
      ]) {
        _rejects<MissingFieldException>(_catalog()..remove(key));
      }
      for (final key in <String>[
        'id',
        'surah',
        'review',
        'no_prophet_depiction',
      ]) {
        _rejects<MissingFieldException>(withSurah(_surah(100)..remove(key)));
      }
      for (final key in <String>['id', 'order', 'name_ar', 'name_en']) {
        _rejects<MissingFieldException>(
          _catalog(
            prophets: <Map<String, Object?>>[
              _prophet('prophet-a', 1)..remove(key),
            ],
          ),
        );
      }
      _rejects<MissingFieldException>(
        _catalog(
          prophets: <Map<String, Object?>>[
            _prophet('prophet-a', 1)..remove('episodes'),
          ],
        ),
      );
      for (final key in <String>[
        'id',
        'order',
        'review',
        'no_prophet_depiction',
        'related_ayahs',
      ]) {
        _rejects<MissingFieldException>(
          withEpisode(
            _episode('prophet-a', 1, const <List<String>>[])..remove(key),
          ),
        );
      }
      _rejects<MissingFieldException>(
        withSurah(_surah(100)..['review'] = <String, Object?>{}),
      );
      for (final key in <String>['reviewer', 'approved_at']) {
        _rejects<MissingFieldException>(
          withSurah(
            _surah(100)..['review'] = (_review('approved')..remove(key)),
          ),
        );
      }
      _rejects<MissingFieldException>(
        withMedia(<String, Object?>{'url': _stream}),
      );
      _rejects<MissingFieldException>(
        withMedia(<String, Object?>{'type': 'stream'}),
      );
      _rejects<MissingFieldException>(
        withMedia(<String, Object?>{'type': 'youtube'}),
      );
      _rejects<MissingFieldException>(
        withEpisode(
          _episode('prophet-a', 1, const <List<String>>[])
            ..['related_ayahs'] = <Object?>[
              <String, Object?>{'from': '1:1'},
            ],
        ),
      );
    });

    test('a bad ayah key', () {
      for (final key in <Object?>[
        '0:1',
        '115:1',
        '1:0',
        '2:300',
        '01:1',
        '1:01',
        '1',
        '1:1:1',
        ' 1:1',
        '1:1 ',
        '',
        12,
        null,
      ]) {
        _rejects<InvalidAyahKeyException>(withRange(key, '114:6'));
        _rejects<InvalidAyahKeyException>(withRange('1:1', key));
      }
    });

    test('a range whose from is after its to', () {
      _rejects<InvalidAyahRangeException>(withRange('2:6', '2:5'));
      _rejects<InvalidAyahRangeException>(withRange('3:1', '2:200'));
      // Compared by number, not as text.
      _rejects<InvalidAyahRangeException>(withRange('10:1', '9:1'));
      _rejects<InvalidAyahRangeException>(withRange('2:10', '2:9'));
      expect(() => _parse(withRange('9:1', '10:1')), returnsNormally);
      expect(() => _parse(withRange('2:9', '2:10')), returnsNormally);
    });

    test('a URL that is not HTTPS', () {
      for (final url in <String>[
        'http://media.example.com/a.mp4',
        'ftp://media.example.com/a.mp4',
        '//media.example.com/a.mp4',
        'HTTP://media.example.com/a.mp4',
      ]) {
        _rejects<InsecureUrlException>(
          withMedia(<String, Object?>{'type': 'stream', 'url': url}),
        );
        _rejects<InsecureUrlException>(
          withMedia(<String, Object?>{
            'type': 'stream',
            'url': _stream,
            'poster_url': url,
          }),
        );
      }
    });

    test('anything else the schema forbids', () {
      final cases = <String, Map<String, Object?>>{
        'unknown root field': _catalog()..['extra'] = 1,
        'unknown surah field': withSurah(_surah(100)..['title'] = 'Item A'),
        'unknown review field': withSurah(
          _surah(100)..['review'] = (_review('planned')..['note'] = 'x'),
        ),
        'unknown media field': withMedia(<String, Object?>{
          'type': 'stream',
          'url': _stream,
          'video_id': 'abcdefghijk',
        }),
        'unknown episode field': withEpisode(
          _episode('prophet-a', 1, const <List<String>>[])..['text'] = 'x',
        ),
        'unknown range field': withEpisode(
          _episode('prophet-a', 1, const <List<String>>[])
            ..['related_ayahs'] = <Object?>[
              <String, Object?>{'from': '1:1', 'to': '1:2', 'x': 1},
            ],
        ),
        'bad updated_at': _catalog(updatedAt: '2026-06-01'),
        'updated_at without offset': _catalog(updatedAt: '2026-06-01T00:00:00'),
        'impossible updated_at': _catalog(updatedAt: '2026-02-30T00:00:00Z'),
        'updated_at hour 24': _catalog(updatedAt: '2026-02-03T24:00:00Z'),
        'surah_stories not an array': _catalog()..['surah_stories'] = 1,
        'bad surah id': withSurah(_surah(100)..['id'] = 'surah-1'),
        'surah 0': withSurah(_surah(100)..['surah'] = 0),
        'surah 115': withSurah(_surah(100)..['surah'] = 115),
        'surah as string': withSurah(_surah(100)..['surah'] = '100'),
        'attestation as string': withSurah(
          _surah(100)..['no_prophet_depiction'] = 'true',
        ),
        'attestation null': withSurah(
          _surah(100)..['no_prophet_depiction'] = null,
        ),
        'unknown status': withSurah(
          _surah(100)..['review'] = <String, Object?>{'status': 'done'},
        ),
        'empty reviewer': withSurah(
          _surah(100)..['review'] = (_review('approved')..['reviewer'] = ''),
        ),
        'bad approved_at': withSurah(
          _surah(100)
            ..['review'] = (_review('approved')
              ..['approved_at'] = '2026-13-01'),
        ),
        'unknown media type': withMedia(<String, Object?>{
          'type': 'vimeo',
          'url': _stream,
        }),
        'media null': withMedia(null),
        'bad video id': withMedia(<String, Object?>{
          'type': 'youtube',
          'video_id': 'short',
        }),
        'zero duration': withMedia(<String, Object?>{
          'type': 'stream',
          'url': _stream,
          'duration_seconds': 0,
        }),
        'fractional duration': withMedia(<String, Object?>{
          'type': 'stream',
          'url': _stream,
          'duration_seconds': 1.5,
        }),
        'URL without host': withMedia(<String, Object?>{
          'type': 'stream',
          'url': 'https://',
        }),
        'bad prophet id': _catalog(
          prophets: <Map<String, Object?>>[_prophet('Prophet-A', 1)],
        ),
        'prophet order 0': _catalog(
          prophets: <Map<String, Object?>>[_prophet('prophet-a', 0)],
        ),
        'empty prophet name': _catalog(
          prophets: <Map<String, Object?>>[
            _prophet('prophet-a', 1)..['name_en'] = '',
          ],
        ),
        'bad episode id': withEpisode(
          _episode('prophet-a', 1, const <List<String>>[])
            ..['id'] = 'prophet-a-1',
        ),
        'title not a string': withEpisode(
          _episode('prophet-a', 1, const <List<String>>[])..['title_en'] = 1,
        ),
        'related_ayahs not an array': withEpisode(
          _episode('prophet-a', 1, const <List<String>>[])
            ..['related_ayahs'] = '1:1',
        ),
        'duplicate surah': _catalog(
          surahs: <Map<String, Object?>>[
            _surah(100),
            _surah(100)..['id'] = 'surah-999',
          ],
        ),
        'duplicate id': _catalog(
          surahs: <Map<String, Object?>>[
            _surah(100),
            _surah(101)..['id'] = 'surah-100',
          ],
        ),
        'duplicate prophet order': _catalog(
          prophets: <Map<String, Object?>>[
            _prophet('prophet-a', 1),
            _prophet('prophet-b', 1),
          ],
        ),
        'duplicate episode order': _catalog(
          prophets: <Map<String, Object?>>[
            _prophet('prophet-a', 1, <Map<String, Object?>>[
              _episode('prophet-a', 1, const <List<String>>[]),
              _episode('prophet-a', 1, const <List<String>>[])
                ..['id'] = 'prophet-a-ep02',
            ]),
          ],
        ),
      };
      _rejects<InvalidFieldException>('[]');
      for (final MapEntry(:key, :value) in cases.entries) {
        expect(
          () => _parse(value),
          throwsA(isA<InvalidFieldException>()),
          reason: key,
        );
      }
    });
  });

  group('queries', () {
    late Catalog catalog;

    setUp(() {
      catalog = _parse(
        _catalog(
          surahs: <Map<String, Object?>>[
            _surah(114, status: 'planned', attested: false, media: false),
            _surah(1),
            _surah(80),
            _surah(78, status: 'in_review'),
          ],
          prophets: <Map<String, Object?>>[
            _prophet('prophet-b', 2, <Map<String, Object?>>[
              _episode('prophet-b', 2, <List<String>>[
                <String>['20:9', '20:98'],
              ]),
              _episode('prophet-b', 1, <List<String>>[
                <String>['20:9', '20:12'],
                <String>['28:3', '28:13'],
              ]),
              _episode('prophet-b', 3, <List<String>>[
                <String>['20:9', '20:12'],
              ], status: 'in_review'),
            ]),
            _prophet('prophet-a', 1, <Map<String, Object?>>[
              _episode('prophet-a', 1, <List<String>>[
                <String>['19:99', '21:5'],
              ]),
            ]),
          ],
        ),
      );
    });

    test('Juz Amma stories in surah order', () {
      expect(catalog.juzAmmaStories.map((s) => s.surah), <int>[78, 80, 114]);
    });

    test('the playable story for a surah', () {
      expect(catalog.playableStoryForSurah(80)?.id, 'surah-080');
      expect(catalog.playableStoryForSurah(1)?.id, 'surah-001');
      expect(catalog.playableStoryForSurah(78), isNull);
      expect(catalog.playableStoryForSurah(114), isNull);
      expect(catalog.playableStoryForSurah(79), isNull);
    });

    test('the prophet series in order, episodes in order', () {
      expect(catalog.prophetSeriesInOrder.map((s) => s.id), <String>[
        'prophet-a',
        'prophet-b',
      ]);
      expect(
        catalog.prophetSeriesInOrder[1].episodesInOrder.map((e) => e.order),
        <int>[1, 2, 3],
      );
    });

    List<String> episodesFor(int surah, int ayah) => <String>[
      for (final match in catalog.playableEpisodesFor(AyahKey(surah, ayah)))
        match.episode.id,
    ];

    test('playable episodes that contain an ayah, in series order', () {
      expect(episodesFor(20, 10), <String>[
        'prophet-a-ep01',
        'prophet-b-ep01',
        'prophet-b-ep02',
      ]);
      expect(episodesFor(28, 5), <String>['prophet-b-ep01']);
      expect(episodesFor(2, 255), isEmpty);
      final match = catalog.playableEpisodesFor(const AyahKey(28, 5)).single;
      expect(match.story.id, 'prophet-b');
    });

    test('range boundaries are inclusive and compared by number', () {
      // 20:9 to 20:98.
      expect(episodesFor(20, 8), <String>['prophet-a-ep01']);
      expect(episodesFor(20, 9), contains('prophet-b-ep02'));
      expect(episodesFor(20, 98), contains('prophet-b-ep02'));
      expect(episodesFor(20, 99), isNot(contains('prophet-b-ep02')));
      expect(episodesFor(20, 100), isNot(contains('prophet-b-ep02')));
      // 20:9 to 20:12: 20:100 is after 20:12 even though "100" < "12".
      expect(episodesFor(20, 12), contains('prophet-b-ep01'));
      expect(episodesFor(20, 13), isNot(contains('prophet-b-ep01')));
      // 19:99 to 21:5 spans surahs.
      expect(episodesFor(19, 98), isEmpty);
      expect(episodesFor(19, 99), <String>['prophet-a-ep01']);
      expect(episodesFor(19, 200), <String>['prophet-a-ep01']);
      expect(episodesFor(21, 1), <String>['prophet-a-ep01']);
      expect(episodesFor(21, 5), <String>['prophet-a-ep01']);
      expect(episodesFor(21, 6), isEmpty);
      expect(episodesFor(3, 1), isEmpty);
    });

    test('a range of one ayah', () {
      const range = AyahKeyRange(AyahKey(9, 9), AyahKey(9, 9));
      expect(range.contains(const AyahKey(9, 9)), isTrue);
      expect(range.contains(const AyahKey(9, 8)), isFalse);
      expect(range.contains(const AyahKey(9, 10)), isFalse);
    });

    test('lists are unmodifiable', () {
      expect(
        () => catalog.surahStories.add(catalog.surahStories.first),
        throwsUnsupportedError,
      );
      expect(
        () => catalog.prophetSeries.first.episodes.clear(),
        throwsUnsupportedError,
      );
    });
  });

  group('repository', () {
    late Directory temp;
    final remoteUrl = Uri.parse('https://catalog.example.com/catalog.json');

    final bundled = jsonEncode(_catalog(updatedAt: '2026-01-01T00:00:00Z'));
    final older = jsonEncode(
      _catalog(
        updatedAt: '2025-12-31T23:59:59Z',
        surahs: <Map<String, Object?>>[_surah(78)],
      ),
    );
    final newer = jsonEncode(
      _catalog(
        updatedAt: '2026-02-01T00:00:00Z',
        surahs: <Map<String, Object?>>[_surah(79)],
      ),
    );
    final newest = jsonEncode(
      _catalog(
        updatedAt: '2026-03-01T00:00:00+01:00',
        surahs: <Map<String, Object?>>[_surah(80)],
      ),
    );

    setUp(() {
      temp = Directory.systemTemp.createTempSync('catalog_test');
    });

    tearDown(() {
      temp.deleteSync(recursive: true);
    });

    File cacheFile() => File('${temp.path}/${CatalogRepository.cacheFileName}');

    var requests = 0;

    http.Client client(Future<http.Response> Function() respond) =>
        MockClient((request) {
          requests++;
          expect(request.url, remoteUrl);
          return respond();
        });

    http.Client serving(String body, {int status = 200}) =>
        client(() async => http.Response.bytes(utf8.encode(body), status));

    CatalogRepository repository({
      http.Client? httpClient,
      Uri? url,
      String? bundledText,
      Duration timeout = const Duration(seconds: 10),
    }) => CatalogRepository(
      loadBundled: () async => bundledText ?? bundled,
      cacheDirectory: () async => temp,
      remoteUrl: url ?? (httpClient == null ? null : remoteUrl),
      client: httpClient,
      timeout: timeout,
    );

    setUp(() => requests = 0);

    test('loads the bundled catalog with nothing cached', () async {
      final repo = repository();
      expect(repo.current, isNull);
      expect(await repo.load(), CatalogParser.parse(bundled));
      expect(repo.current, CatalogParser.parse(bundled));
      expect(repo.canRefresh, isFalse);
      expect(await repo.refresh(), CatalogParser.parse(bundled));
    });

    test('a newer remote catalog is adopted and cached as raw JSON', () async {
      final repo = repository(httpClient: serving(newer));
      await repo.load();
      expect(await repo.refresh(), CatalogParser.parse(newer));
      expect(repo.current, CatalogParser.parse(newer));
      expect(cacheFile().readAsStringSync(), newer);
      expect(requests, 1);

      // The next launch starts from the cache, without the network.
      expect(await repository().load(), CatalogParser.parse(newer));
    });

    test('refresh loads first when needed', () async {
      final repo = repository(httpClient: serving(newer));
      expect(await repo.refresh(), CatalogParser.parse(newer));
    });

    test('an older or equal remote catalog is ignored', () async {
      for (final body in <String>[older, bundled]) {
        final repo = repository(httpClient: serving(body));
        await repo.load();
        expect(await repo.refresh(), CatalogParser.parse(bundled));
        expect(cacheFile().existsSync(), isFalse);
      }
    });

    test('a remote catalog older than the cache is ignored', () async {
      cacheFile().writeAsStringSync(newest);
      final repo = repository(httpClient: serving(newer));
      expect(await repo.load(), CatalogParser.parse(newest));
      expect(await repo.refresh(), CatalogParser.parse(newest));
      expect(cacheFile().readAsStringSync(), newest);
    });

    test('network failures keep the previous catalog silently', () async {
      final failures = <String, http.Client>{
        'socket error': client(
          () async => throw const SocketException('offline'),
        ),
        'client error': client(
          () async => throw http.ClientException('failed'),
        ),
        'server error': serving(newer, status: 500),
        'not found': serving(newer, status: 404),
      };
      for (final MapEntry(:key, :value) in failures.entries) {
        cacheFile().writeAsStringSync(newer);
        final repo = repository(httpClient: value);
        await repo.load();
        expect(await repo.refresh(), CatalogParser.parse(newer), reason: key);
        expect(cacheFile().readAsStringSync(), newer, reason: key);
      }
    });

    test('a slow server times out and keeps the catalog', () async {
      final never = Completer<http.Response>();
      final repo = repository(
        httpClient: client(() => never.future),
        timeout: const Duration(milliseconds: 20),
      );
      await repo.load();
      expect(await repo.refresh(), CatalogParser.parse(bundled));
      expect(cacheFile().existsSync(), isFalse);
    });

    test('an invalid remote catalog is ignored and not cached', () async {
      final invalid = <String>[
        'not json',
        jsonEncode(
          (jsonDecode(newest) as Map<String, Object?>)..['schema_version'] = 2,
        ),
        jsonEncode(
          _catalog(
            updatedAt: '2027-01-01T00:00:00Z',
            surahs: <Map<String, Object?>>[
              _surah(100)
                ..['media'] = <String, Object?>{
                  'type': 'stream',
                  'url': 'http://media.example.com/a.mp4',
                },
            ],
          ),
        ),
      ];
      for (final body in invalid) {
        final repo = repository(httpClient: serving(body));
        await repo.load();
        expect(await repo.refresh(), CatalogParser.parse(bundled));
        expect(cacheFile().existsSync(), isFalse);
      }
    });

    test('decodes the response as UTF-8 whatever the headers say', () async {
      final arabic = jsonEncode(
        _catalog(
          updatedAt: '2026-02-01T00:00:00Z',
          prophets: <Map<String, Object?>>[
            _prophet('prophet-a', 1)..['name_ar'] = 'عنصر',
          ],
        ),
      );
      final repo = repository(
        httpClient: client(
          () async => http.Response.bytes(utf8.encode(arabic), 200),
        ),
      );
      final catalog = await repo.refresh();
      expect(catalog.prophetSeries.single.nameAr, 'عنصر');
    });

    test('a corrupt or invalid cache is ignored', () async {
      for (final contents in <String>[
        '{"schema_version": 1, "upd',
        jsonEncode(
          (jsonDecode(newest) as Map<String, Object?>)..['schema_version'] = 9,
        ),
        jsonEncode(
          (jsonDecode(newest) as Map<String, Object?>)..remove('updated_at'),
        ),
      ]) {
        cacheFile().writeAsStringSync(contents);
        expect(await repository().load(), CatalogParser.parse(bundled));
      }
    });

    test('a corrupt cache is replaced by the next valid refresh', () async {
      cacheFile().writeAsStringSync('garbage');
      final repo = repository(httpClient: serving(newer));
      expect(await repo.load(), CatalogParser.parse(bundled));
      expect(await repo.refresh(), CatalogParser.parse(newer));
      expect(cacheFile().readAsStringSync(), newer);
    });

    test('a cache older than the bundled catalog is ignored', () async {
      cacheFile().writeAsStringSync(older);
      expect(await repository().load(), CatalogParser.parse(bundled));
    });

    test('a valid cache covers an invalid bundled catalog', () async {
      cacheFile().writeAsStringSync(newer);
      expect(
        await repository(bundledText: 'broken').load(),
        CatalogParser.parse(newer),
      );
      cacheFile().deleteSync();
      expect(
        repository(bundledText: 'broken').load(),
        throwsA(isA<CatalogJsonException>()),
      );
    });

    test('an unwritable cache still adopts the remote catalog', () async {
      final repo = CatalogRepository(
        loadBundled: () async => bundled,
        cacheDirectory: () async => Directory('${temp.path}/missing/dir'),
        remoteUrl: remoteUrl,
        client: serving(newer),
      );
      expect(await repo.refresh(), CatalogParser.parse(newer));
    });

    test('CATALOG_URL accepts only HTTPS URLs', () {
      expect(catalogUrlFrom(''), isNull);
      expect(catalogUrlFrom('http://catalog.example.com/c.json'), isNull);
      expect(catalogUrlFrom('not a url'), isNull);
      expect(
        catalogUrlFrom('https://catalog.example.com/c.json'),
        Uri.parse('https://catalog.example.com/c.json'),
      );
      expect(catalogUrlDefine, isEmpty);
    });

    group('provider', () {
      ProviderContainer container({Uri? url, http.Client? httpClient}) =>
          ProviderContainer.test(
            overrides: [
              catalogUrlProvider.overrideWithValue(url),
              if (httpClient != null)
                catalogHttpClientProvider.overrideWithValue(httpClient),
              catalogCacheDirectoryProvider.overrideWithValue(() async => temp),
            ],
          );

      test('serves the bundled asset with no CATALOG_URL', () async {
        final c = container();
        final catalog = await c.read(catalogProvider.future);
        expect(
          catalog,
          CatalogParser.parse(File(bundledCatalogAsset).readAsStringSync()),
        );
        expect(c.read(catalogRepositoryProvider).canRefresh, isFalse);
      });

      test('updates once a newer remote catalog arrives', () async {
        final response = Completer<http.Response>();
        final c = container(
          url: remoteUrl,
          httpClient: client(() => response.future),
        );
        final states = <Catalog?>[];
        c.listen(
          catalogProvider,
          (_, next) => states.add(next.value),
          fireImmediately: true,
        );
        final first = await c.read(catalogProvider.future);
        expect(first.surahStories, hasLength(37));

        final remote = jsonEncode(
          _catalog(
            updatedAt: '2099-01-01T00:00:00Z',
            surahs: <Map<String, Object?>>[_surah(112)],
          ),
        );
        response.complete(http.Response.bytes(utf8.encode(remote), 200));
        await _until(() => c.read(catalogProvider).value != first);
        expect(c.read(catalogProvider).value, CatalogParser.parse(remote));
        expect(states.last, CatalogParser.parse(remote));
        expect(cacheFile().readAsStringSync(), remote);
      });

      test('keeps the catalog when the refresh fails', () async {
        final c = container(
          url: remoteUrl,
          httpClient: client(() async => throw const SocketException('x')),
        );
        final first = await c.read(catalogProvider.future);
        await _until(() => requests == 1);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(c.read(catalogProvider).value, first);
        expect(requests, 1);
      });
    });
  });
}
