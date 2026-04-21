import 'package:inlay/inlay.dart';
import 'package:test/test.dart';

void main() {
  group('Inlay Parser', () {
    final inlay = Inlay();
    final marker = Marker.dart();

    test('Parse single rule', () {
      const content = '''
library;

// inlay template=dart-part mask=*.dart
// GENERATED
part 'foo.dart';
// inlay

String foo() => 'foo';
''';

      final rules = inlay.parse(content: content, marker: marker);

      expect(rules, hasLength(1));
      expect(rules.first.mask, '*.dart');
      expect(rules.first.template, 'dart-part');
    });

    test('Parse multiple rules', () {
      const content = '''
// inlay template=t1 mask=m1
old1
// inlay

// inlay template=t2 mask=m2
old2
// inlay
''';

      final rules = inlay.parse(content: content, marker: marker);

      expect(rules, hasLength(2));

      expect(rules[0].template, 't1');
      expect(rules[0].mask, 'm1');

      expect(rules[1].template, 't2');
      expect(rules[1].mask, 'm2');
    });

    test('Parse rules with extra spaces in params', () {
      const content = '''
// inlay template = dart-export   mask = models/*.dart 
export 'user.dart';
// inlay
''';

      final rules = inlay.parse(content: content, marker: marker);

      expect(rules, hasLength(1));
      expect(rules.first.template, 'dart-export');
      expect(rules.first.mask, 'models/*.dart');
    });

    test('Ignore incomplete markers', () {
      const content = '''
// inlay template=t1 mask=m1
// missing closing tag
''';
      final rules = inlay.parse(content: content, marker: marker);
      expect(rules, isEmpty);
    });

    test('Ignore markers missing required params', () {
      const content = '''
// inlay template=t1
content
// inlay
''';
      final rules = inlay.parse(content: content, marker: marker);
      expect(rules, isEmpty);
    });
  });

  group('Rule Replacement', () {
    final marker = Marker.dart();

    test('Replace content in rule', () {
      const content = 'PRE\n// inlay template=t mask=m\nOLD\n// inlay\nPOST';
      final rule = Rule(mask: 'm', template: 't', start: 4, end: 35);

      final result = rule.replace(
        content: content,
        template: "NEW: {{#files}}{{.}}{{/files}}",
        marker: marker,
        files: ['a.dart'],
      );

      expect(result, contains('NEW: a.dart'));
      expect(result, startsWith('PRE\n'));
      expect(result, endsWith('\nPOST'));
    });
  });
}
