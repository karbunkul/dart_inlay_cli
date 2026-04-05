import 'package:inlay/inlay.dart';
import 'package:test/test.dart';
import 'package:file/file.dart';
import 'package:file/memory.dart';

void main() {
  test('Parse rule in file', () {
    final inlay = Inlay();

    final file = makeFileForTest(
      content: 'part \'foo.dart\';\npart \'bar.dart;\'',
      params: 'template= dart-part mask =*.dart',
      marker: Marker.dart(),
      before: 'library;',
      after: 'String foo() => \'foo\';',
    );

    var rule = inlay.parseFile(file: file, marker: Marker.dart());

    expect(rule, isNot(isNull));
    expect(rule!.mask, '*.dart');
    expect(rule.template, 'dart-part');
  });
}

File makeFileForTest({
  required String content,
  required String params,
  required Marker marker,
  required String before,
  required String after,
}) {
  final fs = MemoryFileSystem();
  final file = fs.file('test.dart');

  final firstTag =
      '${marker.start} inlay $params ${marker.block ? marker.end : ''}';
  final secondTag = '${marker.start} inlay ${marker.block ? marker.end : ''}';

  final fileContent = [
    before,
    firstTag,
    content,
    secondTag,
    after,
  ].join('\n\n');
  file.writeAsStringSync(fileContent);

  return file;
}
