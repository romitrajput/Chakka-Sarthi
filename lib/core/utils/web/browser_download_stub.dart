import 'dart:typed_data';

/// Only used in the web build.
void browserDownload(Uint8List bytes, String fileName, String mimeType) {
  throw UnsupportedError('Browser download is only available on the web');
}
