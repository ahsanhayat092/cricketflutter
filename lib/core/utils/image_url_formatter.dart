class ImageUrlFormatter {
  /// Normalizes Google Drive image URLs into high-speed direct content URLs.
  /// Formats handled:
  /// - https://drive.google.com/file/d/{FILE_ID}/view?usp=sharing
  /// - https://drive.google.com/open?id={FILE_ID}
  /// - https://drive.google.com/uc?id={FILE_ID}
  /// Output: https://lh3.googleusercontent.com/d/{FILE_ID}
  static String format(String? url) {
    if (url == null || url.trim().isEmpty) {
      return '';
    }

    final trimmed = url.trim();

    // Already a direct CDN / lh3 URL or non-drive URL
    if (!trimmed.contains('drive.google.com')) {
      return trimmed;
    }

    // Pattern 1: /file/d/<FILE_ID>/...
    final fileDPattern = RegExp(r'drive\.google\.com/file/d/([a-zA-Z0-9_-]+)');
    final match1 = fileDPattern.firstMatch(trimmed);
    if (match1 != null && match1.groupCount >= 1) {
      final fileId = match1.group(1);
      return 'https://lh3.googleusercontent.com/d/$fileId';
    }

    // Pattern 2: ?id=<FILE_ID> or &id=<FILE_ID>
    final idParamPattern = RegExp(r'[?&]id=([a-zA-Z0-9_-]+)');
    final match2 = idParamPattern.firstMatch(trimmed);
    if (match2 != null && match2.groupCount >= 1) {
      final fileId = match2.group(1);
      return 'https://lh3.googleusercontent.com/d/$fileId';
    }

    return trimmed;
  }
}
