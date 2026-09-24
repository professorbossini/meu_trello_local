import 'dart:async';
import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minhas_tarefas/src/desktop/tray/app_icon.dart';
import 'package:minhas_tarefas/src/desktop/tray/dbus_menu.dart';
import 'package:minhas_tarefas/src/desktop/tray/status_notifier_item.dart';

const watcherName = 'org.kde.StatusNotifierWatcher';

/// Stands in for the tray host (e.g. Plasma) on a private bus.
class FakeWatcher extends DBusObject {
  FakeWatcher() : super(DBusObjectPath('/StatusNotifierWatcher'));

  final registered = StreamController<String>.broadcast();

  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall methodCall) async {
    if (methodCall.name != 'RegisterStatusNotifierItem') {
      return DBusMethodErrorResponse.unknownMethod();
    }
    registered.add(methodCall.values.single.asString());
    return DBusMethodSuccessResponse();
  }
}

void main() {
  late DBusServer server;
  late DBusClient app;
  late DBusClient host;
  late FakeWatcher watcher;

  var activations = 0;
  var quits = 0;

  StatusNotifierItem newItem() => StatusNotifierItem(
    client: app,
    id: 'test-app',
    title: 'Test App',
    onActivate: () => activations++,
    menu: [
      TrayMenuItem(label: 'Show', onClicked: () {}),
      const TrayMenuItem.separator(),
      TrayMenuItem(label: 'Quit', onClicked: () => quits++),
    ],
  );

  Future<void> startWatcher() async {
    watcher = FakeWatcher();
    await host.registerObject(watcher);
    await host.requestName(watcherName);
  }

  setUp(() async {
    activations = 0;
    quits = 0;
    server = DBusServer();
    final address = await server.listenAddress(
      DBusAddress.unix(dir: Directory.systemTemp),
    );
    app = DBusClient(address);
    host = DBusClient(address);
  });

  tearDown(() async {
    await app.close();
    await host.close();
    await server.close();
  });

  test('reports no tray when there is no watcher', () async {
    expect(await newItem().start(), isFalse);
  });

  group('with a tray host', () {
    late StatusNotifierItem item;
    late DBusRemoteObject remoteItem;
    late DBusRemoteObject remoteMenu;

    setUp(() async {
      await startWatcher();
      item = newItem();
      final registration = watcher.registered.stream.first;
      expect(await item.start(), isTrue);
      expect(await registration, item.busName);

      remoteItem = DBusRemoteObject(
        host,
        name: item.busName,
        path: DBusObjectPath('/StatusNotifierItem'),
      );
      remoteMenu = DBusRemoteObject(
        host,
        name: item.busName,
        path: DBusObjectPath('/MenuBar'),
      );
    });

    test('a click on the icon activates the app', () async {
      await remoteItem.callMethod('org.kde.StatusNotifierItem', 'Activate', [
        const DBusInt32(10),
        const DBusInt32(20),
      ]);
      expect(activations, 1);
    });

    test('exposes the icon pixmaps and points to the menu', () async {
      final pixmaps = await remoteItem.getProperty(
        'org.kde.StatusNotifierItem',
        'IconPixmap',
      );
      final first = pixmaps.asArray().first.asStruct();
      expect(first[0].asInt32(), 16);
      expect(first[2].asByteArray(), hasLength(16 * 16 * 4));

      final menu = await remoteItem.getProperty(
        'org.kde.StatusNotifierItem',
        'Menu',
      );
      expect(menu.asObjectPath().value, '/MenuBar');

      final isMenu = await remoteItem.getProperty(
        'org.kde.StatusNotifierItem',
        'ItemIsMenu',
      );
      expect(isMenu.asBoolean(), isFalse);
    });

    test('serves the menu layout and dispatches clicks', () async {
      final layout = await remoteMenu.callMethod(
        'com.canonical.dbusmenu',
        'GetLayout',
        [const DBusInt32(0), const DBusInt32(-1), DBusArray.string(const [])],
      );
      final root = layout.values[1].asStruct();
      final children = root[2].asVariantArray().map((v) => v.asStruct());
      final properties = [
        for (final child in children) child[1].asStringVariantDict(),
      ];
      expect(properties[0]['label']!.asString(), 'Show');
      expect(properties[1]['type']!.asString(), 'separator');
      expect(properties[2]['label']!.asString(), 'Quit');

      await remoteMenu.callMethod('com.canonical.dbusmenu', 'Event', [
        const DBusInt32(3),
        const DBusString('clicked'),
        const DBusVariant(DBusString('')),
        const DBusUint32(0),
      ]);
      expect(quits, 1);
    });

    test('announces menu changes with a new revision', () async {
      final updates = DBusRemoteObjectSignalStream(
        object: remoteMenu,
        interface: 'com.canonical.dbusmenu',
        name: 'LayoutUpdated',
      );
      final update = updates.first;
      // Give the match rule time to reach the bus before emitting.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await item.setMenu([TrayMenuItem(label: 'Hide', onClicked: () {})]);
      expect((await update).values.first.asUint32(), 2);
    });

    test('registers again when the tray host restarts', () async {
      await host.releaseName(watcherName);
      final again = watcher.registered.stream.first;
      await host.requestName(watcherName);
      expect(await again, item.busName);
    });
  });

  test('checkable menu items expose their toggle state', () async {
    await startWatcher();
    final item = StatusNotifierItem(
      client: app,
      id: 'test-app',
      title: 'Test App',
      onActivate: () {},
      menu: [TrayMenuItem(label: 'Autostart', checked: true, onClicked: () {})],
    );
    await item.start();

    final properties =
        await DBusRemoteObject(
          host,
          name: item.busName,
          path: DBusObjectPath('/MenuBar'),
        ).callMethod('com.canonical.dbusmenu', 'GetGroupProperties', [
          DBusArray.int32([1]),
          DBusArray.string(const []),
        ]);
    final props = properties.values.first
        .asArray()
        .first
        .asStruct()[1]
        .asStringVariantDict();
    expect(props['toggle-type']!.asString(), 'checkmark');
    expect(props['toggle-state']!.asInt32(), 1);
  });

  test('app icon has transparent corners and an opaque body', () {
    const size = 32;
    final rgba = AppIcon.rgba(size);
    int alphaAt(int x, int y) => rgba[(y * size + x) * 4 + 3];
    expect(rgba, hasLength(size * size * 4));
    expect(alphaAt(0, 0), 0);
    expect(alphaAt(size - 1, size - 1), 0);
    expect(alphaAt(size ~/ 2, size - 3), 255);
  });
}
