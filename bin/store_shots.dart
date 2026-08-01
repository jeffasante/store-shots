import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:store_shots/src/runner.dart';
import 'package:store_shots/src/store_specs.dart';
import 'package:store_shots/src/verify.dart';

Future<void> main(List<String> arguments) async {
  final runner =
      CommandRunner<int>('store_shots', 'Capture and verify store screenshots.')
        ..addCommand(CaptureCommand())
        ..addCommand(VerifyCommand())
        ..addCommand(SpecsCommand());

  try {
    exitCode = await runner.run(arguments) ?? 0;
  } on UsageException catch (error) {
    stderr.writeln(error);
    exitCode = 64;
  } on FileSystemException catch (error) {
    stderr.writeln('${error.message}: ${error.path}');
    exitCode = 66;
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    exitCode = 65;
  }
}

class CaptureCommand extends Command<int> {
  CaptureCommand() {
    argParser
      ..addOption(
        'config',
        abbr: 'c',
        defaultsTo: ShotConfig.defaultPath,
        help: 'Path to the config file.',
      )
      ..addMultiOption(
        'only',
        abbr: 'o',
        help: 'Capture just these target ids. Repeatable.',
      )
      ..addFlag(
        'verify',
        defaultsTo: true,
        help: 'Check dimensions and duplicates after capturing.',
      )
      ..addFlag(
        'dry-run',
        negatable: false,
        help: 'Print the commands without running them.',
      );
  }

  @override
  String get name => 'capture';

  @override
  String get description => 'Capture screenshots for every configured device.';

  @override
  Future<int> run() async {
    final args = argResults!;
    final config = ShotConfig.load(File(args.option('config')!));

    final failures = await runCaptures(
      config,
      only: args.multiOption('only').toSet(),
      dryRun: args.flag('dry-run'),
    );

    if (failures.isNotEmpty) {
      stderr.writeln('\nFailed: ${failures.join(', ')}');
      return 1;
    }
    if (args.flag('dry-run') || !args.flag('verify')) return 0;

    stdout.writeln();
    final reports = await verify(Directory(config.output));
    return printReports(reports, useColour: stdout.supportsAnsiEscapes) ? 0 : 1;
  }
}

class VerifyCommand extends Command<int> {
  VerifyCommand() {
    argParser
      ..addOption(
        'path',
        abbr: 'p',
        defaultsTo: 'screenshots',
        help: 'Folder holding the per-platform screenshot folders.',
      )
      ..addFlag(
        'json',
        negatable: false,
        help: 'Emit JSON instead of a table.',
      );
  }

  @override
  String get name => 'verify';

  @override
  String get description =>
      'Check screenshot dimensions, duplicates, and store slots.';

  @override
  Future<int> run() async {
    final reports = await verify(Directory(argResults!.option('path')!));

    if (argResults!.flag('json')) {
      stdout.writeln(reportsAsJson(reports));
      return reports.every((r) => r.ok) ? 0 : 1;
    }
    return printReports(reports, useColour: stdout.supportsAnsiEscapes) ? 0 : 1;
  }
}

class SpecsCommand extends Command<int> {
  @override
  String get name => 'specs';

  @override
  String get description => 'List known store slots and their sizes.';

  @override
  Future<int> run() async {
    var store = '';
    for (final spec in kStoreSpecs) {
      if (spec.store != store) {
        store = spec.store;
        stdout.writeln('\n$store');
      }
      stdout.writeln(
        '  ${spec.id.padRight(15)} ${spec.sizeSummary.padRight(26)} '
        '${spec.slot}${spec.required ? ' (required)' : ''}',
      );
      if (spec.note != null) {
        stdout.writeln('  ${' '.padRight(15)} ${spec.note}');
      }
    }
    return 0;
  }
}
