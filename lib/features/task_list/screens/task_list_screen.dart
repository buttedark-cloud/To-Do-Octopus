import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/todo_provider.dart';
import '../../../core/utils/date_formatter.dart';

/// Экран "Списки" — сквозной список всех задач из всех отсеков сразу,
/// со свайпом для удаления и чекбоксом для завершения.
class TaskListScreen extends StatelessWidget {
  const TaskListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TodoProvider>();
    final tasks = provider.allTasks;

    if (tasks.isEmpty) {
      return const Center(child: Text('Задач пока нет'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        final category = provider.getCategoryById(task.categoryId);
        final categoryColor = category?.color ?? Colors.grey;

        return Dismissible(
          key: ValueKey(task.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            margin: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          onDismissed: (_) => provider.deleteTask(task.id),
          child: Card(
            margin: const EdgeInsets.symmetric(vertical: 6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: categoryColor.withOpacity(0.6), width: 1.5),
            ),
            child: ListTile(
              leading: Checkbox(
                value: task.isCompleted,
                onChanged: (_) => provider.toggleTaskStatus(task.id),
              ),
              title: Text(
                task.title,
                style: TextStyle(
                  decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                ),
              ),
              subtitle: Text(
                [
                  if (category != null) category.title,
                  if (task.dueDate != null) formatDate(task.dueDate!),
                ].join(' • '),
              ),
              trailing: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(color: categoryColor, shape: BoxShape.circle),
              ),
            ),
          ),
        );
      },
    );
  }
}
