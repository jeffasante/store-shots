import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:store_shots/src/runner.dart';

void main() {
  late Directory root;

  setUp(() => root = Directory.systemTemp.createTempSync('store_shots_cfg'));
  tearDown(() => root.deleteSync(recursive: true));

  File configWith(String body) =>
      File('${root.path}/store_shots.yaml')..writeAsStringSync(body);

  test('loads targets and applies defaults', () {
    final config = ShotConfig.load(
      configWith('''
targets:
  - id: ios-6.9
    device: ABC
  - id: macos
    device: macos
    window_size: 2880x1800
    reboot: false
'''),
    );

    expect(config.output, 'screenshots');
    expect(config.driver, 'test_driver/store_shots_test.dart');
    expect(config.targets, hasLength(2));
    expect(config.targets.first.reboot, isTrue);
    expect(config.targets.last.windowSize, '2880x1800');
    expect(config.targets.last.reboot, isFalse);
  });

  test('honours an explicit output folder', () {
    final config = ShotConfig.load(
      configWith('''
output: artifacts/app-store
targets:
  - id: macos
    device: macos
'''),
    );

    expect(config.output, 'artifacts/app-store');
  });

  test('rejects a config with no targets', () {
    expect(
      () => ShotConfig.load(configWith('output: shots\n')),
      throwsA(isA<FormatException>()),
    );
  });

  test('reports a missing config file', () {
    expect(
      () => ShotConfig.load(File('${root.path}/nope.yaml')),
      throwsA(isA<FileSystemException>()),
    );
  });

  group('ShotTarget', () {
    test('recognises a simulator UDID', () {
      final target = ShotTarget(
        id: 'ios-6.9',
        device: 'A1B2C3D4-1234-5678-9ABC-DEF012345678',
      );

      expect(target.isSimulator, isTrue);
    });

    test('treats a device alias as not a simulator', () {
      expect(ShotTarget(id: 'macos', device: 'macos').isSimulator, isFalse);
      expect(
        ShotTarget(id: 'android', device: 'emulator-5554').isSimulator,
        isFalse,
      );
    });
  });
}
