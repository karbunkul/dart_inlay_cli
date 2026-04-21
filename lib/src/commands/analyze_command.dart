part of 'commands.dart';

final class AnalyzeCommand extends InlayCommand {
  AnalyzeCommand() {
    argParser.addOption(
      'dir',
      abbr: 'p',
      help: 'Directory to analyze (default is current directory).',
      valueHelp: 'PATH',
    );
    argParser.addOption('depth', abbr: 'd', help: 'Maximum depth to scan.');
  }

  @override
  String get description => 'Analyze project to suggest inlay markers.';

  @override
  String get name => 'analyze';

  @override
  Future<int> run() async {
    final dirPath = argResults?['dir'] as String?;
    final depthStr = argResults?['depth'] as String?;

    // Priority: 1. CLI flag, 2. Config file, 3. Default (2)
    var maxDepth = int.tryParse(depthStr ?? '') ?? config?.analyzeDepth ?? 2;

    if (maxDepth > 3) {
      logger.warn('Depth $maxDepth is too high, limiting to 3.');
      maxDepth = 3;
    }

    final targetDir = dirPath != null ? Directory(dirPath) : Directory.current;

    if (!targetDir.existsSync()) {
      logger.err('Directory not found: ${targetDir.path}');
      return 1;
    }

    final displayDir = toPosix(
      p.relative(targetDir.path, from: projectDir.path),
    );

    logger.detail('DEBUG: Configuration:');
    logger.detail('  Extensions: ${config?.analyzeExtensions}');
    logger.detail('  Keywords: ${config?.analyzeKeywords}');
    logger.detail('  Max Depth: $maxDepth');

    logger.info(
      'Analyzing ${displayDir == '.' ? 'current directory' : displayDir} (depth: $maxDepth)...',
    );

    final allFiles = _listAllFiles(targetDir, maxDepth);

    if (allFiles.isEmpty) {
      logger.warn('No files found for analysis.');
      return 0;
    }

    final patterns = _analyzePatterns(allFiles, targetDir);

    if (patterns.isEmpty) {
      logger.warn('No clear patterns found.');
      return 0;
    }

    logger.info('\n${lightCyan.wrap('Suggested Inlay Markers:')}\n');

    for (final pattern in patterns) {
      final marker = Marker.dart().toCommentTag(
        template: 'dart-part',
        mask: pattern.mask,
      );

      logger.info('Group: ${pattern.suffix} (${pattern.count} files)');
      logger.info('  ${green.wrap('Marker:')} $marker');
      logger.info(
        '  ${darkGray.wrap('Files:')} ${pattern.examples.join(', ')}',
      );
      logger.info('');
    }

    if (config?.isUsingDefaultAnalyzeConfig == true) {
      logger.info(
        '${darkGray.wrap('Tip: You can customize analysis in inlay.yaml:')}\n'
        '${darkGray.wrap('analyze:')}\n'
        '${darkGray.wrap('  depth: 2')}\n'
        '${darkGray.wrap('  keywords: [Page, Entity, Bloc]')}\n',
      );
    }

    return 0;
  }

  List<File> _listAllFiles(Directory dir, int maxDepth) {
    final files = <File>[];
    _scan(dir, 1, maxDepth, files);
    return files;
  }

  void _scan(Directory dir, int depth, int maxDepth, List<File> result) {
    final extensions = config?.analyzeExtensions ?? ['dart'];

    for (final entity in dir.listSync(followLinks: false)) {
      if (entity is File) {
        final ext = p.extension(entity.path).replaceFirst('.', '');
        if (extensions.contains(ext)) {
          logger.detail('DEBUG: Found file: ${entity.path}');
          result.add(entity);
        }
      } else if (entity is Directory) {
        // Заходим в подпапку только если текущая глубина меньше максимальной
        if (depth < maxDepth) {
          final relPath = toPosix(
            p.relative(entity.path, from: projectDir.path),
          );
          // Простая проверка исключений
          if (!relPath.contains('bin') && !relPath.contains('test')) {
            logger.detail('DEBUG: Scanning directory: ${entity.path}');
            _scan(entity, depth + 1, maxDepth, result);
          }
        }
      }
    }
  }

  List<_FileGroup> _analyzePatterns(List<File> files, Directory targetDir) {
    final suffixCounts = <String, List<String>>{};
    final dirMap = <String, Set<String>>{};
    final customKeywords = config?.analyzeKeywords ?? [];

    for (final file in files) {
      final name = p.basename(file.path);
      // Вычисляем путь относительно целевой директории анализа
      final relPath = toPosix(p.relative(file.path, from: targetDir.path));
      final dir = p.dirname(relPath);

      String? detectedSuffix;

      // 1. Try custom keywords from config
      for (final keyword in customKeywords) {
        if (name.contains(keyword)) {
          final ext = p.extension(name);
          final keywordIndex = name.indexOf(keyword);
          detectedSuffix = name.substring(keywordIndex);
          if (!detectedSuffix.endsWith(ext)) detectedSuffix += ext;
          break;
        }
      }

      // 2. Try snake_case suffix (e.g. _command.dart)
      if (detectedSuffix == null) {
        final parts = name.split('_');
        if (parts.length > 1) {
          detectedSuffix = '_${parts.last}';
        }
      }

      // 3. Fallback to extension
      detectedSuffix ??= p.extension(name);

      if (detectedSuffix.isNotEmpty) {
        suffixCounts.putIfAbsent(detectedSuffix, () => []).add(relPath);
        dirMap.putIfAbsent(detectedSuffix, () => {}).add(dir);
      }
    }

    return suffixCounts.entries
        .where((e) => e.value.length >= 2) // only groups with 2+ files
        .map((e) {
          final suffix = e.key;
          final paths = e.value;
          final dirs = dirMap[suffix]!;

          // Если файлы в разных папках или не в корне целевой папки
          final isInSubdir = dirs.any((d) => d != '.');
          final isMultipleDirs = dirs.length > 1;

          String mask;
          if (isMultipleDirs) {
            mask = '**$suffix';
          } else if (isInSubdir) {
            final dir = dirs.first;
            mask = '$dir/*$suffix';
          } else {
            mask = '*$suffix';
          }

          return _FileGroup(
            suffix: suffix,
            mask: mask,
            count: paths.length,
            examples: paths.take(3).map(p.basename).toList(),
          );
        })
        .toList()
      ..sort((a, b) => b.count.compareTo(a.count));
  }
}

class _FileGroup {
  final String suffix;
  final String mask;
  final int count;
  final List<String> examples;

  _FileGroup({
    required this.suffix,
    required this.mask,
    required this.count,
    required this.examples,
  });
}
