import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:to_do/core/services/notification_service.dart';
import '../models/task_model.dart';
import '../models/todo_category_model.dart';

/// Единственный источник правды по задачам и отсекам.
/// Главная, Списки и Календарь читают из одного и того же провайдера,
/// поэтому изменение в одном месте сразу видно во всех остальных.
///
/// Раньше и отсеки, и задачи хранились только в памяти и полностью
/// пропадали при перезапуске приложения. Теперь после каждого изменения
/// они сохраняются в SharedPreferences и подгружаются обратно при старте
/// (см. loadFromPrefs(), вызывается из main.dart).
class TodoProvider extends ChangeNotifier {
  static const _categoriesKey = 'todo_categories_v1';
  static const _tasksKey = 'todo_tasks_v1';
  static const int maxCategories = 20;

  // Стартовый набор карточек-отсеков — используется при первом запуске
  // (когда в памяти телефона ещё ничего не сохранено) И при выходе из
  // аккаунта (resetToDefaults) — вынесен в отдельный метод, чтобы не
  // дублировать один и тот же список в двух местах.
  static List<TodoCategoryModel> _defaultCategories() => [
    TodoCategoryModel(
      id: '1',
      title: 'В процессе',
      color: const Color(0xFF64B5F6),
    ),
    TodoCategoryModel(
      id: '2',
      title: 'Сделано',
      color: const Color(0xFFFF4081),
      isDoneCategory: true,
    ),
    TodoCategoryModel(
      id: '3',
      title: 'Нужно сделать',
      color: const Color(0xFFFFF59D),
    ),
  ];

  List<TodoCategoryModel> _categories = _defaultCategories();

  // Глобальный список всех задач приложения. Никаких примерных/фиктивных
  // задач больше не подставляем — список начинается пустым, пока человек
  // сам что-то не добавит.
  List<TaskModel> _allTasks = [];

  bool _isLoaded = false;
  bool get isLoaded => _isLoaded;

  List<TodoCategoryModel> get categories => List.unmodifiable(_categories);
  List<TaskModel> get allTasks => List.unmodifiable(_allTasks);

  // ---------- ЗАГРУЗКА / СОХРАНЕНИЕ ----------

  Future<void> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();

