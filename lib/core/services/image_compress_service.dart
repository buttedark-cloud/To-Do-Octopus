import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

/// Сжимает фото так, чтобы оно весило не больше ~1 МБ.
///
/// Идёт по ступеням "качество / размер" от мягкой к жёсткой и останавливается
/// на первой, где файл уже влез в лимит. Фото на 7 МБ с камеры обычно
/// превращается в 300–700 КБ уже на первой ступени — на глаз разницы нет.
/// Если файл и так меньше лимита — возвращает его как есть.
class ImageCompressService {
  ImageCompressService._();
  static final ImageCompressService instance = ImageCompressService._();

  static const int maxBytes = 1024 * 1024; // 1 МБ

  // (минимальная сторона в пикселях, качество JPEG)
  static const List<(int, int)> _steps = [
    (1600, 85),
    (1600, 75),
    (1280, 70),
    (1024, 60),
    (800, 55),
  ];

  /// Возвращает путь к сжатому файлу (временная папка) либо исходный путь,
  /// если сжимать не нужно / не получилось.
  Future<String> compressUnderLimit(String sourcePath) async {
    try {
      final source = File(sourcePath);
      if (!await source.exists()) return sourcePath;
      if (await source.length() <= maxBytes) return sourcePath;

      final tempDir = await getTemporaryDirectory();
      String lastPath = sourcePath;

      for (final (side, quality) in _steps) {
        final target =
            '${tempDir.path}/cmp_${DateTime.now().microsecondsSinceEpoch}.jpg';
        final result = await FlutterImageCompress.compressAndGetFile(
          sourcePath,
          target,
          quality: quality,
          minWidth: side,
          minHeight: side,
          format: CompressFormat.jpeg,
        );
        if (result == null) continue;

        // Промежуточный результат прошлой ступени больше не нужен.
        if (lastPath != sourcePath && lastPath != result.path) {
          try {
            await File(lastPath).delete();
          } catch (_) {}
        }
        lastPath = result.path;

        if (await File(result.path).length() <= maxBytes) return result.path;
      }
      return lastPath; // самая сильная ступень — лучшее, что получилось
    } catch (e) {
      debugPrint('ImageCompressService: не удалось сжать фото: $e');
      return sourcePath;
    }
  }
}
