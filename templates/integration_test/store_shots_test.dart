// Copy to integration_test/store_shots_test.dart and edit the walkthrough
// below to match your app's screens.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:store_shots/store_shots.dart';

// import 'package:your_app/main.dart' as app;

void main() {
  final shots = StoreShots.ensureInitialized();

  setUp(() async {
    // Seed state here so the shots show a populated app rather than an empty
    // first run, e.g. SharedPreferences.setMockInitialValues({...}).
  });

  testWidgets('store screenshots', (tester) async {
    // Before the app's first frame, or captures come back blank on mobile.
    await shots.prepare();

    // app.main();
    await tester.pumpAndSettle(const Duration(seconds: 2));

    await shots.capture(tester, '01-home');

    // Guard each step so a missing screen skips rather than fails the run.
    if (await tester.tapIfPresent(find.byIcon(Icons.search))) {
      await shots.capture(tester, '02-search');
      await tester.popRoute();
    }

    if (await tester.tapIfPresent(find.byTooltip('Settings'))) {
      await shots.capture(tester, '03-settings');
      await tester.popRoute();
    }

    // Sends locally rasterised frames to the driver. Always call last.
    shots.publish();
  });
}
