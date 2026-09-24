import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minhas_tarefas/src/app.dart';
import 'package:minhas_tarefas/src/board/board_controller.dart';
import 'package:minhas_tarefas/src/board/board_repository.dart';
import 'package:minhas_tarefas/src/board/models.dart';

/// Pumps the whole app on a window of [size] logical pixels, backed by
/// [board].
Future<BoardController> pumpBoard(
  WidgetTester tester,
  Board board, {
  Size size = const Size(1400, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final controller = BoardController(
    InMemoryBoardRepository(board),
    saveDelay: Duration.zero,
  );
  await controller.load();
  await tester.pumpWidget(MinhasTarefasApp(controller: controller));
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

/// Drags from [from] to [to] with a mouse, moving in small steps like a real
/// pointer so every drag target along the way gets enter/move events.
Future<void> mouseDrag(WidgetTester tester, Offset from, Offset to) async {
  final gesture = await tester.startGesture(
    from,
    kind: PointerDeviceKind.mouse,
  );
  const steps = 10;
  for (var i = 1; i <= steps; i++) {
    await gesture.moveTo(Offset.lerp(from, to, i / steps)!);
    await tester.pump(const Duration(milliseconds: 16));
  }
  await gesture.up();
  await tester.pumpAndSettle();
}
