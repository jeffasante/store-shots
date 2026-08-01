/// A store listing slot and the pixel dimensions it accepts.
class StoreSpec {
  const StoreSpec({
    required this.id,
    required this.store,
    required this.slot,
    required this.sizes,
    this.required = false,
    this.note,
  });

  /// Folder name used under the output root, e.g. `ios-6.9`.
  final String id;

  /// Which storefront the slot belongs to.
  final String store;

  /// Human label for the listing slot, e.g. `iPhone 6.9"`.
  final String slot;

  /// Accepted sizes. Portrait and landscape are listed separately where both
  /// are allowed, since stores match on exact pixel counts.
  final List<({int width, int height})> sizes;

  /// Whether a submission is rejected without this slot.
  final bool required;

  final String? note;

  bool accepts(int width, int height) =>
      sizes.any((s) => s.width == width && s.height == height);

  String get sizeSummary =>
      sizes.map((s) => '${s.width}x${s.height}').join(' or ');
}

/// Store slots and their accepted dimensions.
///
/// Apple and Google both reject uploads whose pixel dimensions do not match
/// exactly, so these are checked rather than assumed. Verify against the
/// current store guidelines before a submission; requirements do change.
const List<StoreSpec> kStoreSpecs = <StoreSpec>[
  StoreSpec(
    id: 'ios-6.9',
    store: 'App Store',
    slot: 'iPhone 6.9"',
    required: true,
    sizes: [(width: 1320, height: 2868), (width: 2868, height: 1320)],
    note: 'iPhone 16 Pro Max, 17 Pro Max',
  ),
  StoreSpec(
    id: 'ios-6.5',
    store: 'App Store',
    slot: 'iPhone 6.5"',
    sizes: [(width: 1242, height: 2688), (width: 2688, height: 1242)],
    note: 'iPhone 11 Pro Max, XS Max',
  ),
  StoreSpec(
    id: 'ipad-13',
    store: 'App Store',
    slot: 'iPad 13"',
    required: true,
    sizes: [(width: 2064, height: 2752), (width: 2752, height: 2064)],
    note: 'Required only if the app supports iPad',
  ),
  StoreSpec(
    id: 'macos',
    store: 'App Store',
    slot: 'Mac',
    required: true,
    sizes: [
      (width: 1280, height: 800),
      (width: 1440, height: 900),
      (width: 2560, height: 1600),
      (width: 2880, height: 1800),
    ],
    note: 'Required only if the app ships on macOS',
  ),
  StoreSpec(
    id: 'android-phone',
    store: 'Play Store',
    slot: 'Phone',
    required: true,
    sizes: [
      (width: 1080, height: 1920),
      (width: 1920, height: 1080),
      (width: 1440, height: 2560),
      (width: 2560, height: 1440),
    ],
    note: 'Play accepts a range; these are the common safe sizes',
  ),
  StoreSpec(
    id: 'android-tablet',
    store: 'Play Store',
    slot: 'Tablet',
    sizes: [
      (width: 1600, height: 2560),
      (width: 2560, height: 1600),
    ],
    note: 'Required only if the listing targets tablets',
  ),
];

/// Returns the spec whose folder name is [id], or null when unknown.
StoreSpec? specFor(String id) {
  for (final spec in kStoreSpecs) {
    if (spec.id == id) return spec;
  }
  return null;
}
