import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Documents (Aadhaar, licence, challans) are kept in PRIVATE storage.
/// A saved link is turned into a short-lived signed link (valid 1 hour) that only
/// works for a logged-in user of the same company.
final Map<String, (String, DateTime)> _signedCache = {};

Future<String> signedUrlFor(String storedUrl) async {
  final cached = _signedCache[storedUrl];
  if (cached != null && cached.$2.isAfter(DateTime.now())) return cached.$1;

  // .../storage/v1/object/public/<bucket>/<path>  (or /sign/, /authenticated/)
  final m = RegExp(r'/storage/v1/object/(?:public|sign|authenticated)/([^/]+)/([^?]+)').firstMatch(storedUrl);
  if (m == null) return storedUrl; // not a storage link
  final bucket = m.group(1)!;
  final path = Uri.decodeComponent(m.group(2)!);
  final signed = await Supabase.instance.client.storage.from(bucket).createSignedUrl(path, 3600);
  _signedCache[storedUrl] = (signed, DateTime.now().add(const Duration(minutes: 50)));
  return signed;
}

/// Drop-in replacement for Image.network for documents in private storage.
class SecureImage extends StatelessWidget {
  const SecureImage(
    this.url, {
    super.key,
    this.fit,
    this.width,
    this.height,
    this.loadingBuilder,
    this.errorBuilder,
  });

  final String url;
  final BoxFit? fit;
  final double? width;
  final double? height;
  final ImageLoadingBuilder? loadingBuilder;
  final ImageErrorWidgetBuilder? errorBuilder;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: signedUrlFor(url),
      builder: (context, snap) {
        if (snap.hasError) {
          return errorBuilder?.call(context, snap.error!, null) ?? const Icon(Icons.broken_image_outlined);
        }
        if (!snap.hasData) {
          return SizedBox(
            width: width,
            height: height,
            child: const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))),
          );
        }
        return Image.network(
          snap.data!,
          fit: fit,
          width: width,
          height: height,
          loadingBuilder: loadingBuilder,
          errorBuilder: errorBuilder,
        );
      },
    );
  }
}
