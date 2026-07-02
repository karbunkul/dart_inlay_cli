part of 'commands.dart';

/// A command that watches for file changes and automatically manages `part` directives.
final class WatchCommand extends InlayCommand {
  WatchCommand() {
    argParser.addOption(
      'dir',
      abbr: 'd',
      help: 'The directory to watch. Defaults to the project directory.',
      valueHelp: 'PATH',
    );
  }

  @override
  String get description =>
      'Watch for file changes and update part directives automatically.';

  @override
  String get name => 'watch';

  @override
  Future<int> run() async {
    final dirPath = argResults?['dir'] as String? ?? Directory.current.path;
    DirectoryWatcher(dirPath).events.listen((event) {
      InlayHandler(event: event, processor: PartProcessor()).handle();
    });

    return 0;
  }
}
