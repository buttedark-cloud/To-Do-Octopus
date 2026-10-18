import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/todo_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/models/task_model.dart';
import '../../../core/utils/date_formatter.dart';

/// Экран "Списки" — сквозной список всех задач из всех отсеков сразу,
/// со свайпом для удаления и чекбоксом для завершения.

class TaskListScreen extends StatelessWidget {
  const TaskListScreen({super.key});

  Widget _buildTaskTile(
    BuildContext context,
    TodoProvider provider,
    TaskModel task, {
    bool showCategoryLine = true,
  }) {
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
          side: BorderSide(
            color: categoryColor.withValues(alpha: 0.6),
            width: 1.5,
          ),
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
              if (showCategoryLine && category != null) category.title,
              if (task.dueDate != null) formatDate(task.dueDate!),
            ].join(' • '),
          ),
          trailing: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: categoryColor,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TodoProvider>();
    final groupByCategory = context
        .watch<SettingsProvider>()
        .groupTasksByCategory;
    final tasks = provider.allTasks;

    if (tasks.isEmpty) {
      return const Center(child: Text('Задач пока нет'));
    }

    if (!groupByCategory) {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: tasks.length,
        itemBuilder: (context, index) =>
            _buildTaskTile(context, provider, tasks[index]),
      );
    }

    // Группировка по разделам: идём по отсекам в их текущем порядке,под каждым — только его задачи; отсеки без задач просто не показываем, чтобы список не пестрил пустыми заголовками.
    final categories = provider.categories;
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        final categoryTasks = provider.getTasksForCategory(category.id);
        if (categoryTasks.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 6),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: category.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    category.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
            for (final task in categoryTasks)
              _buildTaskTile(context, provider, task, showCategoryLine: false),
          ],
        );
      },
    );
  }
}
