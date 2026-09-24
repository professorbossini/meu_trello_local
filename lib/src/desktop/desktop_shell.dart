import 'dart:async';
import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'tray/dbus_menu.dart';
import 'tray/status_notifier_item.dart';

/// Glues the window and the tray icon together:
///
/// - a click on the tray icon shows the window, or hides it when it is
///   already in front;
/// - minimizing or closing the window tucks it away into the tray;
/// - "Sair" in the tray menu (or Ctrl+Q) actually quits.
///
/// When the desktop has no tray host, minimize and close keep their usual
/// behavior so the window can never become unreachable.
class DesktopShell with WindowListener {
  DesktopShell({required DBusClient client, required this.beforeQuit})
    : _client = client;

  static const title = 'Meu Trello Local';

  final DBusClient _client;

  /// Runs before the process exits, e.g. to flush unsaved changes.
  final Future<void> Function() beforeQuit;

  StatusNotifierItem? _tray;
  bool _hasTray = false;
  bool _visible = false;

  /// Sets up the window and the tray. With [startHidden] the app starts in
  /// the tray, which suits launching it on login.
  Future<void> start({bool startHidden = false}) async {
    await windowManager.ensureInitialized();

    final tray = StatusNotifierItem(
      client: _client,
      id: 'meu_trello_local',
      title: title,
      menu: _menu(),
      onActivate: toggle,
    );
    try {
      _hasTray = await tray.start();
      _tray = tray;
    } on Object catch (error) {
      debugPrint('Could not create the tray icon: $error');
    }

    windowManager.addListener(this);
    await windowManager.setPreventClose(_hasTray);

    const options = WindowOptions(
      title: title,
      size: Size(1200, 760),
      minimumSize: Size(640, 420),
      center: true,
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      if (startHidden && _hasTray) {
        await _setVisible(false);
      } else {
        await show();
      }
    });
  }

  Future<void> show() async {
    if (await windowManager.isMinimized()) await windowManager.restore();
    await windowManager.show();
    await windowManager.focus();
    await _setVisible(true);
  }

  Future<void> hide() async {
    if (!_hasTray) {
      await windowManager.minimize();
      return;
    }
    await windowManager.hide();
    await _setVisible(false);
  }

  /// Brings the window forward, or hides it when it already is in front.
  Future<void> toggle() async {
    final inFront =
        await windowManager.isVisible() &&
        !await windowManager.isMinimized() &&
        await windowManager.isFocused();
    await (inFront ? hide() : show());
  }

  Future<void> quit() async {
    windowManager.removeListener(this);
    await beforeQuit();
    await _tray?.dispose();
    await _client.close();
    exit(0);
  }

  @override
  void onWindowMinimize() {
    if (_hasTray) unawaited(hide());
  }

  @override
  void onWindowClose() {
    // Only reached when close is prevented, i.e. when there is a tray.
    unawaited(hide());
  }

  Future<void> _setVisible(bool visible) async {
    if (_visible == visible) return;
    _visible = visible;
    await _tray?.setMenu(_menu());
  }

  List<TrayMenuItem> _menu() => [
    _visible
        ? TrayMenuItem(label: 'Ocultar quadro', onClicked: hide)
        : TrayMenuItem(label: 'Mostrar quadro', onClicked: show),
    const TrayMenuItem.separator(),
    TrayMenuItem(label: 'Sair', onClicked: quit),
  ];
}
