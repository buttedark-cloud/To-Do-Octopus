import 'package:flutter/material.dart';

/// Простое хранилище данных профиля пользователя.
/// Пока здесь только имя — оно показывается внизу карточек-стикеров
/// вместо фиксированной подписи "Dark Butterfly".
class UserProfileProvider extends ChangeNotifier {
  String _name = 'Dark Butterfly';

  String get name => _name;

  void updateName(String newName) {
    final trimmed = newName.trim();
    _name = trimmed.isEmpty ? 'Dark Butterfly' : trimmed;
    notifyListeners();
  }
}
