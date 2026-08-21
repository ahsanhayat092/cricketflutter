/// Utility for parsing and converting image URLs (especially Google Drive links)
/// into direct image CDN URLs suitable for mobile apps.
class ImageUrlHelper {
  /// Converts various Google Drive link formats to direct loadable image URLs.
  /// If the URL is not a Google Drive link, it returns the trimmed URL.
  static String formatDirectImageUrl(String? url) {
    if (url == null || url.trim().isEmpty) return '';
    final trimmed = url.trim();

    // 1. If it's already an lh3 direct url, return it
    if (trimmed.contains('lh3.googleusercontent.com/d/')) {
      return trimmed;
    }

    // 2. Match standard Google Drive file patterns:
    // https://drive.google.com/file/d/<FILE_ID>/view?usp=sharing
    // https://drive.google.com/file/d/<FILE_ID>/view
    // https://drive.google.com/file/d/<FILE_ID>
    final fileMatch = RegExp(r'drive\.google\.com/file/d/([a-zA-Z0-9_-]+)').firstMatch(trimmed);
    if (fileMatch != null && fileMatch.groupCount >= 1) {
      final fileId = fileMatch.group(1);
      return 'https://lh3.googleusercontent.com/d/$fileId';
    }

    // 3. Match Google Drive id query parameter patterns:
    // https://drive.google.com/open?id=<FILE_ID>
    // https://drive.google.com/uc?id=<FILE_ID>&export=download
    // https://drive.google.com/uc?export=view&id=<FILE_ID>
    // https://drive.google.com/thumbnail?id=<FILE_ID>
    if (trimmed.contains('drive.google.com') || trimmed.contains('docs.google.com')) {
      final idMatch = RegExp(r'[?&]id=([a-zA-Z0-9_-]+)').firstMatch(trimmed);
      if (idMatch != null && idMatch.groupCount >= 1) {
        final fileId = idMatch.group(1);
        return 'https://lh3.googleusercontent.com/d/$fileId';
      }
    }

    // 4. Return trimmed original URL (for direct HTTPS URLs, Firebase Storage, etc.)
    return trimmed;
  }
}
