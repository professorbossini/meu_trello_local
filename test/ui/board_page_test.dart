import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

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

  testWidgets('shows a hint in empty lists', (tester) async {
    await pumpBoard(tester, sampleBoard());

    expect(find.text('Nenhuma tarefa'), findsOneWidget);
  });

  testWidgets('deleting a card can be undone', (tester) async {
    final controller = await pumpBoard(tester, sampleBoard());

    await tester.tap(find.text('Write tests'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();

    expect(find.text('Write tests'), findsNothing);
    expect(find.text('Tarefa excluída'), findsOneWidget);

    await tester.tap(find.text('Desfazer'));
    await tester.pumpAndSettle();

    expect(controller.board.lists.first.cards.map((c) => c.title), [
      'Write tests',
      'Ship it',
    ]);
    expect(find.text('Write tests'), findsOneWidget);
  });
}
