import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minhas_tarefas/src/board/models.dart';
import 'package:minhas_tarefas/src/ui/list_column.dart';

import 'helpers.dart';

/// Four lists, plus the "add list" column, makes five board columns.
Board fourLists() => Board(
  lists: [
    for (final title in ['Backlog', 'A fazer', 'Fazendo', 'Concluído'])
      TaskList(
        id: title,
        title: title,
        cards: [
          TaskCard(id: '$title-1', title: 'Task', createdAt: DateTime(2026)),
        ],
      ),
  ],
);

Rect listRect(WidgetTester tester, String title) => tester.getRect(
  find.ancestor(of: find.text(title), matching: find.byType(ListColumn)),
);

void main() {
  group('BoardLayout', () {
    test('keeps every column on one row when they fit', () {
      final layout = BoardLayout.compute(1600, 5);
      expect(layout.columnsPerRow, 5);
      expect(layout.columnWidth, lessThanOrEqualTo(BoardLayout.maxColumnWidth));
    });

    test('wraps the columns that do not fit', () {
      final layout = BoardLayout.compute(900, 5);
      expect(layout.columnsPerRow, 3);
      expect(layout.columnWidth, closeTo((900 - 24) / 3, 0.01));
    });

    test('stacks one column per row on narrow windows', () {
      final layout = BoardLayout.compute(328, 5);
      expect(layout.stacked, isTrue);
      expect(layout.columnWidth, 328);
    });

    test('never asks for more columns than there are', () {
      expect(BoardLayout.compute(2000, 2).columnsPerRow, 2);
    });
  });

  testWidgets('a wide window shows all lists side by side', (tester) async {
    await pumpBoard(tester, fourLists(), size: const Size(1600, 900));

    final tops = [
      for (final title in ['Backlog', 'A fazer', 'Fazendo', 'Concluído'])
        listRect(tester, title).top,
    ];
    expect(tops.toSet(), hasLength(1));
  });

  testWidgets('a medium window wraps lists onto a new row', (tester) async {
    await pumpBoard(tester, fourLists(), size: const Size(932, 900));

    expect(listRect(tester, 'Fazendo').top, listRect(tester, 'Backlog').top);
    expect(
      listRect(tester, 'Concluído').top,
      greaterThan(listRect(tester, 'Backlog').bottom),
    );
    expect(
      listRect(tester, 'Concluído').left,
      listRect(tester, 'Backlog').left,
    );
  });

  testWidgets('a narrow window stacks lists one per row', (tester) async {
    await pumpBoard(tester, fourLists(), size: const Size(360, 640));

    final backlog = listRect(tester, 'Backlog');
    final todo = listRect(tester, 'A fazer');
    expect(todo.top, greaterThan(backlog.bottom));
    expect(todo.left, backlog.left);
    expect(backlog.width, 360 - 32);
    expect(tester.takeException(), isNull);
  });

  testWidgets('resizing the window reflows the lists', (tester) async {
    await pumpBoard(tester, fourLists(), size: const Size(1600, 900));
    expect(listRect(tester, 'A fazer').top, listRect(tester, 'Backlog').top);

    tester.view.physicalSize = const Size(360, 900);
    await tester.pumpAndSettle();

    expect(
      listRect(tester, 'A fazer').top,
      greaterThan(listRect(tester, 'Backlog').bottom),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('stacked lists can be reordered by dragging them down', (
    tester,
  ) async {
    final controller = await pumpBoard(
      tester,
      fourLists(),
      size: const Size(360, 900),
    );
    final target = listRect(tester, 'A fazer');

    await mouseDrag(
      tester,
      tester.getCenter(find.text('Backlog')),
      target.bottomCenter - const Offset(0, 8),
    );

    expect(controller.board.lists.map((l) => l.title).take(2), [
      'A fazer',
      'Backlog',
    ]);
  });

  testWidgets('the card dialog fits a narrow window', (tester) async {
    await pumpBoard(tester, sampleBoard(), size: const Size(360, 640));

    await tester.tap(find.text('Write tests'));
    await tester.pumpAndSettle();

    final surface = find
        .descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(Material),
        )
        .first;
    expect(tester.getRect(surface).width, lessThan(360));
    expect(tester.takeException(), isNull);
  });
}
