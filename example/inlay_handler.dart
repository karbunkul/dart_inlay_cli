import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:watcher/watcher.dart';

final class InlayHandler {
  final WatchEvent _event;

  InlayHandler({required WatchEvent event}) : _event = event;

  void handle() {
    if (p.extension(_event.path) != '.dart') return;
    final content = File(_event.path).readAsStringSync();

    final pattern = RegExp(r"^part of '(.+\.dart)';", multiLine: true);

    if (!pattern.hasMatch(content)) {
      return;
    }

    final match = pattern.firstMatch(content);
    final partOfPath = match!.group(1)!;
    final dir = p.dirname(_event.path);
    final mainFile = File(p.normalize(p.join(dir, partOfPath)));

    if (!mainFile.existsSync()) {
      return;
    }

    final relativePath = p.relative(
      _event.path,
      from: p.dirname(mainFile.path),
    );
    final partLine = 'part \'$relativePath\';';
    final fileContent = mainFile.readAsStringSync();

    return switch (_event.type) {
      .ADD => _updatePart(partLine: partLine, fileContent: fileContent),
      .MODIFY => _updatePart(partLine: partLine, fileContent: fileContent),
      .REMOVE => _updatePart(partLine: partLine, fileContent: fileContent),
      _ => UnimplementedError(),
    };
  }

  void _updatePart({required String partLine, required String fileContent}) {
    print('update part logic');
    if (fileContent.contains(partLine)) {
      print('already exist part');
      return;
    }
  }

  void _removePart({required String partLine, required String fileContent}) {
    print('remove part logic');
  }
}
