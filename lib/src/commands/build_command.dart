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
    final file = argResults?['file'] as String?;

    if (file != null) {
      final normalizeFile = File(p.normalize(file));

      if (!normalizeFile.existsSync()) {
        logger.err('File $file not found');
        return 1;
      } else {
        final config = Config(
          templates: [Template.dartPart(), Template.dartExport()],
          scopes: [normalizeFile.path],
        );
        _generate(file: normalizeFile, config: config);
        return 0;
      }
    }

    if (config == null) {
      logger.err('Config inlay.yaml not found');
      return 1;
    }

    final excludeGlobs = config!.exclude
        .map((s) => Glob(s, context: p.Context(style: p.Style.posix)))
        .toList();

    for (final scope in config!.scopes) {
      final glob = Glob(scope, context: p.Context(style: p.Style.posix));
      for (var entity in glob.listSync(
        root: projectDir.path,
        followLinks: false,
      )) {
        if (entity is! File) continue;

        final relPath = _toPosix(
          p.relative(entity.path, from: projectDir.path),
        );

        if (!_isExcluded(relPath, excludeGlobs)) {
          _generate(file: entity as File, config: config!);
        }
      }
    }

    return 0;
  }

  bool _isExcluded(String relPath, List<Glob> excludes) {
    for (final glob in excludes) {
      if (glob.matches(relPath)) return true;
      var parent = p.dirname(relPath);
      while (parent != '.' && parent != '/') {
        if (glob.matches(parent)) return true;
        parent = p.dirname(parent);
      }
    }
    return false;
  }

  String _toPosix(String path) {
    if (p.style == p.Style.windows) {
      return path.replaceAll('\\', '/');
    }
    return path;
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

      if (!config.hasTemplate(rule.template)) return;

      final template = config.template(rule.template)!;

      final res = rule.replace(
        file: file,
        template: template.template,
        marker: template.marker,
        files: parts,
      );

      final dryRun = argResults?.flag('dry-run') ?? false;

      if (dryRun) {
        logger.info('--- ${file.path} ---');
        logger.info(res);
      } else {
        file.writeAsStringSync(res);
        logger.success('Built ${p.relative(file.path, from: projectDir.path)}');
      }
    }
  }
}
