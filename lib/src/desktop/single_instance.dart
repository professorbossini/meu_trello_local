import 'package:dbus/dbus.dart';
import 'package:flutter/foundation.dart';

/// Ensures a single running instance by owning a well-known D-Bus name.
///
/// When the app is launched again, the new process asks the running one to
/// show its window through [activateMethod] and exits, which is what users
/// expect when clicking the launcher of an app that lives in the tray.
class SingleInstance extends DBusObject {
  SingleInstance._(this._onActivate) : super(_path);

  static const busName = 'io.github.professorbossini.MeuTrelloLocal';
  static const interface = busName;
  static const activateMethod = 'Activate';
  static final _path = DBusObjectPath(
    '/io/github/professorbossini/MeuTrelloLocal',
  );

  final VoidCallback _onActivate;

  /// Tries to become the primary instance, returning `true` on success.
  ///
  /// Otherwise the primary instance is asked to activate and `false` is
  /// returned; the caller should then exit.
  static Future<bool> claim(
    DBusClient client, {
    required VoidCallback onActivate,
  }) async {
    final reply = await client.requestName(
      busName,
      flags: {DBusRequestNameFlag.doNotQueue},
    );
    if (reply == DBusRequestNameReply.primaryOwner ||
        reply == DBusRequestNameReply.alreadyOwner) {
      await client.registerObject(SingleInstance._(onActivate));
      return true;
    }

    await client.callMethod(
      destination: busName,
      path: _path,
      interface: interface,
      name: activateMethod,
      replySignature: DBusSignature(''),
    );
    return false;
  }

  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall methodCall) async {
    if (methodCall.interface != interface ||
        methodCall.name != activateMethod) {
      return DBusMethodErrorResponse.unknownMethod();
    }
    _onActivate();
    return DBusMethodSuccessResponse();
  }

  @override
  List<DBusIntrospectInterface> introspect() => [
    DBusIntrospectInterface(
      interface,
      methods: [DBusIntrospectMethod(activateMethod)],
    ),
  ];
}
