class TaskModel {
  final String id;
  String title;
  bool isCompleted;
  DateTime? dueDate;
  String categoryId;

  String? previousCategoryId;

  bool notificationScheduled;

  TaskModel({
    required this.id,
    required this.title,
    this.isCompleted = false,
    this.dueDate,
    required this.categoryId,
    this.previousCategoryId,
    this.notificationScheduled = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'isCompleted': isCompleted,
    'dueDate': dueDate?.toIso8601String(),
    'categoryId': categoryId,
    'previousCategoryId': previousCategoryId,
    'notificationScheduled': notificationScheduled,
  };

  factory TaskModel.fromJson(Map<String, dynamic> json) => TaskModel(
    id: json['id'] as String,
    title: json['title'] as String,
    isCompleted: json['isCompleted'] as bool? ?? false,
    dueDate: json['dueDate'] != null
        ? DateTime.tryParse(json['dueDate'] as String)
        : null,
    categoryId: json['categoryId'] as String,
    previousCategoryId: json['previousCategoryId'] as String?,
    notificationScheduled: json['notificationScheduled'] as bool? ?? false,
  );
}
