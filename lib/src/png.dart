import 'dart:io';
import 'dart:typed_data';

/// Pixel dimensions of a PNG.
typedef PngSize = ({int width, int height});

const List<int> _signature = [137, 80, 78, 71, 13, 10, 26, 10];

/// Reads the dimensions from a PNG's IHDR header.
///
/// Only the first 24 bytes are read, so this stays cheap over a whole folder
/// and avoids pulling in an image decoding dependency.
Future<PngSize> readPngSize(File file) async {
  final header = await file.openRead(0, 24).fold<BytesBuilder>(
        BytesBuilder(),
        (builder, chunk) => builder..add(chunk),
      );
  final bytes = header.takeBytes();

  if (bytes.length < 24) {
    throw FormatException('${file.path} is too short to be a PNG.');
  }
  for (var i = 0; i < _signature.length; i++) {
    if (bytes[i] != _signature[i]) {
      throw FormatException('${file.path} is not a PNG.');
    }
  }

  final data = ByteData.sublistView(bytes);
  // IHDR is always the first chunk: 8 byte signature, 4 length, 4 type.
  return (width: data.getUint32(16), height: data.getUint32(20));
}
