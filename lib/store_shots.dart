/// Capture store screenshots from inside an integration test.
///
/// Import this in `integration_test/store_shots_test.dart`. The matching
/// driver lives in `package:store_shots/driver.dart`.
library;

export 'src/capture.dart' show StoreShots, StoreShotsNavigation;
export 'src/store_specs.dart' show StoreSpec, kStoreSpecs, specFor;
