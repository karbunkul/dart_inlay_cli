part of 'commands.dart';

final class BuildCommand extends InlayCommand {
  BuildCommand() {
    argParser.addFlag(
      'dry-run',
      negatable: false,
      help: 'Preview changes without writing to files.',
    );
    argParser.addOption(
      'file',
      abbr: 'f',
      help: 'Process a specific file instead of using scopes from inlay.yaml.',
      valueHelp: 'PATH',
    );
  }

  @override
  String get description => 'generate code';

  @override
  String get name => 'build';

  @override
  Future<int> run() async {
    if (config == null) {
      logger.err('Config inlay.yaml not found');
      return 1;
    }

    final file = argResults?['file'] as String?;

    if (file != null) {
      final normalizeFile = File(p.normalize(file));

      if (!normalizeFile.existsSync()) {
        logger.err('File $file not found');
        return 1;
      } else {
        _generate(file: normalizeFile, config: config!);
        return 0;
      }
    }

    for (final scope in config!.scopes) {
      final file = File(p.normalize(scope));
      if (file.existsSync()) {
        _generate(file: file, config: config!);
      } else {
        final glob = Glob(scope, context: p.Context(style: p.Style.posix));
        for (var entity in glob.listSync(root: p.current, followLinks: false)) {
          _generate(file: File(entity.path), config: config!);
        }
      }
    }

    return 0;
  }

  void _generate({required File file, required Config config}) {
    final inlay = Inlay();
    final rule = inlay.parseFile(file: file, marker: Marker.dart());
    final path = file.parent.path;

    if (rule != null) {
      final glob = Glob(rule.mask, context: p.Context(style: p.Style.posix));
      final parts = <String>[];

      for (var entity in glob.listSync(root: path, followLinks: false)) {
        parts.add(entity.path.substring(path.length + 1));
      }

      if (!config.hasTemplate(rule.template)) {}

      final template = config.template(rule.template)!;

      final res = rule.replace(
        file: file,
        template: template.template,
        marker: template.marker,
        files: parts,
      );

      final dryRun = argResults?.flag('dry-run') ?? false;

      if (dryRun) {
        print(res);
      } else {
        file.writeAsStringSync(res);
      }
    }
  }
}
