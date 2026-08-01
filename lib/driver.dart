/// Driver half of the capture, run by `flutter drive --driver=...`.
///
/// Kept separate from `package:store_shots/store_shots.dart` because the
/// driver runs on the host VM, not on the device.
library;

export 'src/driver.dart' show storeShotsDriver, kDefaultOutputRoot;
