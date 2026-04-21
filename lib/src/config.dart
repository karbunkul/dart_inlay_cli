import 'package:inlay/inlay.dart';

final class Config {
  final Map<String, Template> _templates;
  final List<String> scopes;
  final List<String> exclude;

  // Analyze settings
  final List<String> analyzeKeywords;
  final List<String> analyzeExtensions;
  final int? analyzeDepth;
  final bool isUsingDefaultAnalyzeConfig;

  Config({
    required List<Template> templates,
    required this.scopes,
    this.exclude = const [],
    this.analyzeKeywords = const [],
    this.analyzeExtensions = const ['dart'],
    this.analyzeDepth,
    this.isUsingDefaultAnalyzeConfig = true,
  }) : _templates = {for (final b in templates) b.name: b};

  bool hasTemplate(String name) => _templates.containsKey(name);
  Template? template(String name) => _templates[name];
}

final class Template {
  final String name;
  final String template;
  final Marker marker;

  Template({required this.name, required this.template, required this.marker});

  factory Template.dartPart() {
    return Template(
      name: 'dart-part',
      template: '''{{#files}}part '{{{ . }}}';\n{{/files}}\n\n''',
      marker: Marker.dart(),
    );
  }

  factory Template.dartExport() {
    return Template(
      name: 'dart-export',
      template: '''{{#files}}export '{{{ . }}}';\n{{/files}}\n\n''',
      marker: Marker.dart(),
    );
  }
}