    final rawCategories = prefs.getString(_categoriesKey);
    if (rawCategories != null) {
      try {
        final decoded = jsonDecode(rawCategories) as List<dynamic>;
        _categories = decoded
            .map((e) => TodoCategoryModel.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (e, st) {
        debugPrint('TodoProvider: ОШИБКА чтения категорий: $e');
        debugPrint('$st');
      }
    }

    final rawTasks = prefs.getString(_tasksKey);
    if (rawTasks != null) {
      try {
        final decoded = jsonDecode(rawTasks) as List<dynamic>;
        _allTasks = decoded
            .map((e) => TaskModel.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (e, st) {
        debugPrint('TodoProvider: ОШИБКА чтения задач: $e');
        debugPrint('$st');
      }
    }

    _isLoaded = true;
    notifyListeners();

    // Уведомления не переживают удаление/переустановку приложения и могут
    // не пережить перезагрузку телефона — на всякий случай перепланируем
    // их для всех ещё не выполненных задач с будущей датой при каждом
    // старте приложения.
    for (final task in _allTasks) {
      if (!task.isCompleted &&
          task.dueDate != null &&
          task.dueDate!.isAfter(DateTime.now())) {
        NotificationService.instance.scheduleTaskNotification(
          taskId: task.id,
          taskTitle: task.title,
          dueDate: task.dueDate!,
        );
      }
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _categoriesKey,
      jsonEncode(_categories.map((c) => c.toJson()).toList()),
    );
    await prefs.setString(
      _tasksKey,
      jsonEncode(_allTasks.map((t) => t.toJson()).toList()),
    );
  }

  // Получить задачи только для конкретной карточки
  List<TaskModel> getTasksForCategory(String categoryId) {
    return _allTasks.where((task) => task.categoryId == categoryId).toList();
  }

  // Найти отсек по id (например, чтобы показать его цвет/название в Списке задач)
  TodoCategoryModel? getCategoryById(String categoryId) {
    for (final category in _categories) {
      if (category.id == categoryId) return category;
    }
    return null;
  }

  // Просроченные незавершённые задачи — используется в колокольчике на AppBar
  List<TaskModel> getOverdueTasks() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _allTasks
        .where(
          (task) =>
              !task.isCompleted &&
              task.dueDate != null &&
              task.dueDate!.isBefore(today),
        )
        .toList();
  }

  // Переименовать карточку-отсек
  void renameCategory(String categoryId, String newTitle) {
    final index = _categories.indexWhere((c) => c.id == categoryId);
    if (index != -1) {
      _categories[index].title = newTitle;
      notifyListeners();
      _persist();
    }
  }

  // Добавить новую карточку-отсек
  bool get canAddCategory => _categories.length < maxCategories;

  bool addCategory(String title, Color color) {
    if (!canAddCategory) return false;
    _categories.insert(
      0,
      TodoCategoryModel(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: title,
        color: color,
      ),
    );
    notifyListeners();
    _persist();
    return true;
  }

  // Изменить цвет карточки-отсека
  void changeCategoryColor(String categoryId, Color newColor) {
    final index = _categories.indexWhere((c) => c.id == categoryId);
    if (index != -1) {
      _categories[index].color = newColor;
      notifyListeners();
      _persist();
    }
  }

  // Удалить карточку-отсек вместе со всеми задачами внутри неё
  void deleteCategory(String categoryId) {
    _categories.removeWhere((c) => c.id == categoryId);
    _allTasks.removeWhere((t) => t.categoryId == categoryId);
    notifyListeners();
    _persist();
  }

  // Переместить верхнюю карту вниз колоды (для свайпов)
  void cycleCategories() {
    if (_categories.length < 2) return;
    final top = _categories.removeAt(0);
    _categories.add(top);
    notifyListeners();
    _persist();
  }

  // Добавить задачу прямо из карточки
  void addTask({
    required String title,
    required String categoryId,
    DateTime? dueDate,
  }) {
    final task = TaskModel(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: title,
      categoryId: categoryId,
      dueDate: dueDate,
    );
    _allTasks.add(task);
    notifyListeners(); // Обновляет Главную, Календарь и Списки одновременно!
    _persist();

    // Настоящее уведомление — приходит человеку ровно в указанное время.
    if (dueDate != null && dueDate.isAfter(DateTime.now())) {
      NotificationService.instance.scheduleTaskNotification(
        taskId: task.id,
        taskTitle: title,
        dueDate: dueDate,
      );
    }
  }

  // Найти отсек, отмеченный как "Сделано" (если такого нет — значит,
  // пользователь его удалил или ни один отсек так не помечен)
  TodoCategoryModel? _findDoneCategory() {
    for (final category in _categories) {
      if (category.isDoneCategory) return category;
    }
    return null;
  }

  // Публичный доступ для экрана "Настройки" — id текущего отсека
  // "Сделано" (или null, если такого отсека сейчас нет вообще).
  String? get doneCategoryId => _findDoneCategory()?.id;

  // Позволяет человеку самому выбрать, какой отсек считать "Сделано" —
  // например, если он удалил исходный отсек с этой пометкой, и теперь
  // выполненным задачам просто некуда деваться (они остаются на месте,
  // но без автоматического переноса в отдельную стопку).
  void setDoneCategory(String categoryId) {
    for (final category in _categories) {
      category.isDoneCategory = category.id == categoryId;
    }
    notifyListeners();
    _persist();
  }

  // Переключить статус выполнения задачи.
  // При отметке "выполнено" задача автоматически улетает в отсек "Сделано",
  // а при снятии галочки — возвращается туда, откуда была.
  void toggleTaskStatus(String taskId) {
    final index = _allTasks.indexWhere((t) => t.id == taskId);
    if (index == -1) return;

    final task = _allTasks[index];
    task.isCompleted = !task.isCompleted;

    final doneCategory = _findDoneCategory();
    if (doneCategory != null) {
      if (task.isCompleted && task.categoryId != doneCategory.id) {
        task.previousCategoryId = task.categoryId;
        task.categoryId = doneCategory.id;
      } else if (!task.isCompleted && task.previousCategoryId != null) {
        final originStillExists = _categories.any(
          (c) => c.id == task.previousCategoryId,
        );
        if (originStillExists) {
          task.categoryId = task.previousCategoryId!;
        }
        task.previousCategoryId = null;
      }
    }

    notifyListeners();
    _persist();

    // Выполненную задачу больше не нужно "будить" уведомлением; если её
    // снова сделали невыполненной и дата ещё не наступила — планируем
    // напоминание заново.
    if (task.isCompleted) {
      NotificationService.instance.cancelTaskNotification(task.id);
    } else if (task.dueDate != null && task.dueDate!.isAfter(DateTime.now())) {
      NotificationService.instance.scheduleTaskNotification(
        taskId: task.id,
        taskTitle: task.title,
        dueDate: task.dueDate!,
      );
    }
  }

  // Удалить задачу (используется в Списке задач и Календаре)
  void deleteTask(String taskId) {
    _allTasks.removeWhere((t) => t.id == taskId);
    notifyListeners();
    _persist();
    NotificationService.instance.cancelTaskNotification(taskId);
  }

  // ---------- ВЫХОД ИЗ АККАУНТА ----------

  // ИСПРАВЛЕНИЕ КРИТИЧЕСКОГО БАГА: раньше при выходе из аккаунта локальные
  // данные (задачи, отсеки) просто оставались лежать на телефоне — если
  // следующим входил ДРУГОЙ человек на том же устройстве, он видел чужие
  // задачи. Вызывается из ProfileScreen ПЕРЕД AuthProvider.signOut().
  Future<void> resetToDefaults() async {
    for (final task in _allTasks) {
      NotificationService.instance.cancelTaskNotification(task.id);
    }
    _categories = _defaultCategories();
    _allTasks = [];
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_categoriesKey);
    await prefs.remove(_tasksKey);
  }

  // ---------- ОБЛАЧНАЯ СИНХРОНИЗАЦИЯ (см. SyncManager) ----------

  Map<String, dynamic> exportForSync() => {
    'categories': _categories.map((c) => c.toJson()).toList(),
    'tasks': _allTasks.map((t) => t.toJson()).toList(),
  };

  /// Полностью заменяет локальные списки данными из облака (используется,
  /// когда SyncManager решает, что облачная версия новее локальной).
  /// Кэш на устройстве (SharedPreferences) тоже обновляется, чтобы
  /// офлайн-режим сразу видел актуальные данные.
  void importFromSync(Map<String, dynamic> data) {
    final rawCategories = data['categories'];
    if (rawCategories is List) {
      _categories = rawCategories
          .whereType<Map>()
          .map((e) => TodoCategoryModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    final rawTasks = data['tasks'];
    if (rawTasks is List) {
      _allTasks = rawTasks
          .whereType<Map>()
          .map((e) => TaskModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    notifyListeners();
    _persist();

    // Переставляем уведомления под задачи, пришедшие с другого устройства.
    for (final task in _allTasks) {
      if (!task.isCompleted &&
          task.dueDate != null &&
          task.dueDate!.isAfter(DateTime.now())) {
        NotificationService.instance.scheduleTaskNotification(
          taskId: task.id,
          taskTitle: task.title,
          dueDate: task.dueDate!,
        );
      } else {
        NotificationService.instance.cancelTaskNotification(task.id);
      }
    }
  }
}
