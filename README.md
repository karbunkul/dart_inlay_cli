# 💎 Inlay: Smart Code Incrustation Tool

**Inlay** is a precision surgical tool for your codebase. It automates the maintenance of "barrel files" (exports), index files, and part-of connections. Instead of manually writing export or part lines every time you add a file, Inlay does it for you based on smart, declarative rules.

## 📖 Glossary

To better understand how Inlay works, here are the core concepts:

* **Marker**: A pair of special comments in your code (e.g., `// inlay ...` and `// inlay`) that define where the generated code should be placed.
* **Rule**: The logic defined within a **Marker** via parameters like `template` and `mask`. It tells Inlay *how* to format the code and *which* files to include.
* **Scope**: A path or glob pattern defined in `inlay.yaml`. Inlay only scans files that match these scopes. Scopes can be tagged for granular execution.
* **Template**: A predefined or custom format for generating lines (e.g., `dart-export`).

## 🚀 Key Features
* **Bidirectional Sync:** Scans your filesystem and updates index blocks automatically.
* **Smart Analysis:** Automatically suggests markers based on your project structure.
* **Scope Management:** Interactively manage which files are tracked by Inlay.
* **Template-Driven:** Built-in presets for `dart-export`, `dart-part`, or custom formatting.
* **Glob-Pattern Precision:** Supports standard and deep-nesting masks (e.g., `*/*_page.dart` or `**/*.dart`).

## 📦 Installation

```bash
dart pub global activate -sgit https://github.com/karbunkul/dart_inlay_cli.git
```

## 🛠️ CLI Commands

### `inlay init`
Initializes a new `inlay.yaml` configuration file in your project root.

### `inlay analyze`
Scans your project and suggests `inlay` markers based on detected file patterns.
* `--dir, -p`: Directory to analyze (default: current).
* `--depth, -d`: Maximum depth to scan (default: 2, max: 3).

### `inlay scope`
Inspects active scopes in the current directory and helps you add new ones interactively. It detects files with markers that are not yet covered by any scope in `inlay.yaml`.

### `inlay build`
The main engine. Scans files in your scopes and updates the generated code blocks.
* `--dry-run`: Preview changes without writing to files.
* `--file, -f`: Process a specific file instead of using configured scopes.
* `--tag, -t`: Filter by tags. Run `inlay build -t` without arguments to see an interactive selector.

## 🏷️ Tags & Performance
For large projects, you can group your scopes using tags in `inlay.yaml`. This allows Inlay to skip unnecessary file scanning.

### In `inlay.yaml`:
```yaml
scopes:
  - pattern: lib/api/*.dart
    tags: [network, api]
  - pattern: lib/models/*.dart
    tags: [models]
```

### In your code (optional):
You can also tag specific blocks inside a file to update only them:
```dart
// inlay template=dart-export mask=*.dart tag=api
```

Run only specific tags:
```bash
inlay build --tag network models
```

## ⚙️ Configuration (`inlay.yaml`)

```yaml
scopes:
  - lib/**.dart  # Glob patterns to scan for markers

exclude:
  - bin/**       # Patterns to ignore
  - .dart_tool/**

analyze:
  depth: 2       # Default depth for analysis
  keywords:      # Custom keywords to help find patterns (e.g. Page, Bloc, Entity)
    - Page
```

## 📝 How It Works

Insert special comment blocks into your index file. Inlay supports **multiple blocks** in a single file.

```dart
// inlay template=dart-export mask=models/*.dart
// GENERATED CODE - DO NOT MODIFY BY HAND
export 'models/user.dart';
export 'models/product.dart';

// inlay

// inlay template=dart-export mask=services/*.dart
// GENERATED CODE - DO NOT MODIFY BY HAND
export 'services/auth_service.dart';
export 'services/api_service.dart';

// inlay
```

### Parameters:

* **template:** The formatting rule for the generated line.
  * `dart-export` -> `export 'path/file.dart';`
  * `dart-part` -> `part 'file.dart';`

* **mask:** The Glob pattern to find target files.
  * `*/*_page.dart`: Look exactly one level deep (`Folder/File_page.dart`).
  * `**/*.dart`: Recursive search through all subdirectories.

* **tag:** (Optional) Filter tag to group generation blocks.

## 🏗️ Integration with Foreman
Inlay shines brightest as an after-hook in the Foreman ecosystem. When you generate a new "brick" (feature, page, or component), Inlay instantly detects it and wires it into the rest of the application.

## Conclusion 💎

Inlay is about architectural discipline and financial common sense. Stop fighting with imports and start building.
