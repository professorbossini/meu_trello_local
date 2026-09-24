import 'package:flutter/foundation.dart';

/// A single task on the board.
@immutable
class TaskCard {
  const TaskCard({
    required this.id,
    required this.title,
    this.description = '',
    required this.createdAt,
  });

  factory TaskCard.fromJson(Map<String, dynamic> json) => TaskCard(
    id: json['id'] as String,
    title: json['title'] as String,
    description: json['description'] as String? ?? '',
    createdAt: DateTime.parse(json['createdAt'] as String),
  );

  final String id;
  final String title;
  final String description;
  final DateTime createdAt;

  TaskCard copyWith({String? title, String? description}) => TaskCard(
    id: id,
    title: title ?? this.title,
    description: description ?? this.description,
    createdAt: createdAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };
}

/// A column of the board holding an ordered queue of cards.
@immutable
class TaskList {
  const TaskList({
    required this.id,
    required this.title,
    this.cards = const [],
  });

  factory TaskList.fromJson(Map<String, dynamic> json) => TaskList(
    id: json['id'] as String,
    title: json['title'] as String,
    cards: [
      for (final card in json['cards'] as List<dynamic>? ?? const [])
        TaskCard.fromJson(card as Map<String, dynamic>),
    ],
  );

  final String id;
  final String title;
  final List<TaskCard> cards;

  TaskList copyWith({String? title, List<TaskCard>? cards}) =>
      TaskList(id: id, title: title ?? this.title, cards: cards ?? this.cards);

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'cards': [for (final card in cards) card.toJson()],
  };
}

/// The whole board. Every operation returns a new [Board], leaving the
/// receiver untouched, which keeps undo-free state handling simple and makes
/// the logic trivial to unit test.
@immutable
class Board {
  const Board({this.lists = const []});

  factory Board.fromJson(Map<String, dynamic> json) => Board(
    lists: [
      for (final list in json['lists'] as List<dynamic>? ?? const [])
        TaskList.fromJson(list as Map<String, dynamic>),
    ],
  );

  /// Current on-disk schema version, bumped on breaking format changes.
  static const schemaVersion = 1;

  final List<TaskList> lists;

  Map<String, dynamic> toJson() => {
    'version': schemaVersion,
    'lists': [for (final list in lists) list.toJson()],
  };

  int indexOfList(String listId) => lists.indexWhere((l) => l.id == listId);

  /// Returns the list holding [cardId] and the card's index inside it.
  (TaskList, int)? locateCard(String cardId) {
    for (final list in lists) {
      final index = list.cards.indexWhere((c) => c.id == cardId);
      if (index != -1) return (list, index);
    }
    return null;
  }

  Board addList(TaskList list) => Board(lists: [...lists, list]);

  /// Puts [list] back at [index], e.g. to undo its removal.
  Board insertList(int index, TaskList list) =>
      Board(lists: [...lists]..insert(index.clamp(0, lists.length), list));

  Board updateList(String listId, TaskList Function(TaskList) update) =>
      Board(lists: [for (final l in lists) l.id == listId ? update(l) : l]);

  Board removeList(String listId) => Board(
    lists: [
      for (final l in lists)
        if (l.id != listId) l,
    ],
  );

  /// Moves a list so that it lands in the slot [toIndex], expressed in terms
  /// of the current layout (i.e. "drop before the list currently at
  /// [toIndex]"). Indexes past the end append the list.
  Board moveList(String listId, int toIndex) {
    final from = indexOfList(listId);
    if (from == -1) return this;
    final target = _adjustedTarget(from, toIndex, lists.length);
    final reordered = [...lists]..removeAt(from);
    reordered.insert(target, lists[from]);
    return Board(lists: reordered);
  }

  Board addCard(String listId, TaskCard card) =>
      updateList(listId, (l) => l.copyWith(cards: [...l.cards, card]));

  /// Puts [card] back into [listId] at [index], e.g. to undo its removal.
  Board insertCard(String listId, int index, TaskCard card) => updateList(
    listId,
    (l) => l.copyWith(
      cards: [...l.cards]..insert(index.clamp(0, l.cards.length), card),
    ),
  );

  Board updateCard(String cardId, TaskCard Function(TaskCard) update) {
    final location = locateCard(cardId);
    if (location == null) return this;
    final (list, index) = location;
    final cards = [...list.cards];
    cards[index] = update(cards[index]);
    return updateList(list.id, (l) => l.copyWith(cards: cards));
  }

  Board removeCard(String cardId) {
    final location = locateCard(cardId);
    if (location == null) return this;
    final (list, index) = location;
    return updateList(
      list.id,
      (l) => l.copyWith(cards: [...l.cards]..removeAt(index)),
    );
  }

  /// Moves a card into [toListId] at slot [toIndex], expressed in terms of
  /// the destination list's current layout, like [moveList].
  Board moveCard(String cardId, String toListId, int toIndex) {
    final location = locateCard(cardId);
    final destination = indexOfList(toListId);
    if (location == null || destination == -1) return this;
    final (source, from) = location;
    final card = source.cards[from];

    if (source.id == toListId) {
      final target = _adjustedTarget(from, toIndex, source.cards.length);
      final cards = [...source.cards]..removeAt(from);
      cards.insert(target, card);
      return updateList(source.id, (l) => l.copyWith(cards: cards));
    }

    final destinationCards = lists[destination].cards;
    final target = toIndex.clamp(0, destinationCards.length);
    return removeCard(cardId).updateList(
      toListId,
      (l) => l.copyWith(cards: [...l.cards]..insert(target, card)),
    );
  }

  /// Converts a "drop before slot" index into an insertion index that is
  /// valid after the moved element has been removed from the same sequence.
  static int _adjustedTarget(int from, int toIndex, int length) {
    final slot = toIndex.clamp(0, length);
    return slot > from ? slot - 1 : slot;
  }
}
