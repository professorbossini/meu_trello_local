import 'package:flutter/material.dart';

import 'board/board_controller.dart';
import 'ui/board_page.dart';
import 'ui/drag_and_drop.dart';

class MeuTrelloApp extends StatefulWidget {
  const MeuTrelloApp({super.key, required this.controller});

  final BoardController controller;

  @override
  State<MeuTrelloApp> createState() => _MeuTrelloAppState();
}

class _MeuTrelloAppState extends State<MeuTrelloApp> {
  static const _seed = Color(0xFF0079BF);

  final _dragActivity = BoardDragActivity();

  @override
  void dispose() {
    _dragActivity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Meu Trello Local',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: ThemeData(colorSchemeSeed: _seed),
      darkTheme: ThemeData(colorSchemeSeed: _seed, brightness: Brightness.dark),
      // Above the navigator so drag feedback painted in its overlay can
      // reach the scope too.
      builder: (context, child) =>
          BoardDragScope(activity: _dragActivity, child: child!),
      home: BoardPage(controller: widget.controller),
    );
  }
}
