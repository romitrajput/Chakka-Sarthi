import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

/// Saves a file through the browser's normal download.
void browserDownload(Uint8List bytes, String fileName, String mimeType) {
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mimeType));
  final url = web.URL.createObjectURL(blob);
  final link = web.HTMLAnchorElement()
    ..href = url
    ..download = fileName
    ..style.display = 'none';
  web.document.body!.appendChild(link);
  link.click();
  link.remove();
  web.URL.revokeObjectURL(url);
}
