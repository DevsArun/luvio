import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// Saves captured video frames (screenshots) to a Screenshots folder in the
/// app's external storage (falls back to app documents on restricted devices).
class CaptureService {
  Future<String?> saveScreenshot(Uint8List bytes) async {
    try {
      Directory base;
      try {
        base = (await getExternalStorageDirectory()) ??
            await getApplicationDocumentsDirectory();
      } catch (_) {
        base = await getApplicationDocumentsDirectory();
      }
      final dir = Directory('${base.path}/Screenshots');
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      final file = File(
          '${dir.path}/luvio_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes);
      return file.path;
    } catch (_) {
      return null;
    }
  }
}
