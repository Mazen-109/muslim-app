import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muslim/data/bookmark_repository.dart';
import 'package:muslim/data/user_database.dart';

/// A clock that stands still until advanced.
class _FakeClock {
  int _millis = 1000;

  DateTime call() => DateTime.fromMillisecondsSinceEpoch(_millis);

  void advance([int millis = 1]) => _millis += millis;
}

void main() {
  for (final kind in AyahMarkKind.values) {
    group('BookmarkRepository (${kind.name})', () {
      late UserDatabase database;
      late _FakeClock clock;
      late BookmarkRepository repository;

      setUp(() {
        database = UserDatabase.inMemory();
        clock = _FakeClock();
        repository = BookmarkRepository(database, kind, clock: clock.call);
      });

      tearDown(() async {
        await repository.dispose();
        database.close();
      });

      test('add, isSet and remove', () {
        expect(repository.isSet(2), isFalse);
        repository.add(2);
        expect(repository.isSet(2), isTrue);
        repository.remove(2);
        expect(repository.isSet(2), isFalse);
      });

      test('add stores created_at in Unix milliseconds', () {
        repository.add(7);
        expect(
          database.db
              .select('SELECT created_at FROM ${kind.table}')
              .single['created_at'],
          1000,
        );
      });

      test('adding twice keeps the original time', () {
        repository.add(7);
        clock.advance(500);
        repository.add(7);
        expect(repository.list().single.createdAt.millisecondsSinceEpoch, 1000);
      });

      test('toggle returns the new state', () {
        expect(repository.toggle(10), isTrue);
        expect(repository.isSet(10), isTrue);
        expect(repository.toggle(10), isFalse);
        expect(repository.isSet(10), isFalse);
      });

      test('list is newest first, then by ayah id', () {
        repository.add(300);
        clock.advance();
        repository.add(20);
        repository.add(5);
        clock.advance();
        repository.add(6236);

        expect(repository.list().map((m) => m.ayahId), <int>[6236, 5, 20, 300]);
        expect(
          repository.list().first,
          AyahMark(
            ayahId: 6236,
            createdAt: DateTime.fromMillisecondsSinceEpoch(1002),
          ),
        );
      });

      test('rejects ayah ids outside 1 to 6236', () {
        expect(() => repository.add(0), throwsRangeError);
        expect(() => repository.add(6237), throwsRangeError);
        expect(() => repository.toggle(0), throwsRangeError);
        expect(repository.list(), isEmpty);
        repository.add(1);
        repository.add(6236);
        expect(repository.list(), hasLength(2));
      });

      test('changes emits after every change and not for no-ops', () async {
        final events = <AyahMarkChange>[];
        final subscription = repository.changes.listen(events.add);
        addTearDown(subscription.cancel);

        repository.add(3);
        repository.add(3); // no-op
        repository.toggle(4);
        repository.remove(3);
        repository.remove(3); // no-op
        repository.toggle(4);
        await Future<void>.delayed(Duration.zero);

        expect(events, const <AyahMarkChange>[
          AyahMarkChange(ayahId: 3, isSet: true),
          AyahMarkChange(ayahId: 4, isSet: true),
          AyahMarkChange(ayahId: 3, isSet: false),
          AyahMarkChange(ayahId: 4, isSet: false),
        ]);
      });

      test('changes is a broadcast stream', () {
        expect(repository.changes.isBroadcast, isTrue);
      });
    });
  }

  test('bookmarks and memorisation marks are independent', () async {
    final database = UserDatabase.inMemory();
    final bookmarks = BookmarkRepository(database, AyahMarkKind.bookmark);
    final marks = BookmarkRepository(database, AyahMarkKind.memorisation);
    addTearDown(() async {
      await bookmarks.dispose();
      await marks.dispose();
      database.close();
    });

    bookmarks.add(1);
    expect(marks.isSet(1), isFalse);
    marks.add(2);
    expect(bookmarks.list().map((m) => m.ayahId), <int>[1]);
    expect(marks.list().map((m) => m.ayahId), <int>[2]);
  });

  test('providers build both repositories on the user database', () async {
    final database = UserDatabase.inMemory();
    addTearDown(database.close);
    final clock = _FakeClock();
    final container = ProviderContainer.test(
      overrides: [
        userDatabaseProvider.overrideWithValue(AsyncData(database)),
        clockProvider.overrideWithValue(clock.call),
      ],
    );

    final bookmarks = await container.read(bookmarkRepositoryProvider.future);
    final marks = await container.read(memorisationRepositoryProvider.future);
    expect(bookmarks.kind, AyahMarkKind.bookmark);
    expect(marks.kind, AyahMarkKind.memorisation);

    bookmarks.add(9);
    expect(
      bookmarks.list().single,
      AyahMark(ayahId: 9, createdAt: DateTime.fromMillisecondsSinceEpoch(1000)),
    );
  });
}
