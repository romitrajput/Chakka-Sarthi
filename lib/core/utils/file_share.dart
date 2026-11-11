import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sanjay_roadlines_fleet/core/utils/web/browser_download_stub.dart'
    if (dart.library.js_interop) 'package:sanjay_roadlines_fleet/core/utils/web/browser_download_web.dart';

/// Phone: opens the share sheet (WhatsApp, Gmail, Drive, Files…).
/// Web: downloads the file in the browser.
class FileShare {
  static const xlsxMime = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

  static Future<void> shareBytes(
    List<int> bytes, {
    required String fileName,
    required String mimeType,
    String? subject,
    String? text,
  }) async {
    final data = Uint8List.fromList(bytes);
    if (kIsWeb) {
      browserDownload(data, fileName, mimeType);
      return;
    }
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(data, flush: true);
    await Share.shareXFiles([XFile(file.path, mimeType: mimeType)], subject: subject, text: text);
  }
}
