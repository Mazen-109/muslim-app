import 'dart:convert';

import 'catalog_models.dart';

/// Why a catalog was rejected. Any of these rejects the whole catalog.
///
/// [path] points at the offending value, for example
/// `prophet_series[0].episodes[2].related_ayahs[1]`.
sealed class CatalogFormatException implements Exception {
  const CatalogFormatException(this.path, this.message);

  final String path;
  final String message;

  @override
  String toString() => '$runtimeType at $path: $message';
}

/// The text is not JSON.
final class CatalogJsonException extends CatalogFormatException {
  const CatalogJsonException(String message) : super(r'$', message);
}

/// `schema_version` is not the one this build reads.
final class UnsupportedSchemaVersionException extends CatalogFormatException {
  const UnsupportedSchemaVersionException(this.version)
    : super('schema_version', 'unsupported schema version');

  final Object? version;
}

/// A required field is absent.
final class MissingFieldException extends CatalogFormatException {
  const MissingFieldException(String path, this.field)
    : super(path, 'required field "$field" is missing');

  final String field;
}

/// An ayah key does not match `S:A` with a surah from 1 to 114.
final class InvalidAyahKeyException extends CatalogFormatException {
  const InvalidAyahKeyException(String path, this.value)
    : super(path, 'not a valid ayah key');

  final Object? value;
}

/// A range whose `from` comes after its `to` in Mushaf order.
final class InvalidAyahRangeException extends CatalogFormatException {
  const InvalidAyahRangeException(String path, this.from, this.to)
    : super(path, '"from" $from is after "to" $to');

  final AyahKey from;
  final AyahKey to;
}

/// A URL that is not HTTPS.
final class InsecureUrlException extends CatalogFormatException {
  const InsecureUrlException(String path, this.value)
    : super(path, 'URL must use https');

  final Object? value;
}

/// Any other schema violation: a wrong type, an unknown field, a value out
/// of range or not matching its pattern, or a duplicate.
final class InvalidFieldException extends CatalogFormatException {
  const InvalidFieldException(super.path, super.message);
}

/// Parses catalog JSON strictly against `contracts/catalog.schema.json`.
///
/// Beyond the schema it also rejects duplicate item ids, two stories for the
/// same surah, two prophet stories with the same order and two episodes of
/// one story with the same order, so every query has one answer.
abstract final class CatalogParser {
  /// Parses [jsonText]; throws a [CatalogFormatException] on any violation.
  static Catalog parse(String jsonText) {
    final Object? decoded;
    try {
      decoded = jsonDecode(jsonText);
    } on FormatException catch (e) {
      throw CatalogJsonException(e.message);
    }
    return _Parser().catalog(decoded);
  }
}

final RegExp _ayahKeyPattern = RegExp(
  r'^([1-9]|[1-9][0-9]|10[0-9]|11[0-4]):([1-9]|[1-9][0-9]|[12][0-9]{2})$',
);
final RegExp _surahIdPattern = RegExp(r'^surah-[0-9]{3}$');
final RegExp _prophetIdPattern = RegExp(r'^prophet-[a-z0-9-]+$');
final RegExp _episodeIdPattern = RegExp(r'^prophet-[a-z0-9-]+-ep[0-9]{2}$');
final RegExp _youtubeIdPattern = RegExp(r'^[A-Za-z0-9_-]{11}$');
final RegExp _datePattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');
final RegExp _dateTimePattern = RegExp(
  r'^(\d{4})-(\d{2})-(\d{2})[Tt](\d{2}):(\d{2}):(\d{2})(\.\d+)?'
  r'([Zz]|[+-](\d{2}):(\d{2}))$',
);

class _Parser {
  final Set<String> _ids = <String>{};

