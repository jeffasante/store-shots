import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

import 'capture.dart';

/// Default folder screenshots are written to, relative to the project root.
const String kDefaultOutputRoot = 'screenshots';

/// Runs the integration driver and writes every captured frame to disk.
///
/// Use as the whole body of `test_driver/store_shots_test.dart`:
///
/// ```dart
/// import 'package:store_shots/driver.dart';
///
/// Future<void> main() => storeShotsDriver();
/// ```
///
/// The output folder is `<root>/<platform>`, where platform comes from the
/// `SHOT_PLATFORM` environment variable so one driver serves every device:
///
/// ```sh
/// SHOT_PLATFORM=ios-6.9 flutter drive \
///   --driver=test_driver/store_shots_test.dart \
///   --target=integration_test/store_shots_test.dart \
///   -d <device-id>
/// ```
Future<void> storeShotsDriver({
  String root = kDefaultOutputRoot,
  String fallbackPlatform = 'device',
}) async {
  final platform = Platform.environment['SHOT_PLATFORM'] ?? fallbackPlatform;
  final directory = Directory('$root/$platform');

  Future<void> write(String name, List<int> bytes) async {
    await directory.create(recursive: true);
    await File('${directory.path}/$name.png').writeAsBytes(bytes);
    stdout.writeln('  saved ${directory.path}/$name.png');
  }

  await integrationDriver(
    onScreenshot: (name, bytes, [args]) async {
      await write(name, bytes);
      return true;
    },
    // Frames that the test rasterised itself arrive here instead, base64
    // encoded, because their embedder has no native screenshot channel.
    responseDataCallback: (data) async {
      final shots = data?[kStoreShotsReportKey] as Map<String, dynamic>?;
      if (shots == null) return;
      for (final entry in shots.entries) {
        await write(entry.key, base64Decode(entry.value as String));
      }
    },
  );
}
