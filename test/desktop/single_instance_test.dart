import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minhas_tarefas/src/desktop/single_instance.dart';

void main() {
  late DBusServer server;
  late DBusClient first;
  late DBusClient second;

  setUp(() async {
    server = DBusServer();
    final address = await server.listenAddress(
      DBusAddress.unix(dir: Directory.systemTemp),
    );
    first = DBusClient(address);
    second = DBusClient(address);
  });

  tearDown(() async {
    await first.close();
    await second.close();
    await server.close();
  });

  test('the first instance wins and is activated by later ones', () async {
    var activations = 0;

    expect(
      await SingleInstance.claim(first, onActivate: () => activations++),
      isTrue,
    );
    expect(
      await SingleInstance.claim(second, onActivate: () => fail('secondary')),
      isFalse,
    );
    expect(activations, 1);
  });

  test('a new instance takes over once the previous one exits', () async {
    await SingleInstance.claim(first, onActivate: () {});
    await first.close();

    expect(await SingleInstance.claim(second, onActivate: () {}), isTrue);
  });
}
