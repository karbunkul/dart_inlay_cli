import 'package:inlay/inlay.dart';
import 'package:mason_logger/mason_logger.dart';

// inlay template=dart-export mask=/*_page.dart
// GENERATED CODE - DO NOT MODIFY BY HAND

// inlay

void main(List<String> arguments) async {
  final logger = Logger();
  try {
    await InlayRunner(logger: logger).run(arguments);
  } catch (e) {
    logger.err(e.toString());
  }
}
