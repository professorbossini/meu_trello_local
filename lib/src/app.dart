import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'board/board_controller.dart';
import 'ui/board_page.dart';
import 'ui/drag_and_drop.dart';

class MinhasTarefasApp extends StatefulWidget {
  const MinhasTarefasApp({
    super.key,
    required this.controller,
    this.onHide,
    this.onQuit,
  });

  final BoardController controller;

  /// Hides the window into the tray (Ctrl+W).
  final VoidCallback? onHide;

  /// Quits the application (Ctrl+Q).
  final VoidCallback? onQuit;

  @override
  State<MinhasTarefasApp> createState() => _MinhasTarefasAppState();
}

class _MinhasTarefasAppState extends State<MinhasTarefasApp> {
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
      title: 'Minhas Tarefas',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: ThemeData(colorSchemeSeed: _seed),
      darkTheme: ThemeData(colorSchemeSeed: _seed, brightness: Brightness.dark),
      // Above the navigator so drag feedback painted in its overlay can
      // reach the scope too.
      builder: (context, child) => CallbackShortcuts(
        bindings: {
          if (widget.onHide case final onHide?)
            const SingleActivator(LogicalKeyboardKey.keyW, control: true):
                onHide,
          if (widget.onQuit case final onQuit?)
            const SingleActivator(LogicalKeyboardKey.keyQ, control: true):
                onQuit,
        },
        // Keeps the shortcuts working while no text field has focus.
        child: Focus(
          autofocus: true,
          child: BoardDragScope(activity: _dragActivity, child: child!),
        ),
      ),
      home: BoardPage(controller: widget.controller),
    );
  }
}
