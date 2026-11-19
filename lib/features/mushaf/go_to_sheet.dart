import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/models/ayah_ref.dart';
import '../../data/models/mushaf_page.dart';
import '../../data/models/surah.dart';
import '../../data/quran_repository.dart';
import 'reader_controller.dart';

/// The key of the segment that chooses going to a page.
const ValueKey<String> goToByPageKey = ValueKey<String>('go-to-by-page');

/// The key of the segment that chooses going to a surah and ayah.
const ValueKey<String> goToBySurahKey = ValueKey<String>('go-to-by-surah');

/// The key of the page number field.
const ValueKey<String> goToPageFieldKey = ValueKey<String>('go-to-page');

/// The key of the surah picker.
const ValueKey<String> goToSurahFieldKey = ValueKey<String>('go-to-surah');

/// The key of the ayah number field.
const ValueKey<String> goToAyahFieldKey = ValueKey<String>('go-to-ayah');

/// The key of the button that confirms the sheet.
const ValueKey<String> goToSubmitKey = ValueKey<String>('go-to-submit');

/// The key of the surah picker's entry for surah [surah].
ValueKey<String> goToSurahEntryKey(int surah) =>
    ValueKey<String>('go-to-surah-$surah');

/// What the go-to sheet asks for.
enum GoToMode { page, surah }

/// Opens the go-to sheet over the reader. It completes with the place the
/// reader chose, as a `/mushaf` target, or null when it was dismissed.
///
/// [initialAyahId] fills the fields with the reader's current position.
Future<ReaderTarget?> showGoToSheet(
  BuildContext context, {
  required int initialAyahId,
}) => showModalBottomSheet<ReaderTarget>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (context) => GoToSheet(initialAyahId: initialAyahId),
);

/// Parses a whole number typed with Western (0-9), Arabic-Indic (U+0660 to
/// U+0669) or Eastern Arabic-Indic (U+06F0 to U+06F9) digits, ignoring
/// surrounding spaces. Returns null for anything else.
int? parseGoToNumber(String input) {
  final digits = StringBuffer();
  for (final unit in input.trim().codeUnits) {
    if (unit >= 0x30 && unit <= 0x39) {
      digits.writeCharCode(unit);
    } else if (unit >= 0x0660 && unit <= 0x0669) {
      digits.writeCharCode(unit - 0x0660 + 0x30);
    } else if (unit >= 0x06F0 && unit <= 0x06F9) {
      digits.writeCharCode(unit - 0x06F0 + 0x30);
    } else {
      return null;
    }
  }
  // Six digits is far beyond every range here and keeps the parse exact.
  if (digits.isEmpty || digits.length > 6) return null;
  return int.parse(digits.toString());
}

/// The digits a number field accepts while typing.
final RegExp _digitPattern = RegExp('[0-9٠-٩۰-۹]');

/// Go to a Mushaf page (1 to 604) or to a surah and ayah number (US1,
/// scenario 7). Out-of-range numbers are refused with a message under the
/// field; a valid choice closes the sheet with its target.
///
/// Surah names in the picker come from the content database as stored and
/// are set in the interface font, as in the index.
class GoToSheet extends ConsumerStatefulWidget {
  const GoToSheet({super.key, required this.initialAyahId});

  /// The ayah the fields start from.
  final int initialAyahId;

  @override
  ConsumerState<GoToSheet> createState() => _GoToSheetState();
}

class _GoToSheetState extends ConsumerState<GoToSheet> {
  GoToMode _mode = GoToMode.page;
  final TextEditingController _page = TextEditingController();
  final TextEditingController _surahText = TextEditingController();
  final TextEditingController _ayah = TextEditingController();
  final FocusNode _pageFocus = FocusNode();
  final FocusNode _ayahFocus = FocusNode();

  /// The surah chosen in the picker, or null while its text names none.
  int? _surah;

  String? _pageError;
  String? _surahError;
  String? _ayahError;

  QuranRepository get _repository =>
      ref.read(quranRepositoryProvider).requireValue;

  @override
  void initState() {
    super.initState();
    final repository = _repository;
    final start = repository.refOf(widget.initialAyahId);
    _page.text = '${repository.pageOf(widget.initialAyahId)}';
    _surah = start.surah;
    _ayah.text = '${start.ayah}';
    _surahText.addListener(_followSurahText);
    _selectAllOnFocus(_pageFocus, _page);
    _selectAllOnFocus(_ayahFocus, _ayah);
  }

