import 'package:flutter/material.dart';
import '../../../core/models/task_model.dart';
import '../../../core/utils/date_formatter.dart';

/// Шторка со списком просроченных задач.
/// Раньше показывала фиктивные карточки по количеству, теперь — реальные задачи.
class OverdueTasksBottomSheet extends StatelessWidget {
  final List<TaskModel> overdueTasks;

  const OverdueTasksBottomSheet({super.key, required this.overdueTasks});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5, // Открывается на половину экрана
      minChildSize: 0.3, // Минимальный размер при перетаскивании вниз
      maxChildSize: 0.85, // Максимальный размер вверх
      expand: false,
      builder: (context, scrollController) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              children: [
                const SizedBox(height: 12),
                // Серая полосочка-индикатор сверху шторки
                Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Просроченные задачи',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                // Список просроченных задач
                Expanded(
                  child: overdueTasks.isEmpty
                      ? const Center(child: Text('Просроченных задач нет 🎉'))
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: overdueTasks.length,
                          itemBuilder: (context, index) {
                            final task = overdueTasks[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              child: ListTile(
                                leading: const Icon(
                                  Icons.warning_amber_rounded,
                                  color: Colors.red,
                                ),
                                title: Text(task.title),
                                subtitle: Text(
                                  task.dueDate != null
                                      ? 'Дедлайн был: ${formatDate(task.dueDate!)}'
                                      : 'Дедлайн просрочен',
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
