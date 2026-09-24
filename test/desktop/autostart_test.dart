import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:minhas_tarefas/src/desktop/autostart.dart';

void main() {
  late Directory dir;
  late Autostart autostart;

  Autostart create({String executable = '/opt/minhas tarefas/app'}) =>
      Autostart(
        entry: File('${dir.path}/config/autostart/app.desktop'),
        marker: File('${dir.path}/data/autostart-configured'),
        executable: executable,
      );

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('autostart_test');
    autostart = create();
  });

  tearDown(() => dir.delete(recursive: true));

  test('is enabled by default on the first launch', () async {
    await autostart.applyDefault();

    expect(autostart.enabled, isTrue);
    expect(
      autostart.entry.readAsStringSync(),
      contains('Exec="/opt/minhas tarefas/app" --hidden'),
    );
  });

  test('stays off once the user turned it off', () async {
    await autostart.applyDefault();
    await autostart.setEnabled(false);

    await create().applyDefault();

    expect(autostart.enabled, isFalse);
  });

  test('follows the executable to its new location', () async {
    await autostart.applyDefault();

    await create(executable: '/usr/local/bin/app').applyDefault();

    expect(
      autostart.entry.readAsStringSync(),
      contains('Exec="/usr/local/bin/app" --hidden'),
    );
  });

  test('escapes special characters in the executable path', () {
    expect(
      create(executable: r'/a"b$c').desktopEntry,
      contains(r'Exec="/a\"b\$c" --hidden'),
    );
  });
}
