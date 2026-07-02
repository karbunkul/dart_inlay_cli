import 'package:path/path.dart' as p;
import 'package:watcher/watcher.dart';
import 'part_processor.dart';

/// A handler responsible for automatically managing `part` directives in Dart files.
///
/// When a file with a `part of` directive is added or modified, [InlayHandler]
/// ensures the corresponding main file contains the matching `part` directive.
/// When such a file is removed, it cleans up the reference in the main file.
final class InlayHandler {
  final WatchEvent _event;
  final PartProcessor _processor;

  InlayHandler({required WatchEvent event, PartProcessor? processor})
      : _event = event,
        _processor = processor ?? PartProcessor();

  /// Processes the [WatchEvent] and triggers the appropriate update logic.
  void handle() {
    if (p.extension(_event.path) != '.dart') return;

    if (_event.type == ChangeType.REMOVE) {
      _processor.removePart(_event.path);
    } else {
      _processor.upsertPart(_event.path);
    }
  }
}
