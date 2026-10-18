import 'dart:io';
import 'package:path_provider/path_provider.dart';


class LocalFileStorageService {
  LocalFileStorageService._();
  static final LocalFileStorageService instance = LocalFileStorageService._();

  /// Копирует файл под СТАБИЛЬНЫМ именем — повторный вызов с тем же
  /// [fileName] перезапишет предыдущий файл, ничего не накапливается на
  /// телефоне. Подходит для аватара — он всегда один.
  Future<String> persistStable(String temporaryPath, String fileName) async {
    try {
      final sourceFile = File(temporaryPath);
      if (!await sourceFile.exists()) return temporaryPath;

      final docsDir = await getApplicationDocumentsDirectory();
      final targetPath = '${docsDir.path}/$fileName.jpg';
      await sourceFile.copy(targetPath);
      return targetPath;
    } catch (e) {
    
      return temporaryPath;
    }
  }

 
  Future<String> persistUnique(String temporaryPath, String prefix) async {
    final uniqueName = '${prefix}_${DateTime.now().microsecondsSinceEpoch}';
    return persistStable(temporaryPath, uniqueName);
  }
}