  /// Keeps [_surah] on the surah the picker's text names, whether it was
  /// picked from the list or typed, so the ayah range follows it.
  void _followSurahText() {
    if (!mounted) return;
    final id = _surahFromText();
    if (id == _surah) return;
    void apply() {
      if (mounted) setState(() => _surah = id);
    }

    // The picker writes its text while it builds.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => apply());
    } else {
      apply();
    }
  }

  /// Selects the field's text when it gains focus, so typing replaces the
  /// prefilled number.
  void _selectAllOnFocus(FocusNode node, TextEditingController controller) {
    node.addListener(() {
      if (!node.hasFocus) return;
      controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: controller.text.length,
      );
    });
  }

  @override
  void dispose() {
    _page.dispose();
    _surahText.dispose();
    _ayah.dispose();
    _pageFocus.dispose();
    _ayahFocus.dispose();
    super.dispose();
  }

  void _submit() {
    final l10n = AppLocalizations.of(context);
    switch (_mode) {
      case GoToMode.page:
        final page = parseGoToNumber(_page.text);
        if (page == null || page < 1 || page > pageCount) {
          setState(() => _pageError = l10n.goToPageOutOfRange(pageCount));
          return;
        }
        Navigator.of(context).pop(PageTarget(page));
      case GoToMode.surah:
        final surahId = _surahFromText();
        if (surahId == null) {
          setState(() {
            _surahError = l10n.goToSurahMissing;
            _ayahError = null;
          });
          return;
        }
        final count = _repository.surah(surahId).ayahCount;
        final ayah = parseGoToNumber(_ayah.text);
        if (ayah == null || ayah < 1 || ayah > count) {
          setState(() {
            _surahError = null;
            _ayahError = l10n.goToAyahOutOfRange(count);
          });
          return;
        }
        Navigator.of(context)
            .pop(AyahTarget(AyahRef(surahId, ayah), highlight: true));
    }
  }

  /// The surah the picker's text names: an entry's label, or a surah
  /// number typed on its own. Null when it names none.
  int? _surahFromText() {
    final text = _surahText.text.trim();
    final number = parseGoToNumber(text);
    if (number != null) {
      return number >= 1 && number <= surahCount ? number : null;
    }
    final l10n = AppLocalizations.of(context);
    for (final surah in _repository.surahs()) {
      if (l10n.goToSurahOption(surah.id, _surahName(surah)) == text) {
        return surah.id;
      }
    }
    return null;
  }

  String _surahName(Surah surah) =>
      Localizations.localeOf(context).languageCode == 'ar'
      ? surah.nameAr
      : surah.nameEn;

  Widget _numberField({
    required Key key,
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required int max,
    required String? error,
    required VoidCallback onChanged,
    bool autofocus = false,
  }) => TextField(
    key: key,
    autofocus: autofocus,
    controller: controller,
    focusNode: focusNode,
    keyboardType: TextInputType.number,
    textInputAction: TextInputAction.go,
    inputFormatters: <TextInputFormatter>[
      FilteringTextInputFormatter.allow(_digitPattern),
      LengthLimitingTextInputFormatter(4),
    ],
    decoration: InputDecoration(
      labelText: label,
      helperText: AppLocalizations.of(context).goToRange(max),
      errorText: error,
      // Messages wrap rather than being cut, at any text size.
      helperMaxLines: 3,
      errorMaxLines: 3,
    ),
    onChanged: (_) => onChanged(),
    onSubmitted: (_) => _submit(),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final repository = ref.watch(quranRepositoryProvider).requireValue;
    final surahs = repository.surahs();
    final chosen = _surah == null ? null : repository.surah(_surah!);

    final fields = switch (_mode) {
      GoToMode.page => <Widget>[
        _numberField(
          key: goToPageFieldKey,
          controller: _page,
          focusNode: _pageFocus,
          label: l10n.goToPageLabel,
          max: pageCount,
          error: _pageError,
          autofocus: true,
          onChanged: () {
            if (_pageError != null) setState(() => _pageError = null);
          },
        ),
      ],
      GoToMode.surah => <Widget>[
        DropdownMenu<int>(
          key: goToSurahFieldKey,
          controller: _surahText,
          initialSelection: _surah,
          expandedInsets: EdgeInsets.zero,
          enableFilter: true,
          requestFocusOnTap: true,
          menuHeight: MediaQuery.sizeOf(context).height / 2,
          label: Text(l10n.goToSurahLabel),
          errorText: _surahError,
          dropdownMenuEntries: <DropdownMenuEntry<int>>[
            for (final surah in surahs)
              DropdownMenuEntry<int>(
                value: surah.id,
                label: l10n.goToSurahOption(surah.id, _surahName(surah)),
                labelWidget: Text(
                  l10n.goToSurahOption(surah.id, _surahName(surah)),
                  key: goToSurahEntryKey(surah.id),
                ),
              ),
          ],
          onSelected: (id) => setState(() {
            if (id != null) _surah = id;
            _surahError = null;
            _ayahError = null;
          }),
        ),
        const SizedBox(height: AppSpacing.lg),
        _numberField(
          key: goToAyahFieldKey,
          controller: _ayah,
          focusNode: _ayahFocus,
          label: l10n.goToAyahLabel,
          max: chosen?.ayahCount ?? 1,
          error: _ayahError,
          onChanged: () {
            if (_ayahError != null) setState(() => _ayahError = null);
          },
        ),
      ],
    };

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppSizes.readingMeasure,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                0,
                AppSpacing.gutter,
                AppSpacing.xl,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(l10n.readerGoTo, style: theme.textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.lg),
                  SegmentedButton<GoToMode>(
                    showSelectedIcon: false,
                    segments: <ButtonSegment<GoToMode>>[
                      ButtonSegment<GoToMode>(
                        value: GoToMode.page,
                        label: Text(l10n.goToByPage, key: goToByPageKey),
                      ),
                      ButtonSegment<GoToMode>(
                        value: GoToMode.surah,
                        label: Text(l10n.goToBySurah, key: goToBySurahKey),
                      ),
                    ],
                    selected: <GoToMode>{_mode},
                    onSelectionChanged: (selection) =>
                        setState(() => _mode = selection.single),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  ...fields,
                  const SizedBox(height: AppSpacing.xl),
                  FilledButton(
                    key: goToSubmitKey,
                    onPressed: _submit,
                    child: Text(l10n.goToSubmit),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
