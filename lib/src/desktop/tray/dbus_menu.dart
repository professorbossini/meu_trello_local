import 'package:dbus/dbus.dart';
import 'package:flutter/foundation.dart';

/// An entry of the tray context menu.
@immutable
class TrayMenuItem {
  const TrayMenuItem({required this.label, required this.onClicked})
    : separator = false;

  const TrayMenuItem.separator()
    : label = '',
      onClicked = null,
      separator = true;

  final String label;
  final VoidCallback? onClicked;
  final bool separator;
}

/// Exports a flat menu over D-Bus using the `com.canonical.dbusmenu`
/// protocol, which is how StatusNotifierItem hosts (KDE Plasma, the GNOME
/// AppIndicator extension, waybar, ...) render a tray icon's context menu.
///
/// Item ids are their index in [items] plus one; id 0 is the root.
class DBusMenu extends DBusObject {
  DBusMenu(super.path, List<TrayMenuItem> items) : _items = items;

  static const interface = 'com.canonical.dbusmenu';

  List<TrayMenuItem> _items;
  int _revision = 1;

  /// Replaces the menu entries and tells the host to fetch them again.
  Future<void> setItems(List<TrayMenuItem> items) async {
    _items = items;
    _revision++;
    await emitSignal(interface, 'LayoutUpdated', [
      DBusUint32(_revision),
      const DBusInt32(0),
    ]);
  }

  Map<String, DBusValue> _properties(int id) {
    if (id == 0) return {'children-display': const DBusString('submenu')};
    final item = _items[id - 1];
    if (item.separator) return {'type': const DBusString('separator')};
    return {
      'label': DBusString(item.label),
      'enabled': const DBusBoolean(true),
      'visible': const DBusBoolean(true),
    };
  }

  bool _exists(int id) => id >= 0 && id <= _items.length;

  DBusStruct _layout(int id) => DBusStruct([
    DBusInt32(id),
    DBusDict.stringVariant(_properties(id)),
    DBusArray(DBusSignature('v'), [
      if (id == 0)
        for (var child = 1; child <= _items.length; child++)
          DBusVariant(_layout(child)),
    ]),
  ]);

  void _handleEvent(int id, String eventId) {
    if (eventId != 'clicked' || id == 0 || !_exists(id)) return;
    _items[id - 1].onClicked?.call();
  }

  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall methodCall) async {
    if (methodCall.interface != interface) {
      return DBusMethodErrorResponse.unknownInterface();
    }
    final args = methodCall.values;
    switch (methodCall.name) {
      case 'GetLayout':
        final parent = args[0].asInt32();
        if (!_exists(parent)) return DBusMethodErrorResponse.invalidArgs();
        return DBusMethodSuccessResponse([
          DBusUint32(_revision),
          _layout(parent),
        ]);
      case 'GetGroupProperties':
        final ids = args[0].asInt32Array().where(_exists);
        return DBusMethodSuccessResponse([
          DBusArray(DBusSignature('(ia{sv})'), [
            for (final id in ids)
              DBusStruct([
                DBusInt32(id),
                DBusDict.stringVariant(_properties(id)),
              ]),
          ]),
        ]);
      case 'GetProperty':
        final id = args[0].asInt32();
        final value = _exists(id) ? _properties(id)[args[1].asString()] : null;
        if (value == null) return DBusMethodErrorResponse.invalidArgs();
        return DBusMethodSuccessResponse([DBusVariant(value)]);
      case 'Event':
        _handleEvent(args[0].asInt32(), args[1].asString());
        return DBusMethodSuccessResponse();
      case 'EventGroup':
        for (final event in args[0].asArray()) {
          final fields = event.asStruct();
          _handleEvent(fields[0].asInt32(), fields[1].asString());
        }
        return DBusMethodSuccessResponse([DBusArray.int32(const [])]);
      case 'AboutToShow':
        return DBusMethodSuccessResponse([const DBusBoolean(false)]);
      case 'AboutToShowGroup':
        return DBusMethodSuccessResponse([
          DBusArray.int32(const []),
          DBusArray.int32(const []),
        ]);
      default:
        return DBusMethodErrorResponse.unknownMethod();
    }
  }

  static final _menuProperties = <String, DBusValue>{
    'Version': const DBusUint32(3),
    'TextDirection': const DBusString('ltr'),
    'Status': const DBusString('normal'),
    'IconThemePath': DBusArray.string(const []),
  };

  @override
  Future<DBusMethodResponse> getProperty(String interface, String name) async {
    final value = interface == DBusMenu.interface
        ? _menuProperties[name]
        : null;
    return value == null
        ? DBusMethodErrorResponse.unknownProperty()
        : DBusGetPropertyResponse(value);
  }

  @override
  Future<DBusMethodResponse> getAllProperties(String interface) async =>
      DBusGetAllPropertiesResponse(
        interface == DBusMenu.interface ? _menuProperties : const {},
      );

  @override
  List<DBusIntrospectInterface> introspect() => [
    DBusIntrospectInterface(
      interface,
      methods: [
        _method('GetLayout', ['i', 'i', 'as'], ['u', '(ia{sv}av)']),
        _method('GetGroupProperties', ['ai', 'as'], ['a(ia{sv})']),
        _method('GetProperty', ['i', 's'], ['v']),
        _method('Event', ['i', 's', 'v', 'u'], []),
        _method('EventGroup', ['a(isvu)'], ['ai']),
        _method('AboutToShow', ['i'], ['b']),
        _method('AboutToShowGroup', ['ai'], ['ai', 'ai']),
      ],
      signals: [
        _signal('ItemsPropertiesUpdated', ['a(ia{sv})', 'a(ias)']),
        _signal('LayoutUpdated', ['u', 'i']),
        _signal('ItemActivationRequested', ['i', 'u']),
      ],
      properties: [
        for (final MapEntry(:key, :value) in _menuProperties.entries)
          DBusIntrospectProperty(
            key,
            value.signature,
            access: DBusPropertyAccess.read,
          ),
      ],
    ),
  ];
}

DBusIntrospectMethod _method(
  String name,
  List<String> inputs,
  List<String> outputs,
) => DBusIntrospectMethod(
  name,
  args: [
    for (final type in inputs)
      DBusIntrospectArgument(DBusSignature(type), DBusArgumentDirection.in_),
    for (final type in outputs)
      DBusIntrospectArgument(DBusSignature(type), DBusArgumentDirection.out),
  ],
);

DBusIntrospectSignal _signal(String name, List<String> args) =>
    DBusIntrospectSignal(
      name,
      args: [
        for (final type in args)
          DBusIntrospectArgument(
            DBusSignature(type),
            DBusArgumentDirection.out,
          ),
      ],
    );
