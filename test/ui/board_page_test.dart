import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_trello_local/src/app.dart';
import 'package:meu_trello_local/src/board/board_controller.dart';
import 'package:meu_trello_local/src/board/board_repository.dart';
import 'package:meu_trello_local/src/board/models.dart';

Future<BoardController> pumpBoard(WidgetTester tester, Board board) async {
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final controller = BoardController(
    InMemoryBoardRepository(board),
    saveDelay: Duration.zero,
  );
  await controller.load();
  await tester.pumpWidget(MeuTrelloApp(controller: controller));
  return controller;
}

Board sampleBoard() => Board(
  lists: [
    TaskList(
      id: 'todo',
      title: 'A fazer',
      cards: [
        TaskCard(id: 'a', title: 'Write tests', createdAt: DateTime(2026)),
        TaskCard(
          id: 'b',
          title: 'Ship it',
          description: 'Tag a release',
          createdAt: DateTime(2026),
        ),
      ],
    ),
    const TaskList(id: 'done', title: 'Concluído'),
  ],
);

void main() {
  testWidgets('renders lists and cards', (tester) async {
    await pumpBoard(tester, sampleBoard());

    expect(find.text('A fazer'), findsOneWidget);
    expect(find.text('Concluído'), findsOneWidget);
    expect(find.text('Write tests'), findsOneWidget);
    expect(find.text('Tag a release'), findsOneWidget);
  });

  testWidgets('adds a card through the inline composer', (tester) async {
    final controller = await pumpBoard(tester, sampleBoard());

    await tester.tap(find.text('Adicionar tarefa').last);
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Brand new');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    // Also lets the debounced save timer fire.
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.text('Brand new'), findsOneWidget);
    expect(controller.board.lists.last.cards.single.title, 'Brand new');
  });

  testWidgets('edits a card through the details dialog', (tester) async {
    final controller = await pumpBoard(tester, sampleBoard());

    await tester.tap(find.text('Write tests'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Título'), 'Renamed');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(find.text('Renamed'), findsOneWidget);
    expect(controller.board.lists.first.cards.first.title, 'Renamed');
  });

  testWidgets('adds a new list', (tester) async {
    final controller = await pumpBoard(tester, sampleBoard());

    await tester.tap(find.text('Adicionar outra lista'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Review');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    // Also lets the debounced save timer fire.
    await tester.pump(const Duration(milliseconds: 1));

    expect(controller.board.lists.map((l) => l.title), [
      'A fazer',
      'Concluído',
      'Review',
    ]);
  });
}
