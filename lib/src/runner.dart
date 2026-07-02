import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:cli_completion/cli_completion.dart';
import 'package:inlay/inlay.dart';
import 'package:mason_logger/mason_logger.dart';

const version = '2.0.0-beta';
const _keyVerbose = 'verbose';
const _keyVersion = 'version';
const _keyHelp = 'help';
// const _keyProjectDirectory = 'project-dir';

final class InlayRunner extends CompletionCommandRunner<int> {
  final Logger _logger;
  late Directory _projectDir;
  bool _isInitialized = false;

  InlayRunner({required Logger logger})
    : _logger = logger,
      super(
        'inlay',
        'A Dart tool for automatically managing part directives.',
      ) {
    // flags
    argParser
      ..addFlag(
        _keyVerbose,
        abbr: 'v',
        negatable: false,
        help: 'Enable verbose logging.',
      )
      ..addFlag(
        _keyVersion,
        help: 'Reports the version of this tool.',
        defaultsTo: false,
        negatable: false,
      );

    addCommand(BuildCommand());
    addCommand(WatchCommand());
  }

  /// Configures the logger level based on the verbose flag.
  void _verboseSetup(ArgResults topLevelResults) {
    if (topLevelResults[_keyVerbose] == true) {
      _logger.level = Level.verbose;
    }
  }

  @override
  Future<int?> runCommand(ArgResults topLevelResults) {
    if (topLevelResults.command?.name == 'completion' ||
        topLevelResults.wasParsed(_keyHelp)) {
      return super.runCommand(topLevelResults);
    }

    if (topLevelResults.wasParsed(_keyVersion)) {
      return _versionSetup();
    }

    if (!_isInitialized) {
      _verboseSetup(topLevelResults);
      // _projectDirSetup(topLevelResults);

      _isInitialized = true;
    }
    return super.runCommand(topLevelResults);
  }

  // void _projectDirSetup(ArgResults topLevelResults) {
  //   final path = topLevelResults[_keyProjectDirectory] as String?;
  //
  //   if (path != null) {
  //     _projectDir = Directory(path);
  //   } else {
  //     _projectDir = Directory.current;
  //   }
  // }

  Future<int?> _versionSetup() async {
    _logger.info(
      '💎 Inlay $version\n\n'
      'Author: Alexander Pokhodyun (karbunkul) https://github.com/karbunkul\n',
    );

    return 0;
  }

  @override
  String get usageFooter {
    return '\n(c) 2026, Alexander Pokhodyun (karbunkul)';
  }

  @override
  bool get enableAutoInstall => false;
}

abstract base class InlayCommand extends Command<int> {
  @override
  InlayRunner get runner => super.runner as InlayRunner;

  /// Access to the logger instance.
  Logger get logger => runner._logger;

  /// The project directory for the current execution.
  Directory get projectDir => runner._projectDir;

  /// Converts a path to POSIX format (using forward slashes).
  String toPosix(String path) => path.replaceAll('\\', '/');
}
