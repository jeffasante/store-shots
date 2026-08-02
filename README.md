# store_shots

Capture App Store and Play Store screenshots from your real Flutter app, on
every device size, in one command — and catch the bad ones before the store
rejects them.

```
$ dart run store_shots capture

▸ ios-6.9  (A1B2C3D4-0000-0000-0000-000000000000)
  rebooting simulator
  flutter drive --driver=test_driver/store_shots_test.dart ...
  saved screenshots/ios-6.9/01-home.png
  ...

  FOLDER   SIZE         FILES  SLOT
✓ ios-6.9  1320x2868    7      iPhone 6.9"
✓ ipad-13  2064x2752    7      iPad 13"
✓ macos    2880x1800    7      Mac

All 3 folder(s) ready to upload.
```

## Why

Store screenshots are usually made by hand: run the app, resize a window, grab
frames, redo everything when a string changes. It is slow, and the failures are
quiet — a folder of seven identical frames, or a Mac screenshot two pixels off
the accepted size, both look fine until the upload bounces.

`store_shots` drives the app with `integration_test`, so every screenshot comes
from the real running app, then checks the results:

- **Blank captures.** iOS and Android need the Flutter surface converted to an
  image *before* the first frame renders. Get the ordering wrong and every PNG
  is white. `prepare()` handles it.
- **macOS.** `integration_test` has no native `captureScreenshot` on macOS —
  calling it throws `MissingPluginException`. This package rasterises the layer
  tree instead and passes the frames back through the driver's report data.
- **Wrong dimensions.** Stores match exact pixel counts. `verify` knows the
  accepted sizes for each slot.
- **Duplicate frames.** If navigation stalls, you get the same screen seven
  times. Nobody notices by eye. A hash comparison notices immediately.

## Install

```yaml
dev_dependencies:
  integration_test:
    sdk: flutter
  store_shots: ^0.1.1
```

## Setup

Three files, all in [templates/](templates/).

**1. The walkthrough** — `integration_test/store_shots_test.dart`. Drive your
app to each screen worth showing:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:store_shots/store_shots.dart';
import 'package:your_app/main.dart' as app;

void main() {
  final shots = StoreShots.ensureInitialized();

  testWidgets('store screenshots', (tester) async {
    await shots.prepare(); // before the first frame
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 2));

    await shots.capture(tester, '01-home');

    if (await tester.tapIfPresent(find.byIcon(Icons.search))) {
      await shots.capture(tester, '02-search');
      await tester.popRoute();
    }

    shots.publish(); // last
  });
}
```

**2. The driver** — `test_driver/store_shots_test.dart`:

```dart
import 'package:store_shots/driver.dart';

Future<void> main() => storeShotsDriver();
```

**3. The config** — `store_shots.yaml`:

```yaml
output: screenshots

targets:
  # Find UDIDs with: xcrun simctl list devices available
  - id: ios-6.9
    device: 00000000-0000-0000-0000-000000000000 # iPhone 16 Pro Max

  - id: ipad-13
    device: 00000000-0000-0000-0000-000000000000 # iPad Pro 13-inch (M4)

  - id: macos
    device: macos
    window_size: 2880x1800
```

Then:

```sh
dart run store_shots capture
```

## macOS

macOS needs one extra step, because the window is whatever size it opens at and
the App Store only accepts 1280×800, 1440×900, 2560×1600 or 2880×1800.

Copy [templates/macos/StoreShotsWindow.swift](templates/macos/StoreShotsWindow.swift)
into `macos/Runner/`, then call it from `MainFlutterWindow.awakeFromNib()`:

```swift
self.contentViewController = flutterViewController
applyStoreShotsWindowSize()
```

It reads `STORE_SHOTS_WINDOW`, which `store_shots` sets from the `window_size`
field, and does nothing when that variable is absent — so normal launches and
release builds are untouched.

Sizing the window beats resizing the PNGs afterwards: the pixels stay native
rather than interpolated.

## Commands

| Command | What it does |
| --- | --- |
| `capture` | Runs every configured target, then verifies. `--only ios-6.9`, `--dry-run`, `--no-verify` |
| `verify` | Checks an existing folder. `--path`, `--json` |
| `specs` | Lists known store slots and accepted sizes |

`verify` exits non-zero on a problem, so it works as a CI gate:

```sh
dart run store_shots verify --path screenshots
```

## Store slots

| Id | Slot | Sizes |
| --- | --- | --- |
| `ios-6.9` | iPhone 6.9" — required | 1320×2868 |
| `ios-6.5` | iPhone 6.5" | 1242×2688 |
| `ipad-13` | iPad 13" — required with iPad support | 2064×2752 |
| `macos` | Mac | 1280×800, 1440×900, 2560×1600, 2880×1800 |
| `android-phone` | Play phone | 1080×1920, 1440×2560 |
| `android-tablet` | Play tablet | 1600×2560 |

Landscape equivalents are accepted too. Run `store_shots specs` for the full
list, and check the current store guidelines before submitting — requirements
change.

## Notes

**Reboot simulators.** A simulator that has been running a while hands back a
stale graphics surface, and every capture comes out blank white regardless of
your test code. `store_shots` shuts down and reboots each simulator before
capturing. Set `reboot: false` on a target to skip it.

**Seed your state.** Screenshots of an empty first-run app sell nothing. Use
`setUp` to populate storage — mark onboarding complete, unlock paid features,
insert sample content:

```dart
setUp(() async {
  SharedPreferences.setMockInitialValues({'has_seen_onboarding': true});
});
```

**Guard each step.** `tapIfPresent` returns `false` rather than throwing when a
widget is missing, so a renamed screen skips instead of failing the whole run.

**Name in order.** Filenames become the upload order, so prefix with an index.

## Contributing

Issues and pull requests welcome. Run before submitting:

```sh
flutter analyze
flutter test
```

## License

Apache License 2.0 — see [LICENSE](LICENSE).

Contributions are accepted under the same license, per section 5.
