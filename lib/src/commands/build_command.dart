part of 'commands.dart';

final class BuildCommand extends InlayCommand {
  BuildCommand() {
    argParser.addFlag('dry-run', negatable: false, help: 'Preview changes');
  }

  @override
  String get description => 'generate code';

  @override
  String get name => 'build';

  @override
  Future<int> run() async {
    final inlay = Inlay();

    final file = File(
      p.normalize(
        p.join(Directory.current.path, 'lib/src/commands/commands.dart'),
      ),
    );

    if (!file.existsSync()) {
      throw ArgumentError('File not found');
    }

    final rule = inlay.parseFile(file: file, marker: Marker.dart());
    final path = file.parent.path;

    if (rule != null) {
      final glob = Glob(rule.mask, context: p.Context(style: p.Style.posix));
      final parts = <String>[];

      for (var entity in glob.listSync(root: path, followLinks: false)) {
        parts.add(entity.basename);
      }

      final dartPart = '''{{#files}}part '{{ . }}';\n{{/files}}\n\n''';
      final res = rule.replace(
        file: file,
        template: dartPart,
        marker: Marker.dart(),
        files: parts,
      );

      final dryRun = argResults?.flag('dry-run') ?? false;

      if (dryRun) {
        print(res);
      } else {
        file.writeAsStringSync(res);
      }
    }

    return 0;
  }
}
