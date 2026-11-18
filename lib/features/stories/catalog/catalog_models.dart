import 'package:flutter/foundation.dart';

/// First and last surah of Juz Amma, the range the surah stories cover.
const int juzAmmaFirstSurah = 78;
const int juzAmmaLastSurah = 114;

/// An ayah key from the catalog (`"S:A"`), compared by surah and then ayah
/// number, which is Mushaf order.
@immutable
class AyahKey implements Comparable<AyahKey> {
  const AyahKey(this.surah, this.ayah);

  final int surah;
  final int ayah;

  @override
  int compareTo(AyahKey other) =>
      surah != other.surah ? surah - other.surah : ayah - other.ayah;

  bool operator <=(AyahKey other) => compareTo(other) <= 0;

  @override
  bool operator ==(Object other) =>
      other is AyahKey && other.surah == surah && other.ayah == ayah;

  @override
  int get hashCode => Object.hash(surah, ayah);

  /// The key in catalog form, for example `2:255`.
  @override
  String toString() => '$surah:$ayah';
}

/// An inclusive range of ayahs in Mushaf order; [from] is never after [to].
@immutable
class AyahKeyRange {
  /// The parser guarantees that [from] is not after [to].
  const AyahKeyRange(this.from, this.to);

  final AyahKey from;
  final AyahKey to;

  /// Whether [key] lies between [from] and [to], both included.
  bool contains(AyahKey key) => from <= key && key <= to;

  @override
  bool operator ==(Object other) =>
      other is AyahKeyRange && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);

  @override
  String toString() => '$from-$to';
}

/// Where a catalog item is in its review. Only the content owner changes it,
/// in the catalog; the app never does.
enum ReviewStatus {
  planned('planned'),
  inReview('in_review'),
  approved('approved');

  const ReviewStatus(this.jsonValue);

  /// The value used in `catalog.json`.
  final String jsonValue;
}

/// The review state of an item. [reviewer] and [approvedAt] are always set
/// when [status] is [ReviewStatus.approved].
@immutable
class Review {
  const Review({required this.status, this.reviewer, this.approvedAt});

  final ReviewStatus status;
  final String? reviewer;

  /// The approval date, at midnight UTC.
  final DateTime? approvedAt;

  @override
  bool operator ==(Object other) =>
      other is Review &&
      other.status == status &&
      other.reviewer == reviewer &&
      other.approvedAt == approvedAt;

  @override
  int get hashCode => Object.hash(status, reviewer, approvedAt);

  @override
  String toString() => 'Review(${status.jsonValue}, $reviewer, $approvedAt)';
}

/// The video of an item: an HTTPS stream or a YouTube video.
@immutable
sealed class StoryMedia {
  const StoryMedia({this.durationSeconds});

  final int? durationSeconds;
}

/// An MP4 file or HLS playlist served over HTTPS.
final class StreamMedia extends StoryMedia {
  const StreamMedia({required this.url, this.posterUrl, super.durationSeconds});

  final Uri url;
  final Uri? posterUrl;

  @override
  bool operator ==(Object other) =>
      other is StreamMedia &&
      other.url == url &&
      other.posterUrl == posterUrl &&
      other.durationSeconds == durationSeconds;

  @override
  int get hashCode => Object.hash(url, posterUrl, durationSeconds);

  @override
  String toString() => 'StreamMedia($url)';
}

/// A video from a licensed YouTube channel.
final class YoutubeMedia extends StoryMedia {
  const YoutubeMedia({
    required this.videoId,
    this.channelName,
    super.durationSeconds,
  });

  final String videoId;

  /// The licensed channel, shown as attribution.
  final String? channelName;

  @override
  bool operator ==(Object other) =>
      other is YoutubeMedia &&
      other.videoId == videoId &&
      other.channelName == channelName &&
      other.durationSeconds == durationSeconds;

  @override
  int get hashCode => Object.hash(videoId, channelName, durationSeconds);

  @override
  String toString() => 'YoutubeMedia($videoId)';
}

/// Anything the app might play: a surah story or a prophet episode.
@immutable
sealed class StoryItem {
  const StoryItem({
    required this.id,
    required this.review,
    required this.noProphetDepiction,
    this.media,
  });

  final String id;
  final Review review;

  /// The reviewer's attestation that the video depicts no prophet.
  final bool noProphetDepiction;
  final StoryMedia? media;

  /// Whether the app may play this item (data-model.md section 5). This is
  /// the only place the rule is written; everything else asks this getter.
  bool get isPlayable =>
      review.status == ReviewStatus.approved &&
      noProphetDepiction &&
      media != null;
}

/// The story video of one surah.
final class SurahStory extends StoryItem {
  const SurahStory({
    required super.id,
    required this.surah,
    required super.review,
    required super.noProphetDepiction,
    super.media,
  });

  final int surah;

  @override
  bool operator ==(Object other) =>
      other is SurahStory &&
      other.id == id &&
      other.surah == surah &&
      other.review == review &&
      other.noProphetDepiction == noProphetDepiction &&
      other.media == media;

  @override
  int get hashCode => Object.hash(id, surah, review, noProphetDepiction, media);

  @override
  String toString() => 'SurahStory($id)';
}