  Catalog catalog(Object? raw) {
    const where = r'$';
    if (raw is! Map<String, Object?>) {
      throw const InvalidFieldException(where, 'must be an object');
    }
    // The version is checked first: a newer catalog may have any shape.
    if (!raw.containsKey('schema_version')) {
      throw const MissingFieldException(where, 'schema_version');
    }
    final version = raw['schema_version'];
    if (version is! int || version != Catalog.supportedSchemaVersion) {
      throw UnsupportedSchemaVersionException(version);
    }
    final map = _object(raw, where, const {
      'schema_version',
      'updated_at',
      'surah_stories',
      'prophet_series',
    });
    final updatedAt = _dateTime(_required(map, 'updated_at', where), where);

    final surahs = <int>{};
    final surahStories = <SurahStory>[];
    final rawSurahs = _array(map, 'surah_stories', where);
    for (var i = 0; i < rawSurahs.length; i++) {
      final story = _surahStory(rawSurahs[i], 'surah_stories[$i]');
      if (!surahs.add(story.surah)) {
        throw InvalidFieldException(
          'surah_stories[$i].surah',
          'surah ${story.surah} already has a story',
        );
      }
      surahStories.add(story);
    }

    final orders = <int>{};
    final prophetSeries = <ProphetStory>[];
    final rawProphets = _array(map, 'prophet_series', where);
    for (var i = 0; i < rawProphets.length; i++) {
      final story = _prophetStory(rawProphets[i], 'prophet_series[$i]');
      if (!orders.add(story.order)) {
        throw InvalidFieldException(
          'prophet_series[$i].order',
          'order ${story.order} is used twice',
        );
      }
      prophetSeries.add(story);
    }

    return Catalog(
      schemaVersion: version,
      updatedAt: updatedAt,
      surahStories: surahStories,
      prophetSeries: prophetSeries,
    );
  }

  SurahStory _surahStory(Object? raw, String where) {
    final map = _object(raw, where, const {
      'id',
      'surah',
      'review',
      'no_prophet_depiction',
      'media',
    });
    final id = _id(map, _surahIdPattern, where);
    final surah = _int(map, 'surah', where, min: 1, max: 114);
    return SurahStory(
      id: id,
      surah: surah,
      review: _review(_required(map, 'review', where), '$where.review'),
      noProphetDepiction: _bool(map, 'no_prophet_depiction', where),
      media: map.containsKey('media')
          ? _media(map['media'], '$where.media')
          : null,
    );
  }

  ProphetStory _prophetStory(Object? raw, String where) {
    final map = _object(raw, where, const {
      'id',
      'order',
      'name_ar',
      'name_en',
      'episodes',
    });
    final id = _id(map, _prophetIdPattern, where);
    final order = _int(map, 'order', where, min: 1);
    final nameAr = _string(map, 'name_ar', where, nonEmpty: true);
    final nameEn = _string(map, 'name_en', where, nonEmpty: true);

    final orders = <int>{};
    final episodes = <ProphetEpisode>[];
    final rawEpisodes = _array(map, 'episodes', where);
    for (var i = 0; i < rawEpisodes.length; i++) {
      final episode = _episode(rawEpisodes[i], '$where.episodes[$i]');
      if (!orders.add(episode.order)) {
        throw InvalidFieldException(
          '$where.episodes[$i].order',
          'order ${episode.order} is used twice',
        );
      }
      episodes.add(episode);
    }
    return ProphetStory(
      id: id,
      order: order,
      nameAr: nameAr,
      nameEn: nameEn,
      episodes: episodes,
    );
  }

  ProphetEpisode _episode(Object? raw, String where) {
    final map = _object(raw, where, const {
      'id',
      'order',
      'title_ar',
      'title_en',
      'review',
      'no_prophet_depiction',
      'media',
      'related_ayahs',
    });
    final id = _id(map, _episodeIdPattern, where);
    final order = _int(map, 'order', where, min: 1);
    final review = _review(_required(map, 'review', where), '$where.review');
    final attestation = _bool(map, 'no_prophet_depiction', where);
    final rawRanges = _array(map, 'related_ayahs', where);
    return ProphetEpisode(
      id: id,
      order: order,
      titleAr: _optionalString(map, 'title_ar', where),
      titleEn: _optionalString(map, 'title_en', where),
      review: review,
      noProphetDepiction: attestation,
      media: map.containsKey('media')
          ? _media(map['media'], '$where.media')
          : null,
      relatedAyahs: <AyahKeyRange>[
        for (var i = 0; i < rawRanges.length; i++)
          _range(rawRanges[i], '$where.related_ayahs[$i]'),
      ],
    );
  }

