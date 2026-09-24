import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'board_repository.dart';
import 'models.dart';

/// Owns the current [Board], applies user edits and persists them.
///
/// Saves are debounced so that bursts of edits (typing, dragging) turn into a
/// single write, and are serialized so two writes never race each other.
class BoardController extends ChangeNotifier {
  BoardController(
    this._repository, {
    this.saveDelay = const Duration(milliseconds: 400),
  });

  final BoardRepository _repository;
  final Duration saveDelay;
  final _uuid = const Uuid();

  Board _board = const Board();
  Board get board => _board;

  Timer? _saveTimer;
  Future<void> _pendingSave = Future.value();

  /// The board shown on first launch.
  static Board initialBoard(String Function() newId) => Board(
    lists: [
      TaskList(id: newId(), title: 'A fazer'),
      TaskList(id: newId(), title: 'Fazendo'),
      TaskList(id: newId(), title: 'Concluído'),
    ],
  );

  Future<void> load() async {
    _board = await _repository.load() ?? initialBoard(_uuid.v4);
    notifyListeners();
  }

  void addList(String title) =>
      _apply(_board.addList(TaskList(id: _uuid.v4(), title: title.trim())));

  void renameList(String listId, String title) =>
      _apply(_board.updateList(listId, (l) => l.copyWith(title: title.trim())));

  /// Removes a list and returns a callback that puts it back.
  VoidCallback removeList(String listId) {
    final index = _board.indexOfList(listId);
    if (index == -1) return () {};
    final list = _board.lists[index];
    _apply(_board.removeList(listId));
    return () => _apply(_board.insertList(index, list));
  }

  void moveList(String listId, int toIndex) =>
      _apply(_board.moveList(listId, toIndex));

  void addCard(String listId, String title) => _apply(
    _board.addCard(
      listId,
      TaskCard(id: _uuid.v4(), title: title.trim(), createdAt: DateTime.now()),
    ),
  );

  void updateCard(String cardId, {String? title, String? description}) =>
      _apply(
        _board.updateCard(
          cardId,
          (c) => c.copyWith(title: title?.trim(), description: description),
        ),
      );

  /// Removes a card and returns a callback that puts it back where it was,
  /// as long as its list still exists.
  VoidCallback removeCard(String cardId) {
    final location = _board.locateCard(cardId);
    if (location == null) return () {};
    final (list, index) = location;
    final card = list.cards[index];
    _apply(_board.removeCard(cardId));
    return () => _apply(_board.insertCard(list.id, index, card));
  }

  void moveCard(String cardId, String toListId, int toIndex) =>
      _apply(_board.moveCard(cardId, toListId, toIndex));

  /// Writes any pending change right away, e.g. before the app quits.
  Future<void> flush() {
    if (_saveTimer?.isActive ?? false) {
      _saveTimer!.cancel();
      _enqueueSave();
    }
    return _pendingSave;
  }

  void _apply(Board next) {
    if (identical(next, _board)) return;
    _board = next;
    notifyListeners();
    _saveTimer?.cancel();
    _saveTimer = Timer(saveDelay, _enqueueSave);
  }

  void _enqueueSave() {
    final snapshot = _board;
    _pendingSave = _pendingSave
        .then((_) => _repository.save(snapshot))
        .catchError((Object e) => debugPrint('Failed to save board: $e'));
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }
}
