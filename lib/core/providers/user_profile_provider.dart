import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/avatar_storage_service.dart';
import '../services/local_file_storage_service.dart';

/// Простое хранилище данных профиля пользователя.
/// Имя показывается внизу карточек-стикеров вместо фиксированной подписи
/// "Dark Butterfly". Фото — для экрана профиля и экрана регистрации
/// (логотип аккаунта / аватар из Google-Facebook).
class UserProfileProvider extends ChangeNotifier {
  static const _nameKey = 'user_name';
  static const _photoKey = 'user_avatar_path';

  String _name = 'No name';
  String? _photoPath;

  String get name => _name;
  String? get photoPath => _photoPath;

  // ИСПРАВЛЕНИЕ БАГА (имя/фото иногда терялись после полного удаления
  // приложения): обычная облачная синхронизация (см. SyncManager) шлёт
  // изменения в Firestore с задержкой в 2 секунды — так задумано для
  // частых правок задач, чтобы не слать запрос на каждую букву. Но если
  // человек меняет имя/фото и почти сразу удаляет приложение, эти 2
  // секунды могут не успеть пройти, и правка не долетает до облака.
  // SyncManager подставляет сюда мгновенную отправку — специально для
  // редких, но важных изменений вроде имени и фото.
  Future<void> Function()? onCriticalChange;

  // Подгружает сохранённые имя и фото при старте приложения
  Future<void> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _name = prefs.getString(_nameKey) ?? _name;
    _photoPath = prefs.getString(_photoKey);
    notifyListeners();
  }

  Future<void> updateName(String newName) async {
    final trimmed = newName.trim();
    _name = trimmed.isEmpty ? 'Dark Butterfly' : trimmed;
    notifyListeners();

    // Дожидаемся получения памяти и записи строки
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nameKey, _name);

    // Не ждём — не хотим тормозить UI сетевым запросом.
    unawaited(onCriticalChange?.call());
  }

  // Нужен экрану регистрации — сохраняет фото из галереи
  // или ссылку на аватар из Google/Facebook.
  //
  // ИСПРАВЛЕНИЕ БАГА (аватар исчезает после переустановки): раньше
  // локальный путь к файлу на телефоне сохранялся как есть и НИКОГДА не
  // попадал в облако (в отличие от ссылки на аватар из Google) — при
  // полном удалении приложения файл физически стирался вместе с ним, и
  // восстановить аватар было неоткуда.
  //
  // Теперь: если это локальный файл (путь НЕ начинается с http) — он
  // сразу показывается на экране (мгновенный отклик, без ожидания сети),
  // а затем в фоне загружается в Firebase Storage. Как только загрузка
  // завершится, локальный путь заменяется постоянной https-ссылкой на
  // файл в облаке — точно такой же, как для аватара из Google — и с этого
  // момента переживает переустановку.
  Future<void> updatePhoto(String? pathOrUrl) async {
    _photoPath = pathOrUrl;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();

    if (pathOrUrl == null) {
      await prefs.remove(_photoKey);
      unawaited(AvatarStorageService.instance.deleteAvatar());
      unawaited(onCriticalChange?.call());
      return;
    }

    // Ссылка из Google и так постоянная — копировать/грузить никуда не
    // нужно.
    if (pathOrUrl.startsWith('http')) {
      await prefs.setString(_photoKey, pathOrUrl);
      unawaited(onCriticalChange?.call());
      return;
    }

    // ИСПРАВЛЕНИЕ БАГА (фото пропадает само по себе даже без удаления
    // приложения): image_picker/image_cropper обычно возвращают путь во
    // временную/кэш-директорию — Android может очистить её сам, без
    // ведома человека. Сразу копируем файл в постоянную папку приложения
    // — это защищает от такой "тихой" потери. От полного удаления самого
    // приложения это всё равно не спасает (тут только облако помогло бы),
    // но вы сознательно решили этим не заниматься — так что это
    // максимум, что можно сделать бесплатно и без Firebase Storage.
    final persistedPath = await LocalFileStorageService.instance
        .persistStable(pathOrUrl, 'avatar');

    if (_photoPath != pathOrUrl) {
      // Пока копировали — человек уже успел выбрать другое фото. Не
      // перетираем то, что он видит сейчас, устаревшим путём.
      return;
    }

    _photoPath = persistedPath;
    notifyListeners();
    await prefs.setString(_photoKey, persistedPath);
    unawaited(onCriticalChange?.call());

    // Дальше — попытка загрузить в Firebase Storage (если он у вас когда-
    // нибудь будет активирован). Сейчас, скорее всего, просто ничего не
    // сделает и вернёт null — это ожидаемо и безопасно, локальная копия
    // уже сохранена и работает независимо от этого.
    final uploadedUrl = await AvatarStorageService.instance.uploadAvatar(
      persistedPath,
    );
    if (uploadedUrl == null) return;
    if (_photoPath != persistedPath) return;

    _photoPath = uploadedUrl;
    notifyListeners();
    await prefs.setString(_photoKey, uploadedUrl);
    unawaited(onCriticalChange?.call());
  }

  // ---------- ВЫХОД ИЗ АККАУНТА ----------

  // ИСПРАВЛЕНИЕ КРИТИЧЕСКОГО БАГА: раньше имя и фото профиля хранились в
  // SharedPreferences без привязки к конкретному аккаунту Firebase. При
  // выходе они просто оставались на телефоне — если следующим входил
  // ДРУГОЙ человек на том же устройстве, он видел чужое имя и чужую
  // аватарку. Вызывается из ProfileScreen ПЕРЕД AuthProvider.signOut(),
  // до того как следующий человек успеет войти.
  Future<void> resetToDefaults() async {
    _name = 'No name';
    _photoPath = null;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_nameKey);
    await prefs.remove(_photoKey);
  }

  // ---------- ОБЛАЧНАЯ СИНХРОНИЗАЦИЯ (см. SyncManager) ----------

  Map<String, dynamic> exportForSync() => {
        'profileName': _name,
        // Теперь сюда попадает и локально выбранное фото — оно к этому
        // моменту уже либо http-ссылка на Firebase Storage, либо (если
        // загрузка ещё не завершилась/не удалась) временно локальный путь,
        // который просто не будет синхронизирован до следующей попытки.
        'profilePhotoUrl':
            (_photoPath != null && _photoPath!.startsWith('http'))
                ? _photoPath
                : null,
      };

  void importFromSync(Map<String, dynamic> data) {
    final remoteName = data['profileName'];
    if (remoteName is String && remoteName.isNotEmpty && remoteName != _name) {
      updateName(remoteName);
    }
    final remotePhoto = data['profilePhotoUrl'];
    if (remotePhoto is String && remotePhoto != _photoPath) {
      updatePhoto(remotePhoto);
    }
  }
}
