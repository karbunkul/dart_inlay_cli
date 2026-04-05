import 'dart:io';
import 'package:inlay/inlay.dart';

final class Inlay {
  Rule? parseFile({required File file, required Marker marker}) {
    final matches = marker.pattern().allMatches(file.readAsStringSync());

    if (matches.length == 2) {
      final start = matches.first.start;
      final first = matches.first.group(1)!.trim();
      final second = matches.last.group(0)!;
      final between = matches.last.start - matches.first.end;

      final pattern = RegExp(
        r'(template|mask)\s?=\s{0}(.[^\s;]*)',
        multiLine: true,
      );
      final paramMatches = pattern.allMatches(first);
      final params = paramMatches.fold({}, (prev, match) {
        final key = match.group(1)?.trim();
        final value = match.group(2)?.trim();

        if (key?.isNotEmpty == true && value?.isNotEmpty == true) {
          prev.putIfAbsent(key, () => value);
        }

        return prev;
      });

      if (params['template'] == null || params['mask'] == null) {
        throw ArgumentError('template and mask are required');
      }

      return Rule(
        mask: params['mask']!,
        template: params['template']!,
        start: start,
        end: between + matches.first.end + second.length,
      );
    }

    return null;
  }
}
