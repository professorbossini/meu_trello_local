import 'package:flutter_test/flutter_test.dart';
import 'package:meu_trello_local/src/board/models.dart';

TaskCard card(String id) =>
    TaskCard(id: id, title: 'Card $id', createdAt: DateTime.utc(2026));

Board sampleBoard() => Board(
  lists: [
    TaskList(
      id: 'todo',
      title: 'To do',
      cards: [card('a'), card('b'), card('c')],
    ),
    TaskList(id: 'doing', title: 'Doing', cards: [card('d')]),
    const TaskList(id: 'done', title: 'Done'),
  ],
);

List<String> cardIds(Board board, String listId) =>
    board.lists[board.indexOfList(listId)].cards.map((c) => c.id).toList();

List<String> listIds(Board board) => board.lists.map((l) => l.id).toList();

void main() {
  group('lists', () {
    test('addList appends at the end', () {
      final board = sampleBoard().addList(const TaskList(id: 'x', title: 'X'));
      expect(listIds(board), ['todo', 'doing', 'done', 'x']);
    });

    test('removeList drops the list and its cards', () {
      final board = sampleBoard().removeList('todo');
      expect(listIds(board), ['doing', 'done']);
      expect(board.locateCard('a'), isNull);
    });

    test('moveList forward uses drop-before-slot semantics', () {
      expect(listIds(sampleBoard().moveList('todo', 2)), [
        'doing',
        'todo',
        'done',
      ]);
      expect(listIds(sampleBoard().moveList('todo', 3)), [
        'doing',
        'done',
        'todo',
      ]);
    });

    test('moveList backward', () {
      expect(listIds(sampleBoard().moveList('done', 0)), [
        'done',
        'todo',
        'doing',
      ]);
    });

    test('moveList onto its own slot is a no-op', () {
      expect(listIds(sampleBoard().moveList('doing', 1)), [
        'todo',
        'doing',
        'done',
      ]);
      expect(listIds(sampleBoard().moveList('doing', 2)), [
        'todo',
        'doing',
        'done',
      ]);
    });

    test('moveList clamps out-of-range indexes', () {
      expect(listIds(sampleBoard().moveList('todo', 99)), [
        'doing',
        'done',
        'todo',
      ]);
      expect(listIds(sampleBoard().moveList('done', -5)), [
        'done',
        'todo',
        'doing',
      ]);
    });
  });

  group('cards', () {
    test('addCard appends to the given list', () {
      final board = sampleBoard().addCard('done', card('z'));
      expect(cardIds(board, 'done'), ['z']);
    });

    test('updateCard edits in place', () {
      final board = sampleBoard().updateCard(
        'b',
        (c) => c.copyWith(title: 'New', description: 'Desc'),
      );
      final (list, index) = board.locateCard('b')!;
      expect(list.id, 'todo');
      expect(index, 1);
      expect(list.cards[index].title, 'New');
      expect(list.cards[index].description, 'Desc');
    });

    test('removeCard', () {
      expect(cardIds(sampleBoard().removeCard('b'), 'todo'), ['a', 'c']);
    });

    test('moveCard within the same list, forward and backward', () {
      expect(cardIds(sampleBoard().moveCard('a', 'todo', 2), 'todo'), [
        'b',
        'a',
        'c',
      ]);
      expect(cardIds(sampleBoard().moveCard('a', 'todo', 3), 'todo'), [
        'b',
        'c',
        'a',
      ]);
      expect(cardIds(sampleBoard().moveCard('c', 'todo', 0), 'todo'), [
        'c',
        'a',
        'b',
      ]);
    });

    test('moveCard across lists inserts at the requested slot', () {
      final board = sampleBoard().moveCard('b', 'doing', 0);
      expect(cardIds(board, 'todo'), ['a', 'c']);
      expect(cardIds(board, 'doing'), ['b', 'd']);
    });

    test('moveCard into an empty list', () {
      final board = sampleBoard().moveCard('d', 'done', 0);
      expect(cardIds(board, 'doing'), isEmpty);
      expect(cardIds(board, 'done'), ['d']);
    });

    test('moveCard with unknown ids leaves the board untouched', () {
      final board = sampleBoard();
      expect(identical(board.moveCard('nope', 'done', 0), board), isTrue);
      expect(identical(board.moveCard('a', 'nope', 0), board), isTrue);
    });
  });

  test('JSON round-trip preserves the board', () {
    final original = sampleBoard().updateCard(
      'a',
      (c) => c.copyWith(description: 'multi\nline'),
    );
    final restored = Board.fromJson(original.toJson());
    expect(listIds(restored), listIds(original));
    expect(cardIds(restored, 'todo'), ['a', 'b', 'c']);
    expect(restored.locateCard('a')!.$1.cards.first.description, 'multi\nline');
    expect(
      restored.locateCard('a')!.$1.cards.first.createdAt,
      DateTime.utc(2026),
    );
  });
}
