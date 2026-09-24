import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'models.dart';

/// Loads and stores the board.
abstract interface class BoardRepository {
  /// Returns the stored board, or `null` when nothing has been saved yet.
  Future<Board?> load();

  Future<void> save(Board board);
}

/// Stores the board as pretty-printed JSON in a single file.
///
/// Writes go to a sibling temporary file that is then renamed over the
/// target, so a crash mid-write never leaves a truncated board behind.
class JsonFileBoardRepository implements BoardRepository {
  JsonFileBoardRepository(this.file);

  final File file;

  static const _encoder = JsonEncoder.withIndent('  ');

  @override
  Future<Board?> load() async {
    if (!await file.exists()) return null;
    final contents = await file.readAsString();
    try {
      return Board.fromJson(jsonDecode(contents) as Map<String, dynamic>);
    } on Object catch (error) {
      // Keep the unreadable file around for manual recovery instead of
      // silently overwriting the user's data on the next save.
      final backup = File(
        '${file.path}.corrupt-${DateTime.now().millisecondsSinceEpoch}',
      );
      await file.rename(backup.path);
      debugPrint('Unreadable board moved to ${backup.path}: $error');
      return null;
    }
  }

  @override
  Future<void> save(Board board) async {
    await file.parent.create(recursive: true);
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(_encoder.convert(board.toJson()), flush: true);
    await temp.rename(file.path);
  }
}

/// Keeps the board in memory only; handy for tests.
class InMemoryBoardRepository implements BoardRepository {
  InMemoryBoardRepository([this.board]);

  Board? board;

  @override
  Future<Board?> load() async => board;

  @override
  Future<void> save(Board board) async => this.board = board;
}
