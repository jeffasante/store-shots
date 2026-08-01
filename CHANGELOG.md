# Changelog

## 0.1.0

Initial release.

- `StoreShots` capture helper for `integration_test`, handling the mobile
  surface conversion and macOS layer rasterisation.
- `storeShotsDriver()` writes frames to `<output>/<platform>/<name>.png`.
- `store_shots capture` drives every device in `store_shots.yaml`, rebooting
  simulators first.
- `store_shots verify` checks dimensions against store slots and detects
  duplicate frames.
- `store_shots specs` lists known store slots.
