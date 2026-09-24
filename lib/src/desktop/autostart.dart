import 'dart:io';

/// Starts the app hidden in the tray when the user logs in, through an
/// XDG autostart desktop entry.
///
/// Autostart is on by default: the first launch enables it, and a marker
/// file remembers that the default was applied, so turning it off sticks.
class Autostart {
  Autostart({
    required this.entry,
    required this.marker,
    required this.executable,
  });

  /// Uses the standard locations for the current user.
  factory Autostart.forCurrentUser({
    required String appId,
    required Directory dataDir,
  }) {
    final home = Platform.environment['HOME'] ?? '';
    final configHome =
        Platform.environment['XDG_CONFIG_HOME'] ?? '$home/.config';
    return Autostart(
      entry: File('$configHome/autostart/$appId.desktop'),
      marker: File('${dataDir.path}/autostart-configured'),
      executable: Platform.resolvedExecutable,
    );
  }

  /// The XDG autostart entry.
  final File entry;

  /// Exists once the enabled-by-default choice has been applied.
  final File marker;

  /// Program the entry launches.
  final String executable;

  bool get enabled => entry.existsSync();

  /// Applies the default on the first launch and afterwards keeps an
  /// enabled entry pointing at the current executable, in case the app
  /// was moved or reinstalled elsewhere.
  Future<void> applyDefault() async {
    if (!await marker.exists()) {
      await setEnabled(true);
      await marker.parent.create(recursive: true);
      await marker.writeAsString('');
    } else if (enabled) {
      await setEnabled(true);
    }
  }

  Future<void> setEnabled(bool enabled) async {
    if (!enabled) {
      if (await entry.exists()) await entry.delete();
      return;
    }
    await entry.parent.create(recursive: true);
    await entry.writeAsString(desktopEntry);
  }

  String get desktopEntry {
    // Desktop entry spec: quote the program, escaping ", `, $ and \.
    final program = executable.replaceAllMapped(
      RegExp(r'["`$\\]'),
      (m) => '\\${m[0]}',
    );
    return '''
[Desktop Entry]
Type=Application
Name=Minhas Tarefas
Comment=Inicia o Minhas Tarefas na bandeja do sistema
Exec="$program" --hidden
Icon=io.github.professorbossini.minhas_tarefas
Terminal=false
X-GNOME-Autostart-enabled=true
''';
  }
}
