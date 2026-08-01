import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// The report key the macOS frames travel under.
///
/// Deliberately not `screenshots`: `integrationDriver` reserves that key for a
/// `List` of `{bytes, screenshotName}` maps and will throw a cast error if it
/// finds a different shape there.
const String kStoreShotsReportKey = 'storeShots';

/// Captures screenshots of a running Flutter app for store listings.
///
/// Wraps the parts of [IntegrationTestWidgetsFlutterBinding] that behave
/// differently per platform:
///
/// * iOS and Android must convert the Flutter surface to an image *before* the
///   app renders its first frame, otherwise every capture comes back blank.
/// * macOS has no native `captureScreenshot` channel, so frames are rasterised
///   from the layer tree and passed to the driver through the report data.
///
/// ```dart
/// void main() {
///   final shots = StoreShots.ensureInitialized();
///
///   testWidgets('store screenshots', (tester) async {
///     await shots.prepare();
///     app.main();
///     await tester.pumpAndSettle();
///
///     await shots.capture(tester, '01-home');
///     await shots.publish();
///   });
/// }
/// ```
class StoreShots {
  StoreShots._(this.binding);

  /// Initialises the integration test binding and returns a recorder for it.
  factory StoreShots.ensureInitialized() {
    return StoreShots._(
      IntegrationTestWidgetsFlutterBinding.ensureInitialized(),
    );
  }

  final IntegrationTestWidgetsFlutterBinding binding;

  final Map<String, String> _rasterised = <String, String>{};

  /// Names captured so far, in order.
  final List<String> captured = <String>[];

  /// Whether this platform needs frames rasterised from the layer tree.
  static bool get rasterisesLocally => Platform.isMacOS;

  /// Prepares the engine for capture. Call before the app's `main()`.
  ///
  /// Converting the surface after the engine has started rendering yields
  /// all-white images, so ordering here is load-bearing.
  Future<void> prepare() async {
    if (Platform.isAndroid || Platform.isIOS) {
      await binding.convertFlutterSurfaceToImage();
    }
  }

  /// Settles the UI and captures the current frame as [name].
  ///
  /// [name] becomes the PNG filename, so prefix with an index to keep store
  /// listings in order, e.g. `01-home`.
  Future<void> capture(
    WidgetTester tester,
    String name, {
    Duration settle = const Duration(milliseconds: 600),
  }) async {
    await tester.pumpAndSettle(settle);

    if (rasterisesLocally) {
      _rasterised[name] = base64Encode(await _rasterise());
    } else {
      await binding.takeScreenshot(name);
    }
    captured.add(name);
  }

  Future<Uint8List> _rasterise() async {
    final view = binding.renderViews.first;
    final dpr = view.flutterView.devicePixelRatio;
    // The root layer's transform already scales into physical pixels, so the
    // bounds must be physical and the layer's own pixel ratio left at 1.
    final image = await (view.debugLayer! as OffsetLayer).toImage(
      Offset.zero & (view.size * dpr),
    );
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) {
        throw StateError('Could not encode "${view.size}" frame as PNG.');
      }
      return data.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }

  /// Hands locally rasterised frames to the driver. Call once, at the end.
  ///
  /// A no-op on platforms whose embedder captures natively.
  void publish() {
    if (_rasterised.isEmpty) return;
    binding.reportData = <String, dynamic>{
      ...?binding.reportData,
      kStoreShotsReportKey: Map<String, String>.from(_rasterised),
    };
  }
}

/// Navigation helpers for walking an app to each surface worth capturing.
extension StoreShotsNavigation on WidgetTester {
  /// Taps the first match of [finder], or returns false if there is none.
  ///
  /// Screenshot runs should degrade rather than fail when a surface is missing,
  /// so callers can branch on the result instead of catching an exception.
  Future<bool> tapIfPresent(
    Finder finder, {
    Duration settle = const Duration(seconds: 1),
  }) async {
    if (finder.evaluate().isEmpty) return false;
    await tap(finder.first, warnIfMissed: false);
    await pumpAndSettle(settle);
    return true;
  }

  /// Pops the current route directly.
  ///
  /// More reliable than hunting for a back button: apps with custom headers
  /// often use a bare [IconButton] with no tooltip or [BackButton] to find.
  Future<void> popRoute({
    Duration settle = const Duration(seconds: 1),
  }) async {
    final navigator = state<NavigatorState>(find.byType(Navigator).first);
    if (navigator.canPop()) navigator.pop();
    await pumpAndSettle(settle);
  }
}
