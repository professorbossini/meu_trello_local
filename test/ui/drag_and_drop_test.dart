import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minhas_tarefas/src/board/board_controller.dart';

import 'helpers.dart';

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

List<String> titlesOf(BoardController controller, int listIndex) =>
    controller.board.lists[listIndex].cards.map((c) => c.title).toList();

void main() {
  testWidgets('reorders a card below its neighbour', (tester) async {
    final controller = await pumpBoard(tester, sampleBoard());
    final target = tester.getRect(find.text('Ship it'));

    await mouseDrag(
      tester,
      tester.getCenter(find.text('Write tests')),
      target.bottomCenter + const Offset(0, 4),
    );

    expect(titlesOf(controller, 0), ['Ship it', 'Write tests']);
  });

  testWidgets('moves a card into an empty list', (tester) async {
    final controller = await pumpBoard(tester, sampleBoard());

    await mouseDrag(
      tester,
      tester.getCenter(find.text('Write tests')),
      tester.getCenter(find.text('Concluído')),
    );

    expect(titlesOf(controller, 0), ['Ship it']);
    expect(titlesOf(controller, 1), ['Write tests']);
  });

  testWidgets('moves a list before another one', (tester) async {
    final controller = await pumpBoard(tester, sampleBoard());
    final firstList = tester.getRect(find.text('A fazer'));

    await mouseDrag(
      tester,
      tester.getCenter(find.text('Concluído')),
      firstList.centerLeft,
    );

    expect(controller.board.lists.map((l) => l.title), [
      'Concluído',
      'A fazer',
    ]);
  });

  testWidgets('a slightly shaky click still opens the card', (tester) async {
    await pumpBoard(tester, sampleBoard());
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Write tests')),
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveBy(const Offset(2, 1));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
  });
}
