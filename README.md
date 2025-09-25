# Flutter Quill Integration in NoteStack

NoteStack uses [Flutter Quill](https://pub.dev/packages/flutter_quill) as its rich text editor for modern Android, iOS, web, and desktop platforms.

## 📦 Installation

Add the dependency in your `pubspec.yaml`:

```yaml
dependencies:
  flutter_quill: ^11.4.2
```

Then run:

```
flutter pub get
```

## 🛠 Platform Setup

### Android (Optional: For image clipboard sharing)

1. In `android/app/src/main/AndroidManifest.xml`, inside `<application>`, add:

```xml
<provider
    android:name="androidx.core.content.FileProvider"
    android:authorities="${applicationId}.fileprovider"
    android:exported="false"
    android:grantUriPermissions="true" >
    <meta-data
        android:name="android.support.FILE_PROVIDER_PATHS"
        android:resource="@xml/file_paths" />
</provider>
```

2. Create `android/app/src/main/res/xml/file_paths.xml`:

```xml
<paths>
    <cache-path name="cache" path="." />
</paths>
```

## 🚀 Usage

### Localization

Add the following to your `MaterialApp`:

```dart
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

MaterialApp(
  localizationsDelegates: const [
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    FlutterQuillLocalizations.delegate,
  ],
  supportedLocales: const [
    Locale('en'),
    // Add more locales as needed
  ],
);
```

### Editor Example

```dart
final QuillController _controller = QuillController.basic();

QuillSimpleToolbar(
  controller: _controller,
  config: const QuillSimpleToolbarConfig(),
),
Expanded(
  child: QuillEditor.basic(
    controller: _controller,
    config: const QuillEditorConfig(),
  ),
)
```

### Saving and Loading Content

```dart
// Save
final String json = jsonEncode(_controller.document.toDelta().toJson());

// Load
_controller.document = Document.fromJson(jsonDecode(json));
```

## 📝 Changelog
See [CHANGELOG.md](CHANGELOG.md) for version history.

## 📜 License
MIT

