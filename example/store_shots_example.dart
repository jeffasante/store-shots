import 'dart:io';

import 'package:store_shots/store_shots.dart';

void main() {
  for (final spec in kStoreSpecs) {
    final requirement = spec.required ? 'required' : 'optional';
    stdout.writeln('${spec.id}: ${spec.sizeSummary} ($requirement)');
  }
}
