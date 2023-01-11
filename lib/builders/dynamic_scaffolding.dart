import 'dart:async';
import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:build/build.dart';
import 'package:mason/mason.dart';

class DynamicScaffolding extends Builder {
  @override
  FutureOr<void> build(BuildStep buildStep) async {
    log.info(lightGreen.wrap(
        ' 🧱 Generating scaffold for ${buildStep.inputId.pathSegments.last}\n'));
    final scaffoldId = buildStep.inputId.changeExtension('.scaffold.dart');
    final domainSrc = await buildStep.readAsString(buildStep.inputId);
    final domainInfo = await _parseDomainInfo(domainSrc);
    log.info(lightGreen.wrap(
        '🔎 Found Domain Object ${domainInfo.name} with the fields: ${domainInfo.fields.map((e) => e.name)}\n'));

    final files = await _generate(buildStep.inputId.package, domainInfo);
    log.info(lightGreen.wrap(' 🧱 Generated scaffold files now bundling\n'));
    buildStep.writeAsString(
        scaffoldId, _bundle(buildStep.inputId.package, files));
    log.info(lightGreen.wrap(' ✅ Bundled into $scaffoldId\n'));
  }

  @override
  Map<String, List<String>> get buildExtensions => {
        '.dart': ['.scaffold.dart']
      };

  Future<_DomainInfo> _parseDomainInfo(String domainSource) async {
    ParseStringResult result = parseString(
      content: domainSource,
      featureSet: FeatureSet.latestLanguageVersion(),
    );
    AstNode root = result.unit.root;
    final classes = root.childEntities.whereType<ClassDeclaration>();
    if (classes.length != 1) {
      throw Exception(
          'A domain class must have a single class definition I found ${classes.length}');
    }

    final cl = classes.first;
    final List<_Property> fields = [];
    for (final f in cl.childEntities.whereType<FieldDeclaration>()) {
      VariableDeclarationList vdl = f.fields;
      for (VariableDeclaration v in vdl.variables) {
        log.info(lightGray.wrap('Looking at $v'));

        fields.add(
          _Property(
              name: v.name2.toString(),
              type: vdl.type.toString(),
              defaultValue: v.initializer!.toString()),
        );
      }
    }
    return _DomainInfo(
      name: cl.name2.value().toString(),
      fields: fields,
    );
  }

  Future<Iterable<File>> _generate(String packageName, _DomainInfo info) async {
    final workdir =
        Directory('${Directory.systemTemp.path}/scaffolding_${DateTime.now()}');
    workdir.createSync();
    final brick = Brick.git(GitPath('https://github.com/sjhorn/mason_bricks',
        path: 'bricks/scaffolding'));
    final generator = await MasonGenerator.fromBrick(brick);
    final target = DirectoryGeneratorTarget(workdir);
    final logger = Logger(level: Level.verbose);
    final generatedFiles = await generator.generate(
      target,
      vars: <String, dynamic>{
        'package': packageName,
        'feature': info.name.snakeCase,
        'properties': info.fields.map((e) => e.toMap())
      },
      fileConflictResolution: FileConflictResolution.overwrite,
      logger: logger,
    );
    final homeBrick = Brick.git(GitPath(
        'https://github.com/sjhorn/mason_bricks',
        path: 'bricks/scaffolding_home'));
    final homeGenerator = await MasonGenerator.fromBrick(homeBrick);
    final generatedFiles2 = await homeGenerator.generate(
      target,
      vars: <String, dynamic>{
        'package': packageName,
        'features': [info.name.snakeCase],
      },
      fileConflictResolution: FileConflictResolution.overwrite,
      logger: logger,
    );

    return [...generatedFiles, ...generatedFiles2].map((e) => File(e.path));
  }

  Future<String> _bundle(String packageName, Iterable<File> files) async {
    StringBuffer buffer = StringBuffer();
    final importsRE = RegExp(r'^\s*(import.*;)\s*$', multiLine: true);
    final removeExports = RegExp(r'^\s*export.*$', multiLine: true);
    final removeParts = RegExp(r'^\s*part.*$', multiLine: true);
    final Set<String> importSet = {};

    for (final f in files) {
      final file = File(f.path);

      // ignore dot files
      if (file.uri.pathSegments.last.startsWith('.')) {
        continue;
      }

      log.fine(lightGray.wrap('📂 Reading ${file.uri.pathSegments.last}\n'));
      final fileString = file.readAsStringSync();
      importSet.addAll(
        importsRE.allMatches(fileString).map((e) => e.group(1)!.trim()),
      );
      buffer.write(
        fileString
            .replaceAll(importsRE, '')
            .replaceAll(removeExports, '')
            .replaceAll(removeParts, '')
            .trim(),
      );
      buffer.write('\n');
    }
    importSet.removeWhere((element) =>
        element.startsWith("import 'package:$packageName/") ||
        element.startsWith("import 'scaffold_app.dart';"));
    final importList = importSet.toList();
    importList.sort();

    return '''${importList.join('\n')}

${buffer.toString()}
''';
  }
}

class _DomainInfo {
  final String name;
  final Iterable<_Property> fields;
  _DomainInfo({
    required this.name,
    required this.fields,
  });
}

class _Property {
  final String name;
  final String type;
  String defaultValue;
  late final dynamic emptyValue;
  late final dynamic testValue;

  _Property({
    required this.name,
    required this.type,
    required this.defaultValue,
  }) {
    switch (type) {
      case 'String':
        emptyValue = "''";
        testValue = "'testString'";
        break;
      case 'int':
      case 'double':
        emptyValue = 0;
        testValue = 1;
        break;
      case 'bool':
        emptyValue = false;
        testValue = true;
        break;
      default:
        throw Exception('Unsupported type for property');
    }
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'type': type,
        'defaultValue': defaultValue,
        'emptyValue': emptyValue,
        'testValue': testValue,
      };
}
