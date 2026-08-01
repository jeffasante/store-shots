import 'dart:io';

import 'package:yaml/yaml.dart';

/// One device to capture, as declared in `store_shots.yaml`.
class ShotTarget {
  ShotTarget({
    required this.id,
    required this.device,
    this.windowSize,
    this.reboot = true,
  });

  /// Output folder name, matched against the store specs, e.g. `ios-6.9`.
  final String id;

  /// Flutter device id, a simulator UDID, or `macos`.
  final String device;

  /// Desired window size for desktop targets, e.g. `2880x1800`.
  final String? windowSize;

  /// Whether to reboot the simulator before capturing.
  final bool reboot;

  /// True when [device] looks like a simulator UDID rather than an alias.
  bool get isSimulator => RegExp(
        r'^[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}$',
        caseSensitive: false,
      ).hasMatch(device);
}

/// Config loaded from `store_shots.yaml` in the project root.
class ShotConfig {
  ShotConfig({
    required this.targets,
    required this.output,
    required this.driver,
    required this.target,
  });

  final List<ShotTarget> targets;
  final String output;
  final String driver;
  final String target;

  static const String defaultPath = 'store_shots.yaml';

  static ShotConfig load(File file) {
    if (!file.existsSync()) {
      throw FileSystemException('Config not found', file.path);
    }
    final yaml = loadYaml(file.readAsStringSync());
    if (yaml is! Map) {
      throw const FormatException('store_shots.yaml must be a map.');
    }

    final rawTargets = yaml['targets'];
    if (rawTargets is! List || rawTargets.isEmpty) {
      throw const FormatException(
        'store_shots.yaml needs a non-empty "targets" list.',
      );
    }

    return ShotConfig(
      output: (yaml['output'] as String?) ?? 'screenshots',
      driver:
          (yaml['driver'] as String?) ?? 'test_driver/store_shots_test.dart',
      target: (yaml['target'] as String?) ??
          'integration_test/store_shots_test.dart',
      targets: [
        for (final entry in rawTargets)
          ShotTarget(
            id: entry['id'] as String,
            device: entry['device'] as String,
            windowSize: entry['window_size'] as String?,
            reboot: (entry['reboot'] as bool?) ?? true,
          ),
      ],
    );
  }
}

/// Captures every target in [config], or only those whose id is in [only].
///
/// Returns the ids that failed.
Future<List<String>> runCaptures(
  ShotConfig config, {
  Set<String> only = const {},
  bool dryRun = false,
}) async {
  final selected = only.isEmpty
      ? config.targets
      : config.targets.where((t) => only.contains(t.id)).toList();

  if (selected.isEmpty) {
    throw ArgumentError('No targets matched ${only.join(', ')}.');
  }

  final failures = <String>[];

  for (final target in selected) {
    stdout.writeln('\n▸ ${target.id}  (${target.device})');

    if (target.reboot && target.isSimulator) {
      // A simulator that has been up for a while hands back a stale graphics
      // surface and every capture comes out blank white. Rebooting is the only
      // reliable fix, and it is cheap next to the build.
      stdout.writeln('  rebooting simulator');
      if (!dryRun) await _rebootSimulator(target.device);
    }

    final environment = <String, String>{
      'SHOT_PLATFORM': target.id,
      if (target.windowSize != null) 'STORE_SHOTS_WINDOW': target.windowSize!,
    };

    final arguments = <String>[
      'drive',
      '--driver=${config.driver}',
      '--target=${config.target}',
      '-d',
      target.device,
    ];

    stdout.writeln('  flutter ${arguments.join(' ')}');
    if (dryRun) continue;

    final process = await Process.start(
      'flutter',
      arguments,
      environment: environment,
      mode: ProcessStartMode.inheritStdio,
    );
    if (await process.exitCode != 0) {
      stdout.writeln('  capture failed');
      failures.add(target.id);
    }
  }

  return failures;
}

Future<void> _rebootSimulator(String udid) async {
  await Process.run('xcrun', ['simctl', 'shutdown', udid]);
  await Process.run('xcrun', ['simctl', 'boot', udid]);
  await Process.run('xcrun', ['simctl', 'bootstatus', udid, '-b']);
}
