import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minhas_tarefas/src/ui/list_column.dart';

import 'helpers.dart';

void main() {
  test('columns shrink on narrow boards', () {
    expect(listColumnWidthFor(1400), 280);
    expect(listColumnWidthFor(700), 260);
    expect(listColumnWidthFor(360), 300);
    expect(listColumnWidthFor(300), 244);
  });

  testWidgets('a narrow window shows one list with the next peeking in', (
    tester,
  ) async {
    await pumpBoard(tester, sampleBoard(), size: const Size(360, 640));

    final first = tester.getRect(find.byType(ListColumn).first);
    expect(first.width, lessThan(360));
    expect(first.right + 12, lessThan(360), reason: 'next list peeks in');
    expect(tester.takeException(), isNull);
  });

  testWidgets('the card dialog fits a narrow window', (tester) async {
    await pumpBoard(tester, sampleBoard(), size: const Size(360, 640));

    await tester.tap(find.text('Write tests'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
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
