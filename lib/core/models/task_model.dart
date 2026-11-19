class TaskModel {
  final String id;
  String title;
  bool isCompleted;

  /// Срок (дедлайн). null — у задачи нет срока: она никогда не считается
  /// просроченной и не присылает уведомление.
  DateTime? dueDate;
  String categoryId;

  String? previousCategoryId;

  bool notificationScheduled;

  /// Когда задача создана. У задач, сохранённых старой версией приложения,
  /// этого поля нет — тогда null.
  DateTime? createdAt;

  TaskModel({
    required this.id,
    required this.title,
    this.isCompleted = false,
    this.dueDate,
    required this.categoryId,
    this.previousCategoryId,
    this.notificationScheduled = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'isCompleted': isCompleted,
    'dueDate': dueDate?.toIso8601String(),
    'categoryId': categoryId,
    'previousCategoryId': previousCategoryId,
    'notificationScheduled': notificationScheduled,
    'createdAt': createdAt?.toIso8601String(),
  };

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    final task = TaskModel(
      id: json['id'] as String,
      title: json['title'] as String,
      isCompleted: json['isCompleted'] as bool? ?? false,
      dueDate: json['dueDate'] != null ? DateTime.tryParse(json['dueDate'] as String) : null,
      categoryId: json['categoryId'] as String,
      previousCategoryId: json['previousCategoryId'] as String?,
      notificationScheduled: json['notificationScheduled'] as bool? ?? false,
    );
    // Для старых данных без даты создания не выдумываем "сегодня".
    task.createdAt = json['createdAt'] != null ? DateTime.tryParse(json['createdAt'] as String) : null;
    return task;
  }
}
