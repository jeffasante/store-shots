import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'png.dart';
import 'store_specs.dart';

/// Outcome of checking one platform folder.
class FolderReport {
  FolderReport(this.id, this.spec);

  final String id;
  final StoreSpec? spec;

  final List<String> problems = <String>[];
  int fileCount = 0;
  int uniqueCount = 0;
  PngSize? size;

  bool get ok => problems.isEmpty;
}

/// Checks each platform folder under [root] for the mistakes that only surface
/// after an upload is rejected.
///
/// Three things go wrong in practice:
///
/// * Dimensions that no store slot accepts.
/// * Mixed dimensions inside one folder, from a device switch mid-run.
/// * Duplicate frames, which means navigation stalled and the same screen was
///   captured repeatedly. This is the failure that is easiest to miss by eye.
Future<List<FolderReport>> verify(Directory root) async {
  if (!root.existsSync()) {
    throw FileSystemException('No screenshot folder found', root.path);
  }

  final folders = root.listSync().whereType<Directory>().toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  if (folders.isEmpty) {
    throw FileSystemException('No platform folders inside', root.path);
  }

  final reports = <FolderReport>[];

  for (final folder in folders) {
    final id = folder.uri.pathSegments.where((s) => s.isNotEmpty).last;
    final report = FolderReport(id, specFor(id));

    final pngs = folder
        .listSync()
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith('.png'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    report.fileCount = pngs.length;
    if (pngs.isEmpty) {
      report.problems.add('no PNGs');
      reports.add(report);
      continue;
    }

    final digests = <String>{};
    final sizes = <String>{};

    for (final png in pngs) {
      digests.add(md5.convert(await png.readAsBytes()).toString());

      final size = await readPngSize(png);
      report.size ??= size;
      sizes.add('${size.width}x${size.height}');
    }

    report.uniqueCount = digests.length;

    if (digests.length != pngs.length) {
      final dupes = pngs.length - digests.length;
      report.problems.add(
        '$dupes duplicate frame(s) — navigation probably stalled',
      );
    }
    if (sizes.length > 1) {
      report.problems.add('mixed dimensions: ${sizes.join(', ')}');
    }

    final spec = report.spec;
    final size = report.size;
    if (spec == null) {
      report.problems.add('unknown slot "$id" — dimensions not checked');
    } else if (size != null && !spec.accepts(size.width, size.height)) {
      report.problems.add(
        '${size.width}x${size.height} is not accepted for ${spec.slot} '
        '(needs ${spec.sizeSummary})',
      );
    }

    reports.add(report);
  }

  return reports;
}

/// Renders [reports] as a table. Returns true when every folder passed.
bool printReports(List<FolderReport> reports, {required bool useColour}) {
  String green(String s) => useColour ? '\u001b[32m$s\u001b[0m' : s;
  String red(String s) => useColour ? '\u001b[31m$s\u001b[0m' : s;
  String dim(String s) => useColour ? '\u001b[2m$s\u001b[0m' : s;

  final width =
      reports.fold<int>(6, (w, r) => r.id.length > w ? r.id.length : w);

  stdout.writeln(
    dim('  ${'FOLDER'.padRight(width)}  ${'SIZE'.padRight(11)}  FILES  SLOT'),
  );

  for (final report in reports) {
    final size = report.size == null
        ? '-'
        : '${report.size!.width}x${report.size!.height}';
    final files = report.uniqueCount == report.fileCount
        ? '${report.fileCount}'
        : '${report.uniqueCount}/${report.fileCount}';

    stdout.writeln(
      '${report.ok ? green('✓') : red('✗')} '
      '${report.id.padRight(width)}  '
      '${size.padRight(11)}  '
      '${files.padRight(5)}  '
      '${report.spec?.slot ?? dim('unknown')}',
    );
    for (final problem in report.problems) {
      stdout.writeln('  ${red('→')} $problem');
    }
  }

  final failed = reports.where((r) => !r.ok).length;
  stdout.writeln();
  if (failed == 0) {
    stdout.writeln(green('All ${reports.length} folder(s) ready to upload.'));
    return true;
  }
  stdout.writeln(red('$failed of ${reports.length} folder(s) need attention.'));
  return false;
}

/// Writes a JSON summary, for CI steps that want to consume the result.
String reportsAsJson(List<FolderReport> reports) {
  return const JsonEncoder.withIndent('  ').convert({
    'ok': reports.every((r) => r.ok),
    'folders': [
      for (final report in reports)
        {
          'id': report.id,
          'slot': report.spec?.slot,
          'store': report.spec?.store,
          'width': report.size?.width,
          'height': report.size?.height,
          'files': report.fileCount,
          'unique': report.uniqueCount,
          'problems': report.problems,
        },
    ],
  });
}
