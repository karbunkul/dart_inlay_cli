final class Marker {
  final String start;
  final String end;
  final bool block;

  Marker({required this.start, required this.end, this.block = false});

  RegExp pattern() {
    if (block) {
      return RegExp(
        '${RegExp.escape(start)}\\s*inlay(.*)${RegExp.escape(end)}',
        multiLine: true,
      );
    } else {
      return RegExp(
        '^.*${RegExp.escape(start)}\\s*inlay(.*)\$',
        multiLine: true,
      );
    }
  }

  String toCommentTag({String? template, String? mask}) {
    final res = StringBuffer();

    res.write('$start inlay');
    if (template != null && mask != null) {
      res.write(' template=$template mask=$mask');
    }

    if (block) {
      res.write(' $end');
    }

    return res.toString();
  }

  factory Marker.dart() => Marker(start: '//', end: '//');
  factory Marker.html() => Marker(start: '<!--', end: '-->', block: true);
  factory Marker.python() => Marker(start: '#', end: '#');
}