  Review _review(Object? raw, String where) {
    final map = _object(raw, where, const {
      'status',
      'reviewer',
      'approved_at',
    });
    final statusValue = _string(map, 'status', where);
    final status = ReviewStatus.values
        .where((s) => s.jsonValue == statusValue)
        .firstOrNull;
    if (status == null) {
      throw InvalidFieldException('$where.status', 'unknown review status');
    }
    if (status == ReviewStatus.approved) {
      _required(map, 'reviewer', where);
      _required(map, 'approved_at', where);
    }
    final reviewer = map.containsKey('reviewer')
        ? _string(map, 'reviewer', where, nonEmpty: true)
        : null;
    final approvedAt = map.containsKey('approved_at')
        ? _date(map['approved_at'], '$where.approved_at')
        : null;
    return Review(status: status, reviewer: reviewer, approvedAt: approvedAt);
  }

  StoryMedia _media(Object? raw, String where) {
    if (raw is! Map<String, Object?>) {
      throw InvalidFieldException(where, 'must be an object');
    }
    final type = _string(raw, 'type', where);
    switch (type) {
      case 'stream':
        final map = _object(raw, where, const {
          'type',
          'url',
          'poster_url',
          'duration_seconds',
        });
        return StreamMedia(
          url: _https(_required(map, 'url', where), '$where.url'),
          posterUrl: map.containsKey('poster_url')
              ? _https(map['poster_url'], '$where.poster_url')
              : null,
          durationSeconds: _optionalDuration(map, where),
        );
      case 'youtube':
        final map = _object(raw, where, const {
          'type',
          'video_id',
          'channel_name',
          'duration_seconds',
        });
        final videoId = _string(map, 'video_id', where);
        if (!_youtubeIdPattern.hasMatch(videoId)) {
          throw InvalidFieldException(
            '$where.video_id',
            'not a YouTube video id',
          );
        }
        return YoutubeMedia(
          videoId: videoId,
          channelName: _optionalString(map, 'channel_name', where),
          durationSeconds: _optionalDuration(map, where),
        );
      default:
        throw InvalidFieldException('$where.type', 'unknown media type');
    }
  }

  int? _optionalDuration(Map<String, Object?> map, String where) =>
      map.containsKey('duration_seconds')
      ? _int(map, 'duration_seconds', where, min: 1)
      : null;

  AyahKeyRange _range(Object? raw, String where) {
    final map = _object(raw, where, const {'from', 'to'});
    final from = _ayahKey(_required(map, 'from', where), '$where.from');
    final to = _ayahKey(_required(map, 'to', where), '$where.to');
    if (from.compareTo(to) > 0) {
      throw InvalidAyahRangeException(where, from, to);
    }
    return AyahKeyRange(from, to);
  }

  AyahKey _ayahKey(Object? raw, String where) {
    final match = raw is String ? _ayahKeyPattern.firstMatch(raw) : null;
    if (match == null) throw InvalidAyahKeyException(where, raw);
    return AyahKey(int.parse(match.group(1)!), int.parse(match.group(2)!));
  }

  Uri _https(Object? raw, String where) {
    if (raw is! String) throw InvalidFieldException(where, 'must be a string');
    if (!raw.startsWith('https://')) throw InsecureUrlException(where, raw);
    final uri = Uri.tryParse(raw);
    if (uri == null || uri.host.isEmpty) {
      throw InvalidFieldException(where, 'not a valid URL');
    }
    return uri;
  }

