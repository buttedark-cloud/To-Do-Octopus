import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Картинка заметки может быть либо локальным файлом (ещё не загружена
/// в облако), либо https-ссылкой (уже в Supabase). Для ссылок используем
/// дисковый кэш — картинка показывается и без интернета.
ImageProvider imageProviderFor(String path) {
  if (path.startsWith('http')) return CachedNetworkImageProvider(path);
  return FileImage(File(path));
}
