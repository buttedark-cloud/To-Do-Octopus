import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/todo_provider.dart';
import '../../../core/models/task_model.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/providers/notes_provider.dart';
import '../../../core/models/note_model.dart';
import '../../notes/widgets/note_editor_dialog.dart';

/// Экран "Календарь" — простая месячная сетка без сторонних пакетов.
/// Под датой с задачами появляется точка; выбранный день показывает
/// список задач снизу.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _visibleMonth;
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month);
    _selectedDay = DateTime(now.year, now.month, now.day);
  }

  void _changeMonth(int delta) {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
    });
  }

  List<TaskModel> _tasksForDay(List<TaskModel> allTasks, DateTime day) {
    return allTasks
        .where(
          (t) =>
              t.dueDate != null &&
              t.dueDate!.year == day.year &&
              t.dueDate!.month == day.month &&
              t.dueDate!.day == day.day,
        )
        .toList();
  }

  List<NoteModel> _notesForDay(List<NoteModel> allNotes, DateTime day) {
    return allNotes
        .where(
          (n) =>
              n.reminderAt != null &&
              n.reminderAt!.year == day.year &&
              n.reminderAt!.month == day.month &&
              n.reminderAt!.day == day.day,
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TodoProvider>();
    final allTasks = provider.allTasks;
    final allNotes = context.watch<NotesProvider>().notes;

    final firstDayOfMonth = DateTime(
      _visibleMonth.year,
      _visibleMonth.month,
      1,
    );
    final daysInMonth = DateTime(
      _visibleMonth.year,
      _visibleMonth.month + 1,
      0,
    ).day;
    // weekday: Пн=1 ... Вс=7 — считаем пустые ячейки перед 1 числом месяца
    final leadingEmptyCells = firstDayOfMonth.weekday - 1;

    final selectedDayTasks = _tasksForDay(allTasks, _selectedDay);
    final selectedDayNotes = _notesForDay(allNotes, _selectedDay);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _changeMonth(-1),
              ),
              // ИСПРАВЛЕНИЕ БАГА (полоса переполнения справа): "Сентябрь
              // 2026" при увеличенном масштабе шрифта не помещался между
              // двумя стрелками. Expanded + FittedBox сжимают текст ровно
              // настолько, чтобы он влез между стрелками — вместо того
              // чтобы вылезать за край экрана.
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${monthNamesRu[_visibleMonth.month - 1]} ${_visibleMonth.year}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => _changeMonth(1),
              ),
            ],
          ),
        ),
        Row(
          children: weekdayShortNamesRu
              .map(
                (d) => Expanded(
                  child: Center(
                    child: Text(
                      d,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 4),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
          ),
          itemCount: leadingEmptyCells + daysInMonth,
          itemBuilder: (context, index) {
            if (index < leadingEmptyCells) return const SizedBox.shrink();

            final day = DateTime(
              _visibleMonth.year,
              _visibleMonth.month,
              index - leadingEmptyCells + 1,
            );
            final now = DateTime.now();
            final isSelected =
                day.year == _selectedDay.year &&
                day.month == _selectedDay.month &&
                day.day == _selectedDay.day;
            final isToday =
                now.year == day.year &&
                now.month == day.month &&
                now.day == day.day;
            final hasTasks =
                _tasksForDay(allTasks, day).isNotEmpty ||
                _notesForDay(allNotes, day).isNotEmpty;
            final primaryColor = Theme.of(context).colorScheme.primary;

            return GestureDetector(
              onTap: () => setState(() => _selectedDay = day),
              child: Container(
                margin: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: isSelected ? primaryColor : Colors.transparent,
                  shape: BoxShape.circle,
                  border: isToday && !isSelected
                      ? Border.all(color: primaryColor)
                      : null,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Text(
                      '${day.day}',
                      style: TextStyle(
                        color: isSelected ? Colors.white : null,
                        fontWeight: isToday ? FontWeight.bold : null,
                      ),
                    ),
                    if (hasTasks)
                      Positioned(
                        bottom: 4,
                        child: Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.white : primaryColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
        const Divider(height: 32),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'На ${formatDate(_selectedDay)}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: (selectedDayTasks.isEmpty && selectedDayNotes.isEmpty)
              ? const Center(child: Text('На этот день ничего нет'))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: selectedDayTasks.length + selectedDayNotes.length,
                  itemBuilder: (context, index) {
                    if (index < selectedDayTasks.length) {
                      final task = selectedDayTasks[index];
                      final category = provider.getCategoryById(
                        task.categoryId,
                      );
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: ListTile(
                          leading: Checkbox(
                            value: task.isCompleted,
                            onChanged: (_) =>
                                provider.toggleTaskStatus(task.id),
                          ),
                          title: Text(
                            task.title,
                            style: TextStyle(
                              decoration: task.isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          subtitle: category != null
                              ? Text(category.title)
                              : null,
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.redAccent,
                            ),
                            onPressed: () => provider.deleteTask(task.id),
                          ),
                        ),
                      );
                    }

                    // Дальше — заметки с напоминанием на этот день.
                    final note =
                        selectedDayNotes[index - selectedDayTasks.length];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      color: note.color,
                      child: ListTile(
                        leading: const Icon(
                          Icons.sticky_note_2_outlined,
                          color: Colors.black54,
                        ),
                        title: Text(
                          note.title.isEmpty ? 'Без названия' : note.title,
                          style: const TextStyle(color: Colors.black87),
                        ),
                        subtitle: Text(
                          '${note.reminderAt!.hour.toString().padLeft(2, '0')}:'
                          '${note.reminderAt!.minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(color: Colors.black54),
                        ),
                        onTap: () => showNoteEditor(context, initialNote: note),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