  String _id(Map<String, Object?> map, RegExp pattern, String where) {
    final id = _string(map, 'id', where);
    if (!pattern.hasMatch(id)) {
      throw InvalidFieldException('$where.id', 'must match ${pattern.pattern}');
    }
    if (!_ids.add(id)) {
      throw InvalidFieldException('$where.id', 'id "$id" is used twice');
    }
    return id;
  }

  DateTime _dateTime(Object? raw, String where) {
    final at = '$where.updated_at';
    final match = raw is String ? _dateTimePattern.firstMatch(raw) : null;
    if (match == null) {
      throw InvalidFieldException(at, 'must be an RFC 3339 date-time');
    }
    final date = _calendarDate(match);
    final hour = int.parse(match.group(4)!);
    final minute = int.parse(match.group(5)!);
    final second = int.parse(match.group(6)!);
    if (hour > 23 || minute > 59 || second > 60) {
      throw InvalidFieldException(at, 'time out of range');
    }
    if (match.group(9) != null &&
        (int.parse(match.group(9)!) > 23 || int.parse(match.group(10)!) > 59)) {
      throw InvalidFieldException(at, 'offset out of range');
    }
    final parsed = DateTime.tryParse(raw as String);
    if (date == null || parsed == null) {
      throw InvalidFieldException(at, 'must be an RFC 3339 date-time');
    }
    return parsed.toUtc();
  }

  DateTime _date(Object? raw, String where) {
    final match = raw is String ? _datePattern.firstMatch(raw) : null;
    final date = match == null ? null : _calendarDate(match);
    if (date == null) {
      throw InvalidFieldException(where, 'must be a date (YYYY-MM-DD)');
    }
    return date;
  }

  /// The UTC date in groups 1 to 3 of [match], or null if no such day exists.
  DateTime? _calendarDate(RegExpMatch match) {
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    final date = DateTime.utc(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }
    return date;
  }

  Map<String, Object?> _object(Object? raw, String where, Set<String> allowed) {
    if (raw is! Map<String, Object?>) {
      throw InvalidFieldException(where, 'must be an object');
    }
    for (final key in raw.keys) {
      if (!allowed.contains(key)) {
        throw InvalidFieldException(where, 'unknown field "$key"');
      }
    }
    return raw;
  }

  Object? _required(Map<String, Object?> map, String key, String where) {
    if (!map.containsKey(key)) throw MissingFieldException(where, key);
    return map[key];
  }

  List<Object?> _array(Map<String, Object?> map, String key, String where) {
    final value = _required(map, key, where);
    if (value is! List<Object?>) {
      throw InvalidFieldException('$where.$key', 'must be an array');
    }
    return value;
  }

  String _string(
    Map<String, Object?> map,
    String key,
    String where, {
    bool nonEmpty = false,
  }) {
    final value = _required(map, key, where);
    if (value is! String) {
      throw InvalidFieldException('$where.$key', 'must be a string');
    }
    if (nonEmpty && value.trim().isEmpty) {
      throw InvalidFieldException('$where.$key', 'must not be empty');
    }
    return value;
  }

  String? _optionalString(Map<String, Object?> map, String key, String where) =>
      map.containsKey(key) ? _string(map, key, where) : null;

  int _int(
    Map<String, Object?> map,
    String key,
    String where, {
    required int min,
    int? max,
  }) {
    final value = _required(map, key, where);
    if (value is! int) {
      throw InvalidFieldException('$where.$key', 'must be an integer');
    }
    if (value < min || (max != null && value > max)) {
      throw InvalidFieldException('$where.$key', 'out of range');
    }
    return value;
  }

  bool _bool(Map<String, Object?> map, String key, String where) {
    final value = _required(map, key, where);
    if (value is! bool) {
      throw InvalidFieldException('$where.$key', 'must be a boolean');
    }
    return value;
  }
}
