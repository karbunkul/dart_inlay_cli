part of 'commands.dart';

final class InitCommand extends InlayCommand {
  @override
  String get description => 'Initialize inlay in the current project.';

  @override
  String get name => 'init';

  @override
  Future<int> run() async {
    final file = File(p.join(Directory.current.path, 'inlay.yaml'));

    if (file.existsSync()) {
      logger.info(
        '\n${yellow.wrap('⚠️  inlay.yaml already exists in this directory.')}',
      );
      _showHelpHints();
      return 0;
    }

    logger.info('\n${styleBold.wrap('Initialization')}');
    logger.info(
      'This will create a default ${cyan.wrap('inlay.yaml')} file in your project root.',
    );

    final confirm = logger.confirm(
      'Proceed with creation?',
      defaultValue: true,
    );

    if (!confirm) {
      logger.warn('Aborted.');
      return 0;
    }

    final progress = logger.progress('Creating ${cyan.wrap('inlay.yaml')}...');

    try {
      const content = '''
# Inlay configuration file
# For more information, see https://github.com/karbunkul/inlay

scopes:
  - lib/**.dart

exclude:
  - .dart_tool/**
  - bin/**
''';
      await file.writeAsString(content);
      progress.complete('inlay.yaml created successfully!');

      logger.info('\n${green.wrap('✨ Inlay is ready to go!')}');
      _showHelpHints();

      return 0;
    } catch (e) {
      progress.fail('Failed to create inlay.yaml: $e');
      return 1;
    }
  }

  void _showHelpHints() {
    logger.info('\n${styleBold.wrap('Quick Start:')}');
    logger.info(
      '  ${darkGray.wrap('•')} Run ${lightCyan.wrap('inlay scope')} to see active and untracked files',
    );
    logger.info(
      '  ${darkGray.wrap('•')} Run ${lightCyan.wrap('inlay build')} to generate code based on markers',
    );
    logger.info(
      '  ${darkGray.wrap('•')} Edit ${lightCyan.wrap('inlay.yaml')} to adjust scopes or exclusions',
    );
  }
}
