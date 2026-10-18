import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Настройки приложения, которые не относятся ни к профилю, ни к
/// конкретным задачам/заметкам — цвета по умолчанию (выбираются через
/// цветовое колесо) и режим отображения экрана "Списки".
class SettingsProvider extends ChangeNotifier {
  static const _taskColorKey = 'settings_default_task_color';
  static const _noteColorKey = 'settings_default_note_color';
  static const _groupByCategoryKey = 'settings_group_tasks_by_category';

  Color _defaultTaskColor = const Color(0xFFFFF59D);
  Color _defaultNoteColor = const Color(0xFFFFF9C4);
  bool _groupTasksByCategory = false;

  Color get defaultTaskColor => _defaultTaskColor;
  Color get defaultNoteColor => _defaultNoteColor;
  // Экран "Списки": false — общий список всех задач подряд,
  // true — задачи сгруппированы по разделам (отсекам) с заголовками.
  bool get groupTasksByCategory => _groupTasksByCategory;

  Future<void> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final taskColorValue = prefs.getInt(_taskColorKey);
    final noteColorValue = prefs.getInt(_noteColorKey);
    if (taskColorValue != null) _defaultTaskColor = Color(taskColorValue);
    if (noteColorValue != null) _defaultNoteColor = Color(noteColorValue);
    _groupTasksByCategory = prefs.getBool(_groupByCategoryKey) ?? false;
    notifyListeners();
  }

  Future<void> setDefaultTaskColor(Color color) async {
    _defaultTaskColor = color;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_taskColorKey, color.toARGB32());
  }

  Future<void> setDefaultNoteColor(Color color) async {
    _defaultNoteColor = color;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_noteColorKey, color.toARGB32());
  }

  Future<void> setGroupTasksByCategory(bool value) async {
    _groupTasksByCategory = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_groupByCategoryKey, value);
  }

  // ---------- ВЫХОД ИЗ АККАУНТА ----------

  Future<void> resetToDefaults() async {
    _defaultTaskColor = const Color(0xFFFFF59D);
    _defaultNoteColor = const Color(0xFFFFF9C4);
    _groupTasksByCategory = false;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_taskColorKey);
    await prefs.remove(_noteColorKey);
    await prefs.remove(_groupByCategoryKey);
  }

  // ---------- ОБЛАЧНАЯ СИНХРОНИЗАЦИЯ (см. SyncManager) ----------

  Map<String, dynamic> exportForSync() => {
    'defaultTaskColor': _defaultTaskColor.toARGB32(),
    'defaultNoteColor': _defaultNoteColor.toARGB32(),
    'groupTasksByCategory': _groupTasksByCategory,
  };

  void importFromSync(Map<String, dynamic> data) {
    final taskColor = data['defaultTaskColor'];
    if (taskColor is int && taskColor != _defaultTaskColor.toARGB32()) {
      setDefaultTaskColor(Color(taskColor));
    }
    final noteColor = data['defaultNoteColor'];
    if (noteColor is int && noteColor != _defaultNoteColor.toARGB32()) {
      setDefaultNoteColor(Color(noteColor));
    }
    final groupByCategory = data['groupTasksByCategory'];
    if (groupByCategory is bool && groupByCategory != _groupTasksByCategory) {
      setGroupTasksByCategory(groupByCategory);
    }
  }
}
