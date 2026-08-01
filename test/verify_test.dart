import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:store_shots/src/png.dart';
import 'package:store_shots/src/store_specs.dart';
import 'package:store_shots/src/verify.dart';

/// Builds a PNG whose IHDR reports [width] x [height].
///
/// The pixel data is not decoded by anything under test, so a header plus a
/// unique tail is enough to exercise both sizing and duplicate detection.
Uint8List fakePng(int width, int height, {int seed = 0}) {
  final bytes = BytesBuilder()
    ..add([137, 80, 78, 71, 13, 10, 26, 10])
    ..add([0, 0, 0, 13])
    ..add('IHDR'.codeUnits);

  final dimensions = ByteData(8)
    ..setUint32(0, width)
    ..setUint32(4, height);

  return (bytes
        ..add(dimensions.buffer.asUint8List())
        ..add([8, 6, 0, 0, 0])
        ..add(List<int>.filled(4, seed)))
      .takeBytes();
}

Future<Directory> folderWith(
  Directory root,
  String id,
  List<Uint8List> pngs,
) async {
  final folder = Directory('${root.path}/$id')..createSync(recursive: true);
  for (var i = 0; i < pngs.length; i++) {
    File('${folder.path}/0$i-shot.png').writeAsBytesSync(pngs[i]);
  }
  return folder;
}

void main() {
  late Directory root;

  setUp(() => root = Directory.systemTemp.createTempSync('store_shots'));
  tearDown(() => root.deleteSync(recursive: true));

  group('readPngSize', () {
    test('reads dimensions from the IHDR header', () async {
      final file = File('${root.path}/a.png')
        ..writeAsBytesSync(fakePng(1320, 2868));

      expect(await readPngSize(file), (width: 1320, height: 2868));
    });

    test('rejects a file that is not a PNG', () async {
      final file = File('${root.path}/a.png')
        ..writeAsBytesSync(Uint8List.fromList(List.filled(32, 42)));

      expect(readPngSize(file), throwsA(isA<FormatException>()));
    });
  });

  group('store specs', () {
    test('accepts a slot dimension in either orientation', () {
      final iphone = specFor('ios-6.9')!;

      expect(iphone.accepts(1320, 2868), isTrue);
      expect(iphone.accepts(2868, 1320), isTrue);
      expect(iphone.accepts(1284, 2778), isFalse);
    });

    test('every spec id is unique', () {
      final ids = kStoreSpecs.map((s) => s.id).toList();

      expect(ids.toSet(), hasLength(ids.length));
    });
  });

  group('verify', () {
    test('passes a folder with unique, correctly sized frames', () async {
      await folderWith(root, 'ios-6.9', [
        fakePng(1320, 2868, seed: 1),
        fakePng(1320, 2868, seed: 2),
      ]);

      final reports = await verify(root);

      expect(reports.single.ok, isTrue);
      expect(reports.single.uniqueCount, 2);
    });

    test('flags duplicate frames from stalled navigation', () async {
      await folderWith(root, 'ios-6.9', [
        fakePng(1320, 2868, seed: 1),
        fakePng(1320, 2868, seed: 1),
      ]);

      final reports = await verify(root);

      expect(reports.single.ok, isFalse);
      expect(reports.single.problems.single, contains('duplicate'));
    });

    test('flags dimensions the slot does not accept', () async {
      await folderWith(root, 'macos', [fakePng(1512, 982)]);

      final reports = await verify(root);

      expect(reports.single.problems.single, contains('not accepted'));
    });

    test('flags a folder holding more than one size', () async {
      await folderWith(root, 'ios-6.9', [
        fakePng(1320, 2868, seed: 1),
        fakePng(1284, 2778, seed: 2),
      ]);

      final reports = await verify(root);

      expect(
        reports.single.problems,
        contains(predicate<String>((p) => p.contains('mixed dimensions'))),
      );
    });

    test('reports an unknown folder without checking its size', () async {
      await folderWith(root, 'mystery', [fakePng(100, 100)]);

      expect((await verify(root)).single.problems.single, contains('unknown'));
    });

    test('throws when the root does not exist', () {
      expect(
        verify(Directory('${root.path}/missing')),
        throwsA(isA<FileSystemException>()),
      );
    });
  });
}
