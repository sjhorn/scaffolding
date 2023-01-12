
<p align="center">
<img src="https://raw.githubusercontent.com/sjhorn/scaffolding/master/assets/scaffolding_full.png" height="125" alt="mason logo" />
</p>

Scaffolding - a builder tool based on build_runner and mason for dynamically scaffolding a flutter application.

`package:scaffolding` contains the dynamic_scaffolding builder and a command line runner for static scaffolding (this uses [package:mason_cli](https://pub.dev/packages/mason_cli) behind the scenes).

### Screenshots

![home screenshot](https://raw.githubusercontent.com/sjhorn/scaffolding/master/assets/home.png)
![read screenshot](https://raw.githubusercontent.com/sjhorn/scaffolding/master/assets/read.png)


Create a template in /lib/features/contact.dart
```dart
abstract class Contact {
    String firstname = 'Scott';
    String lastname = 'Horn';
    int age = 21; // :)
    bool favourite = true;
}
```

Ensure the scaffolding plugin is installed

```flutter pub install scaffolding```

Add the following to your build.yaml in the root of your project

```
targets:
  $default:
    builders:
      scaffolding|dynamicBuilder:
        generate_for: [lib/features/*.dart]
        enabled: true
```

You can then run build_runner once off `flutter pub run build_runner build` or in watch mode `flutter pub run build_runner watch`

Afterwards call the resulting scaffolded main in your main.dart file

```dart
import 'features/contact.scaffold.dart' as scaffold;

void main(List<String> args) => scaffold.main(args);


```