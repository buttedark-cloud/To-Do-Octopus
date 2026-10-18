import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show Supabase, FileOptions, SearchOptions;
import 'image_compress_service.dart';

/// Облачное хранилище картинок (Supabase Storage, бакет "user-images").
/// Файлы лежат в папке с id пользователя: `uid/avatar.jpg` и
/// `uid/notes/время.jpg` — правила доступа в базе разрешают человеку
/// писать/удалять только в своей папке.
class CloudImageStorage {
  CloudImageStorage._();
  static final CloudImageStorage instance = CloudImageStorage._();

  static const String bucket = 'user-images';

  String? get _uid => Supabase.instance.client.auth.currentUser?.id;

  /// Анонимная сессия Supabase (id = имя папки для файлов этого телефона).
  /// Если при старте не было сети — пробуем создать её сейчас.
  Future<String?> _ensureUid() async {
    final auth = Supabase.instance.client.auth;
    if (auth.currentUser == null) {
      try {
        await auth.signInAnonymously();
      } catch (_) {}
    }
    return auth.currentUser?.id;
  }

  /// Возвращает постоянную https-ссылку или null (нет входа/сети/ошибка —
  /// тогда локальная копия остаётся, и загрузка повторится позже).
  Future<String?> uploadAvatar(String localPath) => _upload(
    localPath,
    (uid) => '$uid/avatar.jpg',
    cacheBust: true,
  );

  Future<String?> uploadNoteImage(String localPath) => _upload(
    localPath,
    (uid) => '$uid/notes/${DateTime.now().microsecondsSinceEpoch}.jpg',
  );

  Future<String?> _upload(
    String localPath,
    String Function(String uid) objectPath, {
    bool cacheBust = false,
  }) async {
    final uid = await _ensureUid();
    if (uid == null) return null;
    try {
      if (!await File(localPath).exists()) return null;

      // Страховка: если сюда дошёл несжатый файл — сожмём ещё раз.
      final ready = File(
        await ImageCompressService.instance.compressUnderLimit(localPath),
      );

      final path = objectPath(uid);
      final storage = Supabase.instance.client.storage.from(bucket);
      await storage.upload(
        path,
        ready,
        fileOptions: const FileOptions(
          contentType: 'image/jpeg',
          upsert: true,
        ),
      );
      final url = storage.getPublicUrl(path);
      // Аватар всегда лежит по одному и тому же пути — добавляем метку,
      // чтобы Flutter не показывал старую картинку из кэша.
      return cacheBust
          ? '$url?v=${DateTime.now().millisecondsSinceEpoch}'
          : url;
    } catch (e) {
      debugPrint('CloudImageStorage: загрузка не удалась: $e');
      return null;
    }
  }

  Future<void> deleteAvatar() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await Supabase.instance.client.storage.from(bucket).remove([
        '$uid/avatar.jpg',
      ]);
    } catch (_) {}
  }

  /// Удаляет файл по его публичной ссылке (локальные пути игнорируются).
  Future<void> deleteByUrl(String? url) async {
    if (url == null || !url.startsWith('http')) return;
    final marker = '/object/public/$bucket/';
    final start = url.indexOf(marker);
    if (start == -1) return;
    var path = url.substring(start + marker.length);
    final query = path.indexOf('?');
    if (query != -1) path = path.substring(0, query);
    try {
      await Supabase.instance.client.storage.from(bucket).remove([
        Uri.decodeComponent(path),
      ]);
    } catch (_) {}
  }

  /// Удаляет ВСЕ картинки текущего пользователя (при удалении аккаунта).
  /// При ошибке (например, нет сети) бросает исключение — тогда аккаунт
  /// не удаляется, и в облаке не остаётся "осиротевших" файлов.
  Future<void> deleteAllMine() async {
    final uid = _uid;
    if (uid == null) return;
    final storage = Supabase.instance.client.storage.from(bucket);
    for (final folder in [uid, '$uid/notes']) {
      final items = await storage.list(
        path: folder,
        searchOptions: const SearchOptions(limit: 1000),
      );
      // Папки в списке приходят без id — берём только файлы.
      final paths = items
          .where((o) => o.id != null)
          .map((o) => '$folder/${o.name}')
          .toList();
      if (paths.isNotEmpty) await storage.remove(paths);
    }
  }
}
