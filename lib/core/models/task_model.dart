/// Общая модель задачи для всего приложения.
/// Используется на Главной, в Списке задач и в Календаре —
/// один источник правды, поэтому храним её отдельно от экранов.
class TaskModel {
  final String id;
  String title;
  bool isCompleted;
  DateTime? dueDate; // Дата для календаря
  String categoryId; // К какой карточке-отсеку принадлежит

  // Запоминает исходный отсек, если задачу автоматически перекинуло в
  // "Сделано" по галочке — чтобы можно было вернуть её на место при снятии галочки.
  String? previousCategoryId;

  TaskModel({
    required this.id,
    required this.title,
    this.isCompleted = false,
    this.dueDate,
    required this.categoryId,
    this.previousCategoryId,
  });
}
