import 'dart:io';
import 'package:inlay/src/runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late Logger logger;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('inlay_test_');
    logger = Logger();
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  test('build command should process files in deterministic order', () async {
    // 1. Create inlay.yaml
    final configFile = File(p.join(tempDir.path, 'inlay.yaml'));
    configFile.writeAsStringSync('''
scopes:
  - "lib/*.dart"
''');

    // 2. Create target file with inlay marker
    final libDir = Directory(p.join(tempDir.path, 'lib'))..createSync();
    final targetFile = File(p.join(libDir.path, 'main.dart'));
    targetFile.writeAsStringSync('''
// inlay template=dart-export mask=parts/*.dart
// inlay
''');

    // 3. Create parts in non-alphabetical order if possible (some FS might return them differently)
    // We'll create b.dart, a.dart, c.dart
    final partsDir = Directory(p.join(libDir.path, 'parts'))..createSync();
    File(p.join(partsDir.path, 'b.dart')).createSync();
    File(p.join(partsDir.path, 'a.dart')).createSync();
    File(p.join(partsDir.path, 'c.dart')).createSync();

    // 4. Run BuildCommand
    final runner = InlayRunner(logger: logger);
    await runner.run(['build', '--project-dir', tempDir.path]);

    // 5. Verify the content of main.dart
    final content = targetFile.readAsStringSync();

    // Check if they are sorted: a.dart, b.dart, c.dart
    // Note: Template.dartExport() uses "export '{{.}}';"
    expect(content, contains("export 'parts/a.dart';"));
    expect(content, contains("export 'parts/b.dart';"));
    expect(content, contains("export 'parts/c.dart';"));

    // Verify the order specifically
    final first = content.indexOf("export 'parts/a.dart';");
    final second = content.indexOf("export 'parts/b.dart';");
    final third = content.indexOf("export 'parts/c.dart';");

    expect(first, isNot(-1));
    expect(second, isNot(-1));
    expect(third, isNot(-1));
    expect(first < second, isTrue, reason: 'a.dart should come before b.dart');
    expect(second < third, isTrue, reason: 'b.dart should come before c.dart');
  });
}
