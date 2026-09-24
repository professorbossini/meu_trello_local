import 'dart:async';
import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:flutter/foundation.dart';

import 'app_icon.dart';
import 'dbus_menu.dart';

/// A system tray icon implemented directly on top of the
/// [StatusNotifierItem](https://www.freedesktop.org/wiki/Specifications/StatusNotifierItem/)
/// D-Bus protocol.
///
/// Plugins built on libappindicator only ever open a menu on click. Talking
/// to the tray host ourselves gives a real single-click [onActivate], while
/// a right click still shows the [DBusMenu] context menu.
class StatusNotifierItem {
  StatusNotifierItem({
    required DBusClient client,
    required this.id,
    required this.title,
    required List<TrayMenuItem> menu,
    required this.onActivate,
  }) : _client = client,
       _menu = DBusMenu(_menuPath, menu);

  static const _watcherName = 'org.kde.StatusNotifierWatcher';
  static final _itemPath = DBusObjectPath('/StatusNotifierItem');
  static final _menuPath = DBusObjectPath('/MenuBar');
  static const _iconSizes = [16, 22, 24, 32, 48, 64];

  final DBusClient _client;
  final DBusMenu _menu;

  /// Stable application identifier reported to the host.
  final String id;

  /// Human readable name, used for the tooltip.
  final String title;

  /// Called on a primary (usually left) click on the icon.
  final VoidCallback onActivate;

  String? _activationToken;

  /// Returns, and forgets, the activation token the tray host sent along
  /// with the latest click, if any. Passing it on when raising the window
  /// lets the window manager know the user asked for it.
  String? takeActivationToken() {
    final token = _activationToken;
    _activationToken = null;
    return token;
  }

  late final _item = _ItemObject(this);
  StreamSubscription<DBusNameOwnerChangedEvent>? _watcherRestarts;

  /// Bus name the item is published under, as the specification requires.
  String get busName => 'org.kde.StatusNotifierItem-$pid-1';

  /// Publishes the icon. Returns `false` when no tray host is running, in
  /// which case the app should not hide itself into a tray nobody shows.
  Future<bool> start() async {
    await _client.registerObject(_item);
    await _client.registerObject(_menu);
    await _client.requestName(busName);

    // Re-register whenever the host comes back, e.g. after plasmashell is
    // restarted, so the icon does not silently disappear.
    _watcherRestarts = _client.nameOwnerChanged
        .where((e) => e.name == _watcherName && e.newOwner != null)
        .listen((_) => _register());

    return _register();
  }

  Future<bool> _register() async {
    try {
      await _client.callMethod(
        destination: _watcherName,
        path: DBusObjectPath('/StatusNotifierWatcher'),
        interface: _watcherName,
        name: 'RegisterStatusNotifierItem',
        values: [DBusString(busName)],
        replySignature: DBusSignature.empty,
      );
      return true;
    } on DBusMethodResponseException catch (error) {
      debugPrint('No system tray available: $error');
      return false;
    }
  }

  Future<void> setMenu(List<TrayMenuItem> items) => _menu.setItems(items);

  Future<void> dispose() async {
    await _watcherRestarts?.cancel();
    await _client.releaseName(busName);
    await _client.unregisterObject(_menu);
    await _client.unregisterObject(_item);
  }
}

/// The `org.kde.StatusNotifierItem` object exported on the bus.
class _ItemObject extends DBusObject {
  _ItemObject(this._owner) : super(StatusNotifierItem._itemPath);

  static const interface = 'org.kde.StatusNotifierItem';

  final StatusNotifierItem _owner;

  late final Map<String, DBusValue> _properties = () {
    final pixmaps = DBusArray(DBusSignature('(iiay)'), [
      for (final size in StatusNotifierItem._iconSizes)
        DBusStruct([
          DBusInt32(size),
          DBusInt32(size),
          DBusArray.byte(AppIcon.argb(size)),
        ]),
    ]);
    final noPixmap = DBusArray(DBusSignature('(iiay)'));
    return <String, DBusValue>{
      'Category': const DBusString('ApplicationStatus'),
      'Id': DBusString(_owner.id),
      'Title': DBusString(_owner.title),
      'Status': const DBusString('Active'),
      'WindowId': const DBusInt32(0),
      'IconName': const DBusString(''),
      'IconPixmap': pixmaps,
      'OverlayIconName': const DBusString(''),
      'OverlayIconPixmap': noPixmap,
      'AttentionIconName': const DBusString(''),
      'AttentionIconPixmap': noPixmap,
      'AttentionMovieName': const DBusString(''),
      'ToolTip': DBusStruct([
        const DBusString(''),
        pixmaps,
        DBusString(_owner.title),
        const DBusString('Clique para mostrar ou ocultar'),
      ]),
      'ItemIsMenu': const DBusBoolean(false),
      'Menu': StatusNotifierItem._menuPath,
    };
  }();

  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall methodCall) async {
    if (methodCall.interface != interface) {
      return DBusMethodErrorResponse.unknownInterface();
    }
    switch (methodCall.name) {
      case 'Activate':
        _owner.onActivate();
        return DBusMethodSuccessResponse();
      case 'ProvideXdgActivationToken':
        // Sent by Plasma right before Activate.
        _owner._activationToken = methodCall.values.first.asString();
        return DBusMethodSuccessResponse();
      case 'SecondaryActivate' || 'Scroll':
        return DBusMethodSuccessResponse();
      case 'ContextMenu':
        // Hosts render the exported Menu themselves; nothing to do here.
        return DBusMethodSuccessResponse();
      default:
        return DBusMethodErrorResponse.unknownMethod();
    }
  }

  @override
  Future<DBusMethodResponse> getProperty(String interface, String name) async {
    final value = interface == _ItemObject.interface ? _properties[name] : null;
    return value == null
        ? DBusMethodErrorResponse.unknownProperty()
        : DBusGetPropertyResponse(value);
  }

  @override
  Future<DBusMethodResponse> getAllProperties(String interface) async =>
      DBusGetAllPropertiesResponse(
        interface == _ItemObject.interface ? _properties : const {},
      );

  @override
  List<DBusIntrospectInterface> introspect() {
    DBusIntrospectMethod method(String name, List<String> args) =>
        DBusIntrospectMethod(
          name,
          args: [
            for (final type in args)
              DBusIntrospectArgument(
                DBusSignature(type),
                DBusArgumentDirection.in_,
              ),
          ],
        );
    return [
      DBusIntrospectInterface(
        interface,
        methods: [
          method('ContextMenu', ['i', 'i']),
          method('Activate', ['i', 'i']),
          method('SecondaryActivate', ['i', 'i']),
          method('Scroll', ['i', 's']),
          method('ProvideXdgActivationToken', ['s']),
        ],
        signals: [
          for (final name in [
            'NewTitle',
            'NewIcon',
            'NewAttentionIcon',
            'NewOverlayIcon',
            'NewToolTip',
          ])
            DBusIntrospectSignal(name),
          DBusIntrospectSignal(
            'NewStatus',
            args: [
              DBusIntrospectArgument(
                DBusSignature('s'),
                DBusArgumentDirection.out,
              ),
            ],
          ),
        ],
        properties: [
          for (final MapEntry(:key, :value) in _properties.entries)
            DBusIntrospectProperty(
              key,
              value.signature,
              access: DBusPropertyAccess.read,
            ),
        ],
      ),
    ];
  }
}
