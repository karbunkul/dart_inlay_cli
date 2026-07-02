part of 'commands.dart';

final class BuildCommand extends InlayCommand {
  BuildCommand() {
    argParser.addOption(
      'file',
      abbr: 'f',
      help: 'Process a specific file.',
      valueHelp: 'PATH',
    );
  }

  @override
  String get description => 'Builds and updates single file.';

  @override
  String get name => 'build';

  @override
  Future<int> run() async {
    final filePath = argResults?['file'] as String?;
    final file = filePath != null ? File(filePath) : null;
    if (file != null && file.existsSync()) {
      final event = WatchEvent(.MODIFY, file.absolute.path);
      InlayHandler(event: event, processor: PartProcessor()).handle();
    }

    return 0;
  }
}
