// Add this call to macos/Runner/MainFlutterWindow.swift, inside
// awakeFromNib(), after `self.contentViewController = flutterViewController`:
//
//     applyStoreShotsWindowSize()
//
// It only does anything when STORE_SHOTS_WINDOW is set, so normal launches and
// release builds are unaffected. store_shots sets that variable from the
// `window_size` field of each target.
//
// Without this the window is whatever size it happens to open at, and the App
// Store rejects anything that isn't 1280x800, 1440x900, 2560x1600 or 2880x1800.
// Sizing the window beats resizing the PNGs afterwards: the captured pixels
// stay native instead of being interpolated.

import Cocoa

extension NSWindow {
  func applyStoreShotsWindowSize() {
    guard let spec = ProcessInfo.processInfo.environment["STORE_SHOTS_WINDOW"]
    else { return }

    let parts = spec.split(separator: "x")
    guard parts.count == 2,
          let width = Double(parts[0]),
          let height = Double(parts[1])
    else {
      NSLog("store_shots: could not parse STORE_SHOTS_WINDOW=\(spec)")
      return
    }

    // The requested size is in physical pixels; setContentSize takes points.
    let scale = self.screen?.backingScaleFactor ?? 1
    self.setContentSize(NSSize(width: width / scale, height: height / scale))
    self.center()
  }
}
