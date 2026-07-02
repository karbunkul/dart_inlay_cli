import 'dart:io';
import 'package:path/path.dart' as p;

/// A processor responsible for managing `part` directives in Dart files.
final class PartProcessor {
  /// Handles addition or modification of a part file.
  /// Reads the `part of` directive to find and update the main library file.
  void upsertPart(String eventPath) {
    final eventFile = File(eventPath);
    if (!eventFile.existsSync()) return;

    final content = eventFile.readAsStringSync();
    final pattern = RegExp(r"^part of '(.+\.dart)';", multiLine: true);
    final match = pattern.firstMatch(content);
    if (match == null) return;

    // Find the main file
    final partOfPath = match.group(1)!;
    final dir = p.dirname(eventPath);
    final mainFile = File(p.normalize(p.join(dir, partOfPath)));
    if (!mainFile.existsSync()) return;

    // Format the part directive string for insertion
    final relativePath = p.relative(eventPath, from: p.dirname(mainFile.path));
    // Convert paths to POSIX format (using '/'), as Dart expects it in directives even on Windows
    final posixRelativePath = p.posix.joinAll(p.split(relativePath));
    final partLine = "part '$posixRelativePath';";

    updateMainFile(mainFile, partLine, isRemoval: false);
  }

  /// Handles removal of a part file by scanning neighbor files for references.
  void removePart(String eventPath) {
    final dir = Directory(p.dirname(eventPath));
    if (!dir.existsSync()) return;

    File? mainFile;
    String? partLine;

    // Scan neighboring files to find the one that referenced the deleted file
    for (final entry in dir.listSync()) {
      if (entry is File && p.extension(entry.path) == '.dart') {
        if (p.canonicalize(entry.path) == p.canonicalize(eventPath)) {
          continue;
        }

        final content = entry.readAsStringSync();
        final relativePath = p.relative(eventPath, from: p.dirname(entry.path));
        final posixRelativePath = p.posix.joinAll(p.split(relativePath));

        // Search considering potential differences in quotes
        final escapedPath = RegExp.escape(posixRelativePath);
        final partPattern = RegExp("part\\s+['\"]$escapedPath['\"]\\s*;");

        final match = partPattern.firstMatch(content);
        if (match != null) {
          mainFile = entry;
          partLine = match.group(0);
          break;
        }
      }
    }

    if (mainFile == null || partLine == null) return;

    updateMainFile(mainFile, partLine, isRemoval: true);
  }

  /// Updates the content of the [mainFile] by adding or removing the [partLine].
  /// It also ensures that all `part` directives remain sorted alphabetically.
  void updateMainFile(
    File mainFile,
    String partLine, {
    required bool isRemoval,
  }) {
    final mainFileContent = mainFile.readAsStringSync();
    List<String> lines = mainFileContent.split('\n');

    final partRegex = RegExp(r"^part '.+\.dart';$");
    final partLines = lines
        .where((l) => partRegex.hasMatch(l.trim()))
        .map((l) => l.trim())
        .toSet();

    bool changed = false;
    if (isRemoval) {
      changed = partLines.remove(partLine.trim());
    } else {
      changed = partLines.add(partLine.trim());
    }

    final sortedParts = partLines.toList()..sort();
    final currentParts = lines
        .where((l) => partRegex.hasMatch(l.trim()))
        .map((l) => l.trim())
        .toList();

    bool needsUpdate =
        changed ||
        currentParts.length != sortedParts.length ||
        !Iterable.generate(
          sortedParts.length,
        ).every((i) => currentParts[i] == sortedParts[i]);

    if (!needsUpdate) return;

    final firstPartIndex = lines.indexWhere(
      (l) => partRegex.hasMatch(l.trim()),
    );
    lines.removeWhere((l) => partRegex.hasMatch(l.trim()));

    if (sortedParts.isNotEmpty) {
      if (firstPartIndex != -1) {
        lines.insertAll(firstPartIndex, sortedParts);
      } else {
        final lastImportIndex = lines.lastIndexWhere(
          (l) => l.trim().startsWith('import '),
        );
        if (lastImportIndex != -1) {
          lines.insertAll(lastImportIndex + 1, ['', ...sortedParts]);
        } else {
          lines.insertAll(0, [...sortedParts, '']);
        }
      }
    }

    final newContent = lines.join('\n').replaceAll(RegExp(r'\n{3,}'), '\n\n');
    mainFile.writeAsStringSync(newContent);
    stdout.writeln('Updated ${mainFile.path}');
  }
}
