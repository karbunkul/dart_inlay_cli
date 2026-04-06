import 'package:inlay/inlay.dart';
import 'package:mason_logger/mason_logger.dart';

void main(List<String> arguments) {
  final logger = Logger();
  try {
    InlayRunner(logger: logger).run(arguments);
  } catch (e) {
    logger.err(e.toString());
  }
}
