import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import '../../../core/providers/todo_provider.dart';
import '../../../core/providers/user_profile_provider.dart';
import '../../../core/models/todo_category_model.dart';
import '../widgets/sticky_note_painter.dart';
import '../../../core/utils/date_formatter.dart';

class TodoListsScreen extends StatefulWidget {
  const TodoListsScreen({super.key});

  @override
  State<TodoListsScreen> createState() => _TodoListsScreenState();
}

class _TodoListsScreenState extends State<TodoListsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  bool _isAnimating = false;

  // Координаты для ручного свайпа пальцем
  double _dragX = 0;
  double _dragY = 0;

  // Дата, выбранная для новой задачи в форме быстрого добавления (по отсекам).
  // Пока не выбрана вручную — используется сегодняшняя дата.
  final Map<String, DateTime> _pendingDueDates = {};

  DateTime _dueDateFor(String categoryId) =>
      _pendingDueDates[categoryId] ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Логика улетания карты после свайпа
  void _triggerCardFlyAway(
    TodoProvider provider,
    double containerWidth,
    double containerHeight,
  ) {
    if (_isAnimating) return;
    setState(() {
      _isAnimating = true;
    });

    _animationController.forward().then((_) {
      provider.cycleCategories(); // Перекидываем карту вниз в провайдере
      _animationController.reset();
      setState(() {
        _dragX = 0;
        _dragY = 0;
        _isAnimating = false;
      });
    });
  }

  // Готовая палитра цветов для стикеров — этого достаточно, чтобы не тянуть
  // сторонний пакет-колорпикер ради одной фичи.
  static const List<Color> _stickerPalette = [
    Color(0xFF64B5F6), // синий
    Color(0xFFFF4081), // розовый
    Color(0xFFFFF59D), // жёлтый
    Color(0xFF8BC34A), // зелёный
    Color(0xFFFFAB91), // персиковый
    Color(0xFFB39DDB), // сиреневый
    Color(0xFF80CBC4), // бирюзовый
    Color(0xFFEF9A9A), // красноватый
    Color(0xFFFFCC80), // оранжевый
    Color(0xFF90A4AE), // серо-голубой
  ];

  // Диалог выбора нового цвета отсека
  Future<void> _showColorPicker(
    BuildContext context,
    TodoProvider provider,
    TodoCategoryModel card,
  ) async {
    final chosen = await showDialog<Color>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Выберите цвет'),
        content: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _stickerPalette.map((color) {
            final isSelected = color.value == card.color.value;
            return GestureDetector(
              onTap: () => Navigator.pop(context, color),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? Colors.black87 : Colors.black26,
                    width: isSelected ? 3 : 1,
                  ),
                ),
                child: isSelected
                    ? const Icon(Icons.check, size: 18, color: Colors.black87)
                    : null,
              ),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
        ],
      ),
    );
    if (chosen != null) {
      provider.changeCategoryColor(card.id, chosen);
    }
  }

  // Диалог выбора даты для новой задачи (кнопка-календарь у формы добавления)
  Future<void> _pickDueDate(BuildContext context, String categoryId) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDateFor(categoryId),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      helpText: 'Дата задачи',
      cancelText: 'Отмена',
      confirmText: 'Готово',
    );
    if (picked != null) {
      setState(() => _pendingDueDates[categoryId] = picked);
    }
  }

  // Диалог подтверждения перед безвозвратным удалением отсека
  Future<void> _confirmDeleteCategory(
    BuildContext context,
    TodoProvider provider,
    TodoCategoryModel card,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить отсек?'),
        content: Text(
          'Отсек «${card.title}» и все задачи внутри него будут удалены безвозвратно.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      provider.deleteCategory(card.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final todoProvider = Provider.of<TodoProvider>(context);
    final categories = todoProvider.categories;

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final containerWidth = constraints.maxWidth * 0.85;
            final containerHeight = constraints.maxHeight * 0.7;

            if (categories.isEmpty) {
              return const Center(child: Text('Нет отсеков. Добавьте новый!'));
            }

            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                Center(
                  child: SizedBox(
                    width: containerWidth,
                    height: containerHeight,
                    child: AnimatedBuilder(
                      animation: _animationController,
                      builder: (context, child) {
                        return Stack(
                          clipBehavior: Clip.none,
                          children: List.generate(categories.length, (index) {
                            final reversedIndex = categories.length - 1 - index;
                            final card = categories[reversedIndex];
                            final isTopCard = reversedIndex == 0;

                            // Расчет трансформаций при ручном свайпе или автоматическом улете
                            if (isTopCard) {
                              double offsetX = _dragX;
                              double offsetY = _dragY;
                              double rotation =
                                  (_dragX / containerWidth) * (math.pi / 6);

                              if (_isAnimating) {
                                final val = _animationController.value;
                                offsetX =
                                    _dragX +
                                    (val * (containerWidth - _dragX + 100));
                                offsetY =
                                    _dragY +
                                    (val * (containerHeight - _dragY + 100));
                                rotation = rotation + (val * (math.pi / 6));
                              }

                              return Transform.translate(
                                offset: Offset(offsetX, offsetY),
                                child: Transform.rotate(
                                  angle: rotation,
                                  child: _buildGestureWrapper(
                                    card,
                                    containerWidth,
                                    containerHeight,
                                    todoProvider,
                                  ),
                                ),
                              );
                            }

                            // Каскадные слои сзади
                            final positionFactor = reversedIndex.toDouble();
                            if (positionFactor > 3) {
                              return const SizedBox.shrink();
                            }

                            return Transform.translate(
                              offset: Offset(
                                -positionFactor * 12,
                                -positionFactor * 18,
                              ),
                              child: _buildCardContent(
                                card,
                                containerWidth,
                                containerHeight,
                                todoProvider,
                                isTopCard: false,
                              ),
                            );
                          }),
                        );
                      },
                    ),
                  ),
                ),
                const Spacer(),
                // Кнопка создания новой карточки (оставим её системной для простоты)
                Padding(
                  padding: const EdgeInsets.only(bottom: 24.0),
                  child: FloatingActionButton(
                    onPressed: () => todoProvider.addCategory(
                      'Новый отсек',
                      Colors.orangeAccent.shade100,
                    ),
                    backgroundColor: const Color(0xFF8BC34A),
                    child: const Icon(Icons.add, color: Colors.white, size: 30),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // Обертка для перехвата свайпов пальцем (только для верхней карты)
  Widget _buildGestureWrapper(
    TodoCategoryModel card,
    double w,
    double h,
    TodoProvider provider,
  ) {
    return GestureDetector(
      onPanUpdate: (details) {
        if (_isAnimating) return;
        setState(() {
          _dragX += details.delta.dx;
          _dragY += details.delta.dy;
        });
      },
      onPanEnd: (details) {
        if (_isAnimating) return;
        // Если протащили достаточно далеко вправо или вниз — запускаем полет карты
        if (_dragX > w * 0.3 || _dragY > h * 0.3) {
          _triggerCardFlyAway(provider, w, h);
        } else {
          // Если протащили мало — возвращаем карту на место
          setState(() {
            _dragX = 0;
            _dragY = 0;
          });
        }
      },
      child: _buildCardContent(card, w, h, provider, isTopCard: true),
    );
  }

  // Внутреннее устройство карточки со всеми текстовыми полями
  Widget _buildCardContent(
    TodoCategoryModel card,
    double w,
    double h,
    TodoProvider provider, {
    required bool isTopCard,
  }) {
    const double cornerSize = 35.0;
    final tasks = provider.getTasksForCategory(card.id);
    final authorName = context.watch<UserProfileProvider>().name;

    final TextEditingController taskInputController = TextEditingController();
    final TextEditingController titleEditController = TextEditingController(
      text: card.title,
    );

    Path createCardPath(Size size) {
      return Path()
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width, size.height - cornerSize)
        ..lineTo(size.width - cornerSize, size.height)
        ..lineTo(0, size.height)
        ..close();
    }

    return SizedBox(
      width: w,
      height: h,
      child: PhysicalShape(
        clipper: StickyNoteClipper(createCardPath),
        color: Colors.transparent,
        elevation: 5,
        shadowColor: Colors.black.withOpacity(0.3),
        child: CustomPaint(
          painter: StickyNotePainter(baseColor: card.color),
          child: Padding(
            padding: const EdgeInsets.only(
              top: 20.0,
              left: 20.0,
              right: 20.0,
              bottom: 40.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. НАЗВАНИЕ КАРТОЧКИ (инлайн-переименование) + КНОПКА УДАЛЕНИЯ
                Row(
                  children: [
                    Expanded(
                      child: Focus(
                        onFocusChange: (hasFocus) {
                          if (!hasFocus &&
                              titleEditController.text.trim().isNotEmpty) {
                            provider.renameCategory(
                              card.id,
                              titleEditController.text.trim(),
                            );
                          }
                        },
                        child: TextFormField(
                          controller: titleEditController,
                          enabled: isTopCard, // Переименовать можно только верхнюю
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ),
                    // Менять цвет и удалять можно только верхнюю (активную) карточку
                    if (isTopCard) ...[
                      IconButton(
                        icon: const Icon(
                          Icons.palette_outlined,
                          color: Colors.black54,
                        ),
                        tooltip: 'Изменить цвет',
                        onPressed: () =>
                            _showColorPicker(context, provider, card),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.black54,
                        ),
                        tooltip: 'Удалить отсек',
                        onPressed: () =>
                            _confirmDeleteCategory(context, provider, card),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),

                // 2. СПИСОК ЗАДАЧ
                Expanded(
                  child: ListView.builder(
                    itemCount: tasks.length,
                    itemBuilder: (context, index) {
                      final task = tasks[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        leading: Checkbox(
                          value: task.isCompleted,
                          activeColor: Colors.black87,
                          onChanged: (val) =>
                              provider.toggleTaskStatus(task.id),
                        ),
                        title: Text(
                          task.title,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.black87,
                            decoration: task.isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // 3. ФОРМА БЫСТРОГО ДОБАВЛЕНИЯ ЗАДАЧИ ПРЯМО НА КАРТЕ
                if (isTopCard) ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: taskInputController,
                          style: const TextStyle(
                            fontSize: 15,
                            color: Colors.black87,
                          ),
                          decoration: const InputDecoration(
                            hintStyle: TextStyle(color: Colors.black45),
                            border: UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.black38),
                            ),
                            focusedBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.black87),
                            ),
                            isDense: true,
                          ),
                        ),
                      ),
                      // Кнопка-календарь — выбрать дату для новой задачи
                      IconButton(
                        icon: const Icon(
                          Icons.calendar_month_outlined,
                          color: Colors.black87,
                          size: 22,
                        ),
                        tooltip: 'Выбрать дату',
                        onPressed: () => _pickDueDate(context, card.id),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.add_circle,
                          color: Colors.black87,
                          size: 26,
                        ),
                        onPressed: () {
                          if (taskInputController.text.trim().isEmpty) return;
                          provider.addTask(
                            title: taskInputController.text.trim(),
                            categoryId: card.id,
                            dueDate: _dueDateFor(card.id),
                          );
                          taskInputController.clear();
                          // Сбрасываем выбор даты обратно на "сегодня" для следующей задачи
                          setState(() => _pendingDueDates.remove(card.id));
                        },
                      ),
                    ],
                  ),
                  // Подпись с выбранной датой — тоже открывает выбор даты по тапу
                  GestureDetector(
                    onTap: () => _pickDueDate(context, card.id),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2, bottom: 6),
                      child: Text(
                        'Дата: ${formatDate(_dueDateFor(card.id))}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                  ),
                ],
                Align(
                  alignment: Alignment.bottomLeft,
                  child: Text(
                    authorName,
                    style: const TextStyle(
                      color: Colors.black45,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
