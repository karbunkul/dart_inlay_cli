part of 'commands.dart';

final class ScopeCommand extends InlayCommand {
  @override
  String get description => 'Inspect or add scopes for the current directory.';

  @override
  String get name => 'scope';

  @override
  Future<int> run() async {
    final currentDirRel = toPosix(
      p.relative(Directory.current.path, from: projectDir.path),
    );

    if (!hasConfig) {
      logger.info('inlay.yaml not found in this project.');
      final setup = logger.confirm(
        'Would you like to initialize inlay?',
        defaultValue: true,
      );
      if (setup) {
        return (await runner.run(['init'])) ?? 0;
      }
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
          '  - ${toPosix(p.relative(file.path, from: Directory.current.path))}',
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
      final glob = Glob(scope);
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

    final globs = config!.scopes.map((s) => Glob(s)).toList();
    final excludeGlobs = config!.exclude.map((s) => Glob(s)).toList();

    for (final file in allFiles) {
      final relPath = toPosix(p.relative(file.path, from: projectDir.path));

      if (_isExcluded(relPath, excludeGlobs)) continue;

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

  Future<void> _inspectScope(String scope) async {
    final glob = Glob(scope);
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
      final relPath = toPosix(p.relative(file.path, from: currentDirPath));
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
    String basePath;
    if (untrackedFiles != null && untrackedFiles.isNotEmpty) {
      basePath = toPosix(
        p.relative(untrackedFiles.first.path, from: projectDir.path),
      );
    } else {
      basePath = currentDirRel == '.' ? '*.dart' : '$currentDirRel/*.dart';
    }

    final mode = Select(
      prompt: 'How would you like to add the scope?',
      options: [
        'Use as is: $basePath',
        'Replace parts with * (interactive)...',
        'Custom pattern (edit current)...',
      ],
    ).interact();

    String? finalScope;

    if (mode == 0) {
      finalScope = basePath;
    } else if (mode == 1) {
      final segments = basePath.split('/');
      final selectedIndices = MultiSelect(
        prompt: 'Select segments to replace with * (Space to select)',
        options: segments,
      ).interact();

      final resultSegments = List<String>.from(segments);
      for (final index in selectedIndices) {
        resultSegments[index] = '*';
      }
      finalScope = resultSegments.join('/');
    } else {
      finalScope = Input(
        prompt: 'Enter custom scope pattern',
        defaultValue: basePath,
      ).interact();
    }

    if (finalScope != null && finalScope.isNotEmpty) {
      finalScope = toPosix(finalScope);
      final confirm = Confirm(
        prompt: 'Add "$finalScope" to inlay.yaml?',
        defaultValue: true,
      ).interact();

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
