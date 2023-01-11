import 'dart:io';
import 'package:mason/mason.dart';

Future<void> main() async {
  final logger = Logger(level: Level.verbose);
  logger.info('Starting');
  final brick = Brick.path('../../mason/scaffold_domain');
  final generator = await MasonGenerator.fromBrick(brick);
  final workdir = Directory.current;
  final target = DirectoryGeneratorTarget(workdir);
  final vars = <String, dynamic>{
    'package': 'scaffolding',
    'feature': 'todo',
    'properties': "String name|'scott',String name2|'catherine'",
  };
  Map<String, dynamic>? updatedVars;
  await generator.hooks.preGen(
    vars: vars,
    workingDirectory: workdir.path,
    logger: logger,
    onVarsChanged: (vars) => updatedVars = vars,
  );

  await generator.generate(
    target,
    vars: updatedVars ?? vars,
    fileConflictResolution: FileConflictResolution.overwrite,
    logger: logger,
  );
  await generator.hooks.postGen(
    vars: updatedVars ?? vars,
    workingDirectory: workdir.path,
    logger: logger,
  );
  logger.flush((message) => logger.info(darkGray.wrap(message)));
  logger.info('Done');
}
