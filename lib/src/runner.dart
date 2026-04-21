import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:cli_completion/cli_completion.dart';
import 'package:inlay/inlay.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

const _keyVerbose = 'verbose';
const _keyVersion = 'version';
const _keyHelp = 'help';
const _keyProjectDirectory = 'project-dir';

const _configFileName = 'inlay.yaml';

final class InlayRunner extends CompletionCommandRunner<int> {
  final Logger _logger;
  bool _verbose = false;
  late Directory _projectDir;
  Config? _config;
  bool _isInitialized = false;

  InlayRunner({required Logger logger}) : _logger = logger, super('inlay', '') {
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
    // options
    argParser.addOption(
      _keyProjectDirectory,
      abbr: 'p',
      help: 'The path to the project directory.',
    );

    addCommand(BuildCommand());
    addCommand(ScopeCommand());
    addCommand(InitCommand());
  }

  /// Configures the logger level based on the verbose flag.
  void _verboseSetup(ArgResults topLevelResults) {
    if (topLevelResults[_keyVerbose] == true) {
      _verbose = true;
      _logger.level = Level.verbose;
    }
  }

  /// Loads the [Config] from the configuration file if it exists.
  void _configSetup(ArgResults topLevelResults) {
    if (_config == null && _configFile.existsSync()) {
      final yaml = loadYaml(_configFile.readAsStringSync()) as Map;
      final json = jsonDecode(jsonEncode(yaml));
      final scopes = (json['scopes'] as List?)?.cast<String>() ?? [];
      final exclude = (json['exclude'] as List?)?.cast<String>() ?? [];

      _config = Config(
        scopes: scopes,
        exclude: exclude,
        templates: [Template.dartPart(), Template.dartExport()],
      );

      _logger.detail('DEBUG: Config loaded from ${_configFile.path}');
      _logger.detail('DEBUG: Scopes found: $scopes');
      _logger.detail('DEBUG: Exclude patterns: $exclude');
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

    if (topLevelResults.wasParsed(_keyHelp)) {
      return super.runCommand(topLevelResults);
    }

    if (!_isInitialized) {
      _verboseSetup(topLevelResults);
      _projectDirSetup(topLevelResults);
      _configSetup(topLevelResults);

      _isInitialized = true;
    }
    return super.runCommand(topLevelResults);
  }

  void _projectDirSetup(ArgResults topLevelResults) {
    final path = topLevelResults[_keyProjectDirectory] as String?;

    if (path != null) {
      _projectDir = Directory(path);
    } else {
      final projectDir = _findProjectDir(Directory.current);
      _projectDir = projectDir ?? Directory.current;
    }
  }

  /// Returns the [File] pointing to the `inlay.yaml` configuration file.
  File get _configFile =>
      File(p.join(_projectDir.absolute.path, _configFileName));

  /// Recursively searches for a directory containing `foreman.yaml` starting from [dir].
  Directory? _findProjectDir(Directory dir) {
    final hasConfigFile = File(p.join(dir.path, _configFileName)).existsSync();

    if (hasConfigFile) return dir;

    if (dir.parent.path == dir.path) {
      return null;
    }

    return _findProjectDir(dir.parent);
  }

  Future<int?> _versionSetup() async {
    _logger.info(
      '💎 Inlay 0.9.8\n\n'
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

  /// The parsed configuration specification, if available.
  Config? get config => runner._config;

  /// Whether a configuration was successfully loaded.
  bool get hasConfig => config != null;

  /// The configuration file used by the runner.
  File get configFile => runner._configFile;

  /// Converts a path to POSIX format (using forward slashes).
  String toPosix(String path) => path.replaceAll('\\', '/');
}
