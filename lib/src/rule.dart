import 'dart:io';

import 'package:inlay/inlay.dart';
import 'package:mustache_template/mustache.dart' as m;

final class Rule {
  final String mask;
  final String template;
  final int start;
  final int end;

  const Rule({
    required this.mask,
    required this.template,
    required this.start,
    required this.end,
  });

  String replace({
    required String content,
    required String template,
    required Marker marker,
    required List<String> files,
  }) {
    final tmpl = m.Template(template);

    final replacement = StringBuffer();

    replacement.write(marker.toCommentTag(template: this.template, mask: mask));
    replacement.write('\n');
    if (!marker.block) {
      replacement.write(
        '${marker.start} GENERATED CODE - DO NOT MODIFY BY HAND',
      );
      replacement.write('\n');
    }
    replacement.write(tmpl.renderString({'files': files}));
    replacement.write(marker.toCommentTag());

    return content.replaceRange(start, end, replacement.toString());
  }
}
