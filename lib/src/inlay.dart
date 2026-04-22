import 'dart:io';
import 'package:inlay/inlay.dart';

final class Inlay {
  List<Rule> parse({required String content, required Marker marker}) {
    final matches = marker.pattern().allMatches(content).toList();
    final rules = <Rule>[];

    for (var i = 0; i < matches.length; i += 2) {
      if (i + 1 >= matches.length) break;

      final openingMatch = matches[i];
      final closingMatch = matches[i + 1];

      final startOffset = openingMatch.start;
      final firstContent = openingMatch.group(1)!.trim();
      final endOffset = closingMatch.end;

      final pattern = RegExp(
        r'(template|mask|tag)\s?=\s{0}(.[^\s;]*)',
        multiLine: true,
      );
      final paramMatches = pattern.allMatches(firstContent);
      final params = paramMatches.fold(<String, String>{}, (prev, match) {
        final key = match.group(1)?.trim();
        final value = match.group(2)?.trim();

        if (key?.isNotEmpty == true && value?.isNotEmpty == true) {
          prev.putIfAbsent(key!, () => value!);
        }

        return prev;
      });

      if (params['template'] != null && params['mask'] != null) {
        rules.add(
          Rule(
            mask: params['mask']!,
            template: params['template']!,
            tag: params['tag'],
            start: startOffset,
            end: endOffset,
          ),
        );
      }
    }

    return rules;
  }
}
