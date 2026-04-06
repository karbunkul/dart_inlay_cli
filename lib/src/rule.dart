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
    required File file,
    required String template,
    required Marker marker,
    required List<String> files,
  }) {
    final value = file.readAsStringSync();
    final tmpl = m.Template(template);

    final content = StringBuffer();

    content.write(marker.toCommentTag(template: this.template, mask: mask));
    content.write('\n');
    if (!marker.block) {
      content.write('${marker.start} GENERATED CODE - DO NOT MODIFY BY HAND');
      content.write('\n');
    }
    content.write(tmpl.renderString({'files': files}));
    content.write(marker.toCommentTag());

    final newContent = value.replaceFirst(
      value.substring(start, end),
      content.toString(),
    );

    return newContent.toString();
  }
}
