import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:minhas_tarefas/src/board/board_controller.dart';
import 'package:minhas_tarefas/src/board/board_repository.dart';
import 'package:minhas_tarefas/src/board/models.dart';

void main() {
  group('JsonFileBoardRepository', () {
    late Directory dir;
    late File file;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('board_test');
      file = File('${dir.path}/nested/board.json');
    });

    tearDown(() => dir.delete(recursive: true));

    test('returns null when nothing was saved', () async {
      expect(await JsonFileBoardRepository(file).load(), isNull);
    });

    test('saves and loads a board, creating parent directories', () async {
      final repository = JsonFileBoardRepository(file);
      await repository.save(
        const Board(
          lists: [TaskList(id: 'l1', title: 'One')],
        ),
      );
      final loaded = await repository.load();
      expect(loaded!.lists.single.title, 'One');
      expect(File('${file.path}.tmp').existsSync(), isFalse);
    });

    test('moves a corrupt file aside instead of losing it', () async {
      await file.parent.create(recursive: true);
      await file.writeAsString('{not json');
      expect(await JsonFileBoardRepository(file).load(), isNull);
      expect(file.existsSync(), isFalse);
      final backups = file.parent.listSync().where(
        (e) => e.path.contains('board.json.corrupt-'),
      );
      expect(backups, hasLength(1));
    });
  });

  group('BoardController', () {
    test('seeds a default board on first launch', () async {
      final controller = BoardController(InMemoryBoardRepository());
      await controller.load();
      expect(controller.board.lists, hasLength(3));
    });

    test('debounces edits into a single save and flushes on demand', () async {
      final repository = InMemoryBoardRepository(const Board());
      final controller = BoardController(
        repository,
        saveDelay: const Duration(hours: 1),
      );
      await controller.load();

      controller
        ..addList('  Backlog  ')
        ..addList('Review');
      expect(repository.board!.lists, isEmpty);

      await controller.flush();
      expect(repository.board!.lists.map((l) => l.title), [
        'Backlog',
        'Review',
      ]);
    });

    test('notifies listeners on change only', () async {
      final controller = BoardController(InMemoryBoardRepository());
      await controller.load();
      var notifications = 0;
      controller.addListener(() => notifications++);

      controller.moveCard('missing', 'missing', 0);
      expect(notifications, 0);

      controller.addCard(controller.board.lists.first.id, 'Task');
      expect(notifications, 1);
    });
  });
}
