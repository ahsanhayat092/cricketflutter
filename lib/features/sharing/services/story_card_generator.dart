import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class StoryCardGenerator {
  /// Captures a widget with a GlobalKey into a high-DPI Uint8List PNG byte buffer
  static Future<Uint8List?> captureBoundaryToImage(
    GlobalKey key, {
    double pixelRatio = 3.0,
  }) async {
    try {
      final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;

      // Allow a brief delay for any active animations/fonts if needed
      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('[StoryCardGenerator] Capture error: $e');
      return null;
    }
  }

  /// Saves PNG bytes into a temporary file on the device
  static Future<File?> saveBytesToTempFile(Uint8List bytes, String filename) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$filename');
      await file.writeAsBytes(bytes, flush: true);
      return file;
    } catch (e) {
      debugPrint('[StoryCardGenerator] File write error: $e');
      return null;
    }
  }

  /// One-step capture & share flow
  static Future<bool> captureAndShare({
    required GlobalKey key,
    required String filename,
    required String shareText,
    String? subject,
    double pixelRatio = 3.0,
  }) async {
    final bytes = await captureBoundaryToImage(key, pixelRatio: pixelRatio);
    if (bytes == null) return false;

    final file = await saveBytesToTempFile(bytes, filename);
    if (file == null) return false;

    final xFile = XFile(file.path, mimeType: 'image/png');
    final result = await Share.shareXFiles(
      [xFile],
      text: shareText,
      subject: subject ?? 'WASA Premier League 2026',
    );

    return result.status == ShareResultStatus.success;
  }
}
