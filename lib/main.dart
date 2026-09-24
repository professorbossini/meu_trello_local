import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'src/app.dart';
import 'src/board/board_controller.dart';
import 'src/board/board_repository.dart';
import 'src/desktop/autostart.dart';
import 'src/desktop/desktop_shell.dart';
import 'src/desktop/single_instance.dart';

/// Pass `--hidden` to start straight into the tray; the autostart entry
/// does so on login.
Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  final dbus = DBusClient.session();
  DesktopShell? shell;
  if (!await _claimSingleInstance(dbus, onActivate: () => shell?.show())) {
    await dbus.close();
    exit(0);
  }

  final dataDir = await getApplicationSupportDirectory();
  final controller = BoardController(
    JsonFileBoardRepository(File('${dataDir.path}/board.json')),
  );
  await controller.load();

  final autostart = Autostart.forCurrentUser(
    appId: 'io.github.professorbossini.minhas_tarefas',
    dataDir: dataDir,
  );
  try {
    await autostart.applyDefault();
  } on FileSystemException catch (error) {
    debugPrint('Could not set up autostart: $error');
  }

  shell = DesktopShell(
    client: dbus,
    autostart: autostart,
    beforeQuit: controller.flush,
  );
  await shell.start(startHidden: args.contains('--hidden'));

  runApp(
    MinhasTarefasApp(
      controller: controller,
      onHide: shell.hide,
      onQuit: shell.quit,
    ),
  );
}

Future<bool> _claimSingleInstance(
  DBusClient dbus, {
  required VoidCallback onActivate,
}) async {
  try {
    return await SingleInstance.claim(dbus, onActivate: onActivate);
  } on Object catch (error) {
    // Without a session bus there is nothing to coordinate with; just run.
    debugPrint('Single instance check unavailable: $error');
    return true;
  }
}
