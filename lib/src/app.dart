import 'package:flutter/material.dart';

import 'board/board_controller.dart';
import 'ui/board_page.dart';

class MeuTrelloApp extends StatelessWidget {
  const MeuTrelloApp({super.key, required this.controller});

  final BoardController controller;

  static const _seed = Color(0xFF0079BF);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Meu Trello Local',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: ThemeData(colorSchemeSeed: _seed),
      darkTheme: ThemeData(colorSchemeSeed: _seed, brightness: Brightness.dark),
      home: BoardPage(controller: controller),
    );
  }
}