/// One episode of a prophet story.
final class ProphetEpisode extends StoryItem {
  ProphetEpisode({
    required super.id,
    required this.order,
    required super.review,
    required super.noProphetDepiction,
    required List<AyahKeyRange> relatedAyahs,
    this.titleAr,
    this.titleEn,
    super.media,
  }) : relatedAyahs = List<AyahKeyRange>.unmodifiable(relatedAyahs);

  final int order;
  final String? titleAr;
  final String? titleEn;

  /// The ayah ranges that tell this episode, supplied with the review.
  final List<AyahKeyRange> relatedAyahs;

  /// Whether one of [relatedAyahs] contains [key].
  bool relatesTo(AyahKey key) => relatedAyahs.any((r) => r.contains(key));

  @override
  bool operator ==(Object other) =>
      other is ProphetEpisode &&
      other.id == id &&
      other.order == order &&
      other.titleAr == titleAr &&
      other.titleEn == titleEn &&
      other.review == review &&
      other.noProphetDepiction == noProphetDepiction &&
      other.media == media &&
      listEquals(other.relatedAyahs, relatedAyahs);

  @override
  int get hashCode => Object.hash(
    id,
    order,
    titleAr,
    titleEn,
    review,
    noProphetDepiction,
    media,
    Object.hashAll(relatedAyahs),
  );

  @override
  String toString() => 'ProphetEpisode($id)';
}

/// The story of one prophet: a name and its episodes.
@immutable
class ProphetStory {
  ProphetStory({
    required this.id,
    required this.order,
    required this.nameAr,
    required this.nameEn,
    required List<ProphetEpisode> episodes,
  }) : episodes = List<ProphetEpisode>.unmodifiable(episodes);

  final String id;

  /// Chronological position in the series, from 1.
  final int order;
  final String nameAr;
  final String nameEn;

  /// Episodes as listed in the catalog.
  final List<ProphetEpisode> episodes;

  /// Episodes sorted by [ProphetEpisode.order].
  List<ProphetEpisode> get episodesInOrder => List<ProphetEpisode>.unmodifiable(
    List<ProphetEpisode>.of(episodes)
      ..sort((a, b) => a.order.compareTo(b.order)),
  );

  @override
  bool operator ==(Object other) =>
      other is ProphetStory &&
      other.id == id &&
      other.order == order &&
      other.nameAr == nameAr &&
      other.nameEn == nameEn &&
      listEquals(other.episodes, episodes);

  @override
  int get hashCode =>
      Object.hash(id, order, nameAr, nameEn, Object.hashAll(episodes));

  @override
  String toString() => 'ProphetStory($id)';
}

/// A playable episode together with the story it belongs to.
typedef EpisodeMatch = ({ProphetStory story, ProphetEpisode episode});

/// A validated story catalog (`contracts/catalog.schema.json`).
@immutable
class Catalog {
  Catalog({
    required this.schemaVersion,
    required this.updatedAt,
    required List<SurahStory> surahStories,
    required List<ProphetStory> prophetSeries,
  }) : surahStories = List<SurahStory>.unmodifiable(surahStories),
       prophetSeries = List<ProphetStory>.unmodifiable(prophetSeries);

  /// The only schema version this build reads.
  static const int supportedSchemaVersion = 1;

  final int schemaVersion;

  /// When the content owner published this catalog, in UTC.
  final DateTime updatedAt;
  final List<SurahStory> surahStories;
  final List<ProphetStory> prophetSeries;

  /// Surah stories for Juz Amma (surahs 78 to 114), in surah order.
  List<SurahStory> get juzAmmaStories => List<SurahStory>.unmodifiable(
    surahStories
        .where(
          (s) => s.surah >= juzAmmaFirstSurah && s.surah <= juzAmmaLastSurah,
        )
        .toList()
      ..sort((a, b) => a.surah.compareTo(b.surah)),
  );

  /// The playable story of [surah], or null.
  SurahStory? playableStoryForSurah(int surah) {
    for (final story in surahStories) {
      if (story.surah == surah && story.isPlayable) return story;
    }
    return null;
  }

  /// The prophet stories in chronological order.
  List<ProphetStory> get prophetSeriesInOrder =>
      List<ProphetStory>.unmodifiable(
        List<ProphetStory>.of(prophetSeries)
          ..sort((a, b) => a.order.compareTo(b.order)),
      );

  /// Playable episodes whose related ayahs contain [key], in series order
  /// and then episode order.
  List<EpisodeMatch> playableEpisodesFor(AyahKey key) =>
      List<EpisodeMatch>.unmodifiable(<EpisodeMatch>[
        for (final story in prophetSeriesInOrder)
          for (final episode in story.episodesInOrder)
            if (episode.isPlayable && episode.relatesTo(key))
              (story: story, episode: episode),
      ]);

  @override
  bool operator ==(Object other) =>
      other is Catalog &&
      other.schemaVersion == schemaVersion &&
      other.updatedAt == updatedAt &&
      listEquals(other.surahStories, surahStories) &&
      listEquals(other.prophetSeries, prophetSeries);

  @override
  int get hashCode => Object.hash(
    schemaVersion,
    updatedAt,
    Object.hashAll(surahStories),
    Object.hashAll(prophetSeries),
  );

  @override
  String toString() => 'Catalog($updatedAt)';
}
