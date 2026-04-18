part of 'commands.dart';

final class ScopeCommand extends InlayCommand {
  @override
  String get description => 'Inspect or add scopes for the current directory.';

  @override
  String get name => 'scope';

  @override
  Future<int> run() async {
    final currentDirRel = p.relative(
      Directory.current.path,
      from: projectDir.path,
    );

    if (!hasConfig) {
      logger.err(
        'inlay.yaml not found. Run this command in a project with inlay initialized.',
      );
      return 1;
    }

    final activeScopes = _findActiveScopes();
    final untrackedWithMarkers = await _findUntrackedFilesWithMarkers();

    if (activeScopes.isNotEmpty) {
      logger.info('Current directory context:');
      for (final scope in activeScopes) {
        logger.info('\n  ${lightCyan.wrap('active scope:')} $scope');
        await _inspectScope(scope);
      }
    }

    if (untrackedWithMarkers.isNotEmpty) {
      logger.info(
        '\n${yellow.wrap('⚠️  Detected ${untrackedWithMarkers.length} untracked file(s) with inlay markers:')}',
      );
      for (final file in untrackedWithMarkers.take(5)) {
        logger.info(
          '  - ${p.relative(file.path, from: Directory.current.path)}',
        );
      }
      if (untrackedWithMarkers.length > 5) {
        logger.info(
          '    ${darkGray.wrap('... and ${untrackedWithMarkers.length - 5} more')}',
        );
      }

      await _suggestAddingScope(
        currentDirRel,
        untrackedFiles: untrackedWithMarkers,
      );
    } else if (activeScopes.isEmpty) {
      logger.warn(
        '\nNo active scopes or untracked markers found in this directory.',
      );
      await _suggestAddingScope(currentDirRel);
    }

    return 0;
  }

  List<String> _findActiveScopes() {
    final active = <String>[];
    final currentDirPath = Directory.current.path;

    for (final scope in config!.scopes) {
      final glob = Glob(scope, context: p.Context(style: p.Style.posix));
      final hasMatches = glob.listSync(root: projectDir.path).any((entity) {
        return p.isWithin(currentDirPath, entity.path) ||
            entity.path == currentDirPath;
      });

      if (hasMatches) {
        active.add(scope);
      }
    }
    return active;
  }

  Future<List<File>> _findUntrackedFilesWithMarkers() async {
    final currentDirPath = Directory.current.path;
    final allFiles = Directory(currentDirPath)
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();

    final untracked = <File>[];
    final marker = Marker.dart();
    final pattern = marker.pattern();

    final globs = config!.scopes
        .map((s) => Glob(s, context: p.Context(style: p.Style.posix)))
        .toList();

    for (final file in allFiles) {
      final relPath = p.relative(file.path, from: projectDir.path);
      final isTracked = globs.any((g) => g.matches(relPath));

      if (!isTracked) {
        final content = await file.readAsString();
        if (pattern.hasMatch(content)) {
          untracked.add(file);
        }
      }
    }
    return untracked;
  }

  Future<void> _inspectScope(String scope) async {
    final glob = Glob(scope, context: p.Context(style: p.Style.posix));
    final currentDirPath = Directory.current.path;

    final files = glob
        .listSync(root: projectDir.path)
        .whereType<File>()
        .where(
          (f) => p.isWithin(currentDirPath, f.path) || f.path == currentDirPath,
        )
        .toList();

    if (files.isEmpty) return;

    int totalMarkers = 0;
    final filesWithMarkers = <File>[];
    final marker = Marker.dart();
    final pattern = marker.pattern();

    for (final file in files) {
      final content = await file.readAsString();
      final matches = pattern.allMatches(content).length;
      if (matches > 0) {
        totalMarkers += matches;
        filesWithMarkers.add(file);
      }
    }

    logger.info('    ${green.wrap('Matched files:')} ${files.length}');
    if (totalMarkers > 0) {
      logger.info(
        '    ${yellow.wrap('Inlays:')} $totalMarkers markers in ${filesWithMarkers.length} files',
      );
    }

    for (final file in files.take(3)) {
      final relPath = p.relative(file.path, from: currentDirPath);
      final hasMarkers = filesWithMarkers.contains(file);
      logger.info(
        '      ${darkGray.wrap('->')} $relPath ${hasMarkers ? yellow.wrap('⚡') : ''}',
      );
    }
  }

  Future<void> _suggestAddingScope(
    String currentDirRel, {
    List<File>? untrackedFiles,
  }) async {
    final choices = <String>{};

    if (untrackedFiles != null && untrackedFiles.isNotEmpty) {
      for (final file in untrackedFiles) {
        final dir = p.dirname(p.relative(file.path, from: projectDir.path));
        choices.add(dir == '.' ? '*.dart' : '$dir/*.dart');
        choices.add(dir == '.' ? '**.dart' : '$dir/**.dart');
      }
    }

    if (currentDirRel != '.') {
      choices.add('$currentDirRel/*.dart');
      choices.add('$currentDirRel/**.dart');
    }

    choices.addAll(['*.dart', '**.dart', 'Custom pattern...']);

    final selection = logger.chooseOne(
      '\nChoose a pattern to add to scopes:',
      choices: choices.toList(),
      defaultValue: choices.first,
    );

    String? finalScope = selection;
    if (selection == 'Custom pattern...') {
      finalScope = logger.prompt('Enter custom scope pattern:');
    }

    if (finalScope != null && finalScope.isNotEmpty) {
      final confirm = logger.confirm(
        'Add "$finalScope" to inlay.yaml?',
        defaultValue: true,
      );
      if (confirm) {
        _addScopeToConfig(finalScope);
        logger.success('Added scope: $finalScope');
      }
    }
  }

  void _addScopeToConfig(String newScope) {
    final file = configFile;
    final content = file.readAsStringSync();
    final lines = content.split('\n');
    int scopesIndex = lines.indexWhere((line) => line.trim() == 'scopes:');

    if (scopesIndex == -1) {
      if (lines.isNotEmpty && lines.last.isNotEmpty) lines.add('');
      lines.add('scopes:');
      lines.add('  - $newScope');
    } else {
      lines.insert(scopesIndex + 1, '  - $newScope');
    }
    file.writeAsStringSync(lines.join('\n'));
  }
}
