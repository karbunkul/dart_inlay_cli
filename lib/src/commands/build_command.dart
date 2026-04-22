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
    argParser.addFlag(
      'tag',
      abbr: 't',
      help: 'Filter by tags. If no tags provided, shows interactive selector.',
      negatable: false,
    );
  }

  @override
  String get description => 'Scan scopes and update inlay markers.';

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
          scopes: [Scope(pattern: toPosix(normalizeFile.path))],
        );
        _generate(file: normalizeFile, config: config);
        return 0;
      }
    }

    if (config == null) {
      logger.info('inlay.yaml not found.');
      final setup = logger.confirm(
        'Would you like to initialize inlay?',
        defaultValue: true,
      );
      if (setup) {
        return (await runner.run(['init'])) ?? 0;
      }
      return 1;
    }
    final excludeGlobs = config!.exclude.map((s) => Glob(s)).toList();
    var requestedTags = <String>[];

    if (argResults?.wasParsed('tag') == true) {
      requestedTags = argResults?.rest ?? [];

      if (requestedTags.isEmpty) {
        final allTags = config!.scopes.expand((s) => s.tags).toSet().toList()
          ..sort();

        if (allTags.isEmpty) {
          logger.warn('No tags defined in inlay.yaml');
        } else {
          final selection = MultiSelect(
            prompt: 'Select tags to build (Space to select, Enter to confirm)',
            options: allTags,
          ).interact();

          requestedTags = selection.map((i) => allTags[i]).toList();
          if (requestedTags.isEmpty) {
            logger.warn('No tags selected. Aborting.');
            return 0;
          }
        }
      }
    }

    for (final scope in config!.scopes) {
      if (requestedTags.isNotEmpty &&
          !requestedTags.any((tag) => scope.hasTag(tag))) {
        continue;
      }

      logger.detail('Processing scope: ${scope.pattern}');
      final glob = Glob(scope.pattern);
      for (var entity in glob.listSync(
        root: projectDir.path,
        followLinks: false,
      )) {
        if (entity is! File) continue;

        final relPath = p.relative(entity.path, from: projectDir.path);

        if (!_isExcluded(relPath, excludeGlobs)) {
          logger.detail('Processing $relPath');
          _generate(
            file: entity as File,
            config: config!,
            requestedTags: requestedTags,
          );
        } else {
          logger.detail('Skipping excluded file $relPath');
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

  void _generate({
    required File file,
    required Config config,
    List<String> requestedTags = const [],
  }) {
    final inlay = Inlay();
    final marker = Marker.dart();
    final content = file.readAsStringSync();
    var rules = inlay.parse(content: content, marker: marker);

    if (rules.isEmpty) return;

    if (requestedTags.isNotEmpty) {
      rules = rules.where((r) => requestedTags.contains(r.tag)).toList();
    }

    if (rules.isEmpty) return;

    final path = p.normalize(file.parent.path);
    var updatedContent = content;

    // Apply replacements in reverse order to keep offsets valid
    for (final rule in rules.reversed) {
      logger.detail(
        'Found rule in ${file.path}: template=${rule.template}, mask=${rule.mask}',
      );
      final glob = Glob(rule.mask);
      final parts = <String>[];

      for (var entity in glob.listSync(
        root: p.normalize(path),
        followLinks: false,
      )) {
        final part = entity.path.substring(path.length + 1);
        final posixPart = toPosix(part);
        logger.detail('  Matched: $posixPart');
        parts.add(posixPart);
      }

      if (!config.hasTemplate(rule.template)) {
        logger.detail('Template ${rule.template} not found in config');
        continue;
      }

      final template = config.template(rule.template)!;

      updatedContent = rule.replace(
        content: updatedContent,
        template: template.template,
        marker: template.marker,
        files: parts,
      );
    }

    final dryRun = argResults?.flag('dry-run') ?? false;

    if (dryRun) {
      logger.info('--- ${file.path} ---');
      logger.info(updatedContent);
    } else if (updatedContent != content) {
      file.writeAsStringSync(updatedContent);
      logger.success('Built ${p.relative(file.path, from: projectDir.path)}');
    }
  }
}
