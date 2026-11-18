// Synthetic fixtures in the shape of Quran.com API v4 responses.
//
// They hold placeholder tokens only (w1, END1, ...); no Quran or tafsir text.

Map<String, Object?> wordJson(
  int id,
  int position,
  String type,
  String text, {
  required int page,
  required int line,
  int? pageNumber,
  int? lineV1,
}) => {
  'id': id,
  'position': position,
  'audio_url': null,
  'char_type_name': type,
  'text_qpc_hafs': text,
  'line_number': line,
  'page_number': pageNumber ?? page,
  'v1_page': page,
  'line_v1': lineV1 ?? line,
  'text': text,
};

Map<String, Object?> verseJson({
  required int id,
  required String key,
  required int page,
  required List<Map<String, Object?>> words,
  String text = 'w1 w2\u00A0END1',
  int? sajdah,
}) => {
  'id': id,
  'verse_number': int.parse(key.split(':')[1]),
  'verse_key': key,
  'hizb_number': 1,
  'rub_el_hizb_number': 1,
  'ruku_number': 1,
  'manzil_number': 1,
  'sajdah_number': sajdah,
  'text_qpc_hafs': text,
  'text_uthmani': 'u1 u2 U-END1',
  'text_imlaei_simple': 's1 s2',
  'page_number': page,
  'juz_number': 1,
  'words': words,
};

Map<String, Object?> pagination({int? next}) => {
  'per_page': 300,
  'current_page': 1,
  'next_page': next,
  'total_pages': next == null ? 1 : 2,
  'total_records': 1,
};
