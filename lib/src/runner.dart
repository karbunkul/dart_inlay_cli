import 'package:args/command_runner.dart';
import 'package:cli_completion/cli_completion.dart';
import 'package:inlay/inlay.dart';

final class InlayRunner extends CompletionCommandRunner<int> {
  InlayRunner() : super('inlay', '') {
    addCommand(BuildCommand());
  }

  @override
  bool get enableAutoInstall => false;
}
