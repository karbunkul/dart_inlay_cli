# 💎 Inlay: Smart Code Incrustation Tool
**Inlay** is a precision surgical tool for your codebase. It automates the maintenance of "barrel files" (exports), index files, and part-of connections. Instead of manually writing export or part lines every time you add a file, Inlay does it for you based on smart, declarative rules.

## 🚀 Key Features
* **Bidirectional Sync:** Scans your filesystem and updates index blocks automatically.
* **Template-Driven:** Built-in presets for dart-export, dart-part, or custom formatting.
* **Glob-Pattern Precision:** Supports standard and deep-nesting masks (e.g., */*_page.dart or **/*.dart).

## 🛠️ How It Works
Insert a special comment block into your index file (e.g., lib/src/pages/pages.dart):

```dart
// inlay template=dart-export mask=/_page.dart
// GENERATED CODE - DO NOT MODIFY BY HAND
export 'login/login_page.dart';
export 'settings/settings_page.dart';

// inlay
```

### Parameters:

* **template:** The formatting rule for the generated line.
  * **dart-export** -> export 'path/file.dart';
  * **dart-part** -> part 'file.dart';

* **mask:** The Glob pattern to find target files.
  * **\*/\*_page.dart:** Look exactly one level deep (Folder/File_page.dart).
  * ****/*.dart:** Recursive search through all subdirectories.

## 🏗️ Integration with Foreman
Inlay shines brightest as an after-hook in the Foreman ecosystem. When you generate a new "brick" (feature, page, or component), Inlay instantly detects it and wires it into the rest of the application.

## Conclusion 💎

Inlay is about architectural discipline and financial common sense. Stop fighting with imports and start building.