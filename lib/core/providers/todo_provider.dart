import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../models/todo_category_model.dart';

/// Единственный источник правды по задачам и отсекам.
/// Главная, Списки и Календарь читают из одного и того же провайдера,
/// поэтому изменение в одном месте сразу видно во всех остальных.
class TodoProvider extends ChangeNotifier {
  // Начальные карточки-отсеки
  final List<TodoCategoryModel> _categories = [
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

  // Глобальный список всех задач приложения
  final List<TaskModel> _allTasks = [
    TaskModel(
      id: 't1',
      title: 'Пример задачи',
      categoryId: '1',
      dueDate: DateTime(2026, 8, 30),
    ),
  ];

  List<TodoCategoryModel> get categories => List.unmodifiable(_categories);
  List<TaskModel> get allTasks => List.unmodifiable(_allTasks);

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
    }
  }

  // Добавить новую карточку-отсек
  void addCategory(String title, Color color) {
    _categories.insert(
      0,
      TodoCategoryModel(
        id: DateTime.now().toString(),
        title: title,
        color: color,
      ),
    );
    notifyListeners();
  }

  // Изменить цвет карточки-отсека
  void changeCategoryColor(String categoryId, Color newColor) {
    final index = _categories.indexWhere((c) => c.id == categoryId);
    if (index != -1) {
      _categories[index].color = newColor;
      notifyListeners();
    }
  }

  // Удалить карточку-отсек вместе со всеми задачами внутри неё
  void deleteCategory(String categoryId) {
    _categories.removeWhere((c) => c.id == categoryId);
    _allTasks.removeWhere((t) => t.categoryId == categoryId);
    notifyListeners();
  }

  // Переместить верхнюю карту вниз колоды (для свайпов)
  void cycleCategories() {
    if (_categories.length < 2) return;
    final top = _categories.removeAt(0);
    _categories.add(top);
    notifyListeners();
  }

  // Добавить задачу прямо из карточки
  void addTask({
    required String title,
    required String categoryId,
    DateTime? dueDate,
  }) {
    _allTasks.add(
      TaskModel(
        id: DateTime.now().toString(),
        title: title,
        categoryId: categoryId,
        dueDate: dueDate,
      ),
    );
    notifyListeners(); // Обновляет Главную, Календарь и Списки одновременно!
  }

  // Найти отсек, отмеченный как "Сделано" (если такого нет — значит,
  // пользователь его удалил или ни один отсек так не помечен)
  TodoCategoryModel? _findDoneCategory() {
    for (final category in _categories) {
      if (category.isDoneCategory) return category;
    }
    return null;
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
        final originStillExists =
            _categories.any((c) => c.id == task.previousCategoryId);
        if (originStillExists) {
          task.categoryId = task.previousCategoryId!;
        }
        task.previousCategoryId = null;
      }
    }

    notifyListeners();
  }

  // Удалить задачу (используется в Списке задач и Календаре)
  void deleteTask(String taskId) {
    _allTasks.removeWhere((t) => t.id == taskId);
    notifyListeners();
  }
}
