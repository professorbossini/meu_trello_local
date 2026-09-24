import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'src/app.dart';
import 'src/board/board_controller.dart';
import 'src/board/board_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final dataDir = await getApplicationSupportDirectory();
  final controller = BoardController(
    JsonFileBoardRepository(File('${dataDir.path}/board.json')),
  );
  await controller.load();

  runApp(MeuTrelloApp(controller: controller));
}
