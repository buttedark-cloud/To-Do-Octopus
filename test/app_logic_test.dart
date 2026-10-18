import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:to_do/core/models/note_model.dart';
import 'package:to_do/core/models/task_model.dart';
import 'package:to_do/core/providers/todo_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Модели', () {
    test('TaskModel: toJson -> fromJson сохраняет данные', () {
      final task = TaskModel(
        id: '1',
        title: 'Купить молоко',
        isCompleted: true,
        dueDate: DateTime(2026, 10, 20, 9, 30),
        categoryId: '3',
        previousCategoryId: '1',
      );

      final restored = TaskModel.fromJson(task.toJson());

      expect(restored.title, 'Купить молоко');
      expect(restored.isCompleted, isTrue);
      expect(restored.dueDate, DateTime(2026, 10, 20, 9, 30));
      expect(restored.previousCategoryId, '1');
    });

    test('NoteModel: toJson -> fromJson сохраняет цвет и напоминание', () {
      final note = NoteModel(
        id: 'n1',
        title: 'Идея',
        content: 'Текст',
        color: const Color(0xFFC8E6C9),
        reminderAt: DateTime(2026, 11, 1, 18, 0),
        createdAt: DateTime(2026, 10, 16),
      );

      final restored = NoteModel.fromJson(note.toJson());

      expect(restored.color.toARGB32(), 0xFFC8E6C9);
      expect(restored.reminderAt, DateTime(2026, 11, 1, 18, 0));
      expect(restored.imagePath, isNull);
    });

    test('TaskModel: старые данные без новых полей читаются', () {
      final restored = TaskModel.fromJson({
        'id': '7',
        'title': 'Старая задача',
        'categoryId': '1',
      });

      expect(restored.isCompleted, isFalse);
      expect(restored.notificationScheduled, isFalse);
    });
  });

  group('TodoProvider', () {
    test('выполненная задача улетает в «Сделано» и возвращается обратно', () {
      final provider = TodoProvider();
      final doneId = provider.doneCategoryId!;

      provider.addTask(title: 'Тест', categoryId: '1');
      final taskId = provider.allTasks.single.id;

      provider.toggleTaskStatus(taskId);
      expect(provider.allTasks.single.categoryId, doneId);
      expect(provider.allTasks.single.isCompleted, isTrue);

      provider.toggleTaskStatus(taskId);
      expect(provider.allTasks.single.categoryId, '1');
      expect(provider.allTasks.single.isCompleted, isFalse);
    });

    test('просроченные задачи: только невыполненные с прошедшей датой', () {
      final provider = TodoProvider();
      final yesterday = DateTime.now().subtract(const Duration(days: 2));

      provider.addTask(title: 'Просрочена', categoryId: '1', dueDate: yesterday);
      provider.addTask(title: 'Без даты', categoryId: '1');

      final overdue = provider.getOverdueTasks();
      expect(overdue.length, 1);
      expect(overdue.single.title, 'Просрочена');
    });

    test('нельзя создать больше 20 карточек', () {
      final provider = TodoProvider();
      while (provider.canAddCategory) {
        provider.addCategory('Карточка', Colors.blue);
      }
      expect(provider.categories.length, TodoProvider.maxCategories);
      expect(provider.addCategory('Лишняя', Colors.red), isFalse);
    });
  });
}
