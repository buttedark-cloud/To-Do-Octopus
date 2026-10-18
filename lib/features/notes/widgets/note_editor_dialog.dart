import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../core/models/note_model.dart';
import '../../../core/providers/notes_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/utils/note_palette.dart';
import '../../../core/utils/emoji_palette.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/services/local_file_storage_service.dart';
import '../../../core/services/image_compress_service.dart';
import '../../../core/utils/image_provider_for.dart';
import '../../../core/utils/capped_text_scale.dart';

/// Открывает "окошко" заметки поверх экрана — с необычной анимацией
/// (лёгкий отскок при появлении вместо стандартного плоского фейда).
/// initialNote == null → создание новой заметки, иначе → редактирование.
Future<void> showNoteEditor(BuildContext context, {NoteModel? initialNote}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Заметка',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 380),
    pageBuilder: (context, animation, secondaryAnimation) {
      return _NoteEditorDialog(initialNote: initialNote);
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutBack);
      return Transform.scale(
        scale: curved.value < 0 ? 0 : curved.value,
        child: Opacity(
          opacity: animation.value.clamp(0.0, 1.0),
          child: child,
        ),
      );
    },
  );
}

class _NoteEditorDialog extends StatefulWidget {
  final NoteModel? initialNote;
  const _NoteEditorDialog({this.initialNote});

  @override
  State<_NoteEditorDialog> createState() => _NoteEditorDialogState();
}

class _NoteEditorDialogState extends State<_NoteEditorDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  late Color _selectedColor;
  String? _imagePath;
  DateTime? _reminderAt;
  bool _showEmojiPicker = false;
  bool _processingImage = false;

  // Дата создания заметки — для новой заметки это "сейчас" (совпадёт с
  // тем, что реально запишется в NoteModel.createdAt при сохранении),
  // для существующей — берём как есть, никогда не меняем при редактировании.
  late final DateTime _createdAt;

  bool get _isEditing => widget.initialNote != null;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialNote?.title ?? '');
    _contentController = TextEditingController(text: widget.initialNote?.content ?? '');
    // Для новой заметки — начинаем с цвета по умолчанию, который человек
    // выбрал в Настройках (цветовое колесо), а не с фиксированного первого
    // цвета палитры.
    _selectedColor = widget.initialNote?.color ??
        context.read<SettingsProvider>().defaultNoteColor;
    _imagePath = widget.initialNote?.imagePath;
    _reminderAt = widget.initialNote?.reminderAt;
    _createdAt = widget.initialNote?.createdAt ?? DateTime.now();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  // Вставляет эмодзи в текст заметки прямо в позицию курсора
  void _insertEmoji(String emoji) {
    final text = _contentController.text;
    final selection = _contentController.selection;
    final start = selection.start >= 0 ? selection.start : text.length;
    final end = selection.end >= 0 ? selection.end : text.length;
    final newText = text.replaceRange(start, end, emoji);
    _contentController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + emoji.length),
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    if (mounted) setState(() => _processingImage = true);
    try {
      // Сжимаем фото до ~1 МБ (7-мегабайтный снимок с камеры → несколько
      // сотен КБ), затем копируем в постоянную папку приложения: путь из
      // image_picker временный, Android может очистить его сам. В облако
      // картинка уйдёт после сохранения заметки (см. NotesProvider).
      final compressedPath = await ImageCompressService.instance
          .compressUnderLimit(picked.path);
      final persistedPath = await LocalFileStorageService.instance
          .persistUnique(compressedPath, 'note');
      if (mounted) setState(() => _imagePath = persistedPath);
    } finally {
      if (mounted) setState(() => _processingImage = false);
    }
  }

  // Точная дата и время напоминания по заметке — та же логика, что и у
  // задач в отсеках: сначала дата, потом время, вместе дают точный момент
  // для настоящего push-уведомления.
  Future<void> _pickReminder() async {
    final now = DateTime.now();
    final initial = _reminderAt ?? now;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      helpText: 'Дата напоминания',
      cancelText: 'Отмена',
      confirmText: 'Далее',
      builder: (context, child) => capTextScale(context, child),
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      helpText: 'Время напоминания',
      cancelText: 'Отмена',
      confirmText: 'Готово',
      builder: (context, child) => capTextScale(context, child),
    );
    if (!mounted) return;

    setState(() {
      _reminderAt = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime?.hour ?? 9,
        pickedTime?.minute ?? 0,
      );
    });
  }

  void _save() {
    final notesProvider = context.read<NotesProvider>();
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty && content.isEmpty && _imagePath == null) {
      Navigator.pop(context);
      return;
    }

    if (_isEditing) {
      notesProvider.updateNote(
        widget.initialNote!.id,
        title: title,
        content: content,
        color: _selectedColor,
        imagePath: _imagePath,
        clearImage: _imagePath == null,
        reminderAt: _reminderAt,
        clearReminder: _reminderAt == null,
      );
    } else {
      notesProvider.addNote(
        title: title,
        content: content,
        color: _selectedColor,
        imagePath: _imagePath,
        reminderAt: _reminderAt,
      );
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    // ИСПРАВЛЕНИЕ БАГА (жёлто-чёрная полоса переполнения при сохранении):
    // раньше весь Column не был прокручиваемым и жил внутри
    // ConstrainedBox(maxHeight: 640) без учёта клавиатуры — как только
    // содержимое (палитра + заголовок + картинка + текст + напоминание +
    // панель эмодзи + нижние кнопки) не помещалось в это ограничение, ИЛИ
    // когда клавиатура выезжала и "съедала" часть экрана, Flutter рисовал
    // предупреждение о переполнении (тот самый жёлто-чёрный паттерн) —
    // это не зависит от конкретного телефона, оно проявится на любом
    // экране, где итоговая высота не влезает.
    //
    // Теперь: 1) весь диалог сдвигается вверх при появлении клавиатуры
    // (Padding с MediaQuery.viewInsets — так делает Scaffold, здесь этого
    // не было, потому что это не Scaffold, а showGeneralDialog); 2) весь
    // контент обёрнут в один SingleChildScrollView, поэтому при нехватке
    // места он просто прокручивается, а не переполняется.
    return Padding(
      padding: MediaQuery.of(context).viewInsets,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 380,
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Material(
              color: _selectedColor,
              borderRadius: BorderRadius.circular(24),
              elevation: 12,
              shadowColor: Colors.black.withValues(alpha: 0.4),
              child: Padding(
                padding: const EdgeInsets.all(18.0),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Заголовок окошка + кнопка закрыть
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _isEditing ? 'Заметка' : 'Новая заметка',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                          InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () => Navigator.pop(context),
                            child: const Padding(
                              padding: EdgeInsets.all(4.0),
                              child: Icon(Icons.close, size: 20, color: Colors.black54),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Палитра цветов заметки
                      SizedBox(
                        height: 32,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: notePalette.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final color = notePalette[index];
                            final isSelected = color.toARGB32() == _selectedColor.toARGB32();
                            return GestureDetector(
                              onTap: () => setState(() => _selectedColor = color),
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected ? Colors.black87 : Colors.black26,
                                    width: isSelected ? 2.5 : 1,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Заголовок заметки
                      TextField(
                        controller: _titleController,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Заголовок',
                          hintStyle: TextStyle(color: Colors.black38),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Картинка — ИСПРАВЛЕНИЕ БАГА (обрезка): раньше был
                      // фиксированный height: 140 + BoxFit.cover, который
                      // всегда обрезал края картинки под этот прямоугольник.
                      // Теперь BoxFit.contain — картинка целиком вписывается
                      // в отведённую область, ничего не обрезается (по
                      // бокам/сверху-снизу может остаться немного фона
                      // заметки, если пропорции не совпадают — это
                      // ожидаемо и не является багом).
                      if (_imagePath != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(maxHeight: 220),
                                  child: Image(
                                    image: imageProviderFor(_imagePath!),
                                    width: double.infinity,
                                    fit: BoxFit.contain,
                                    // ИСПРАВЛЕНИЕ: раньше при повреждённом/
                                    // недоступном файле картинки Flutter
                                    // показывал стандартную перечёркнутую
                                    // иконку "битого" изображения — теперь
                                    // вместо неё понятная надпись.
                                    errorBuilder: (context, error, stackTrace) =>
                                        Container(
                                      height: 100,
                                      alignment: Alignment.center,
                                      color: Colors.black12,
                                      child: const Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.broken_image_outlined,
                                            color: Colors.black45,
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            'Не удалось загрузить картинку',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.black54,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                right: 6,
                                top: 6,
                                child: GestureDetector(
                                  onTap: () => setState(() => _imagePath = null),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.close, size: 16, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Текст заметки — больше не вложенный
                      // SingleChildScrollView+Flexible (это и давало
                      // конфликт constraints внутри уже прокручиваемого
                      // родителя), просто обычное поле нужной минимальной
                      // высоты — растёт вместе со всем диалогом.
                      TextField(
                        controller: _contentController,
                        maxLines: null,
                        minLines: 4,
                        style: const TextStyle(fontSize: 15, color: Colors.black87),
                        decoration: const InputDecoration(
                          hintText: 'Ваша заметка...',
                          hintStyle: TextStyle(color: Colors.black38),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),

                      // Напоминание — точная дата и время push-уведомления
                      GestureDetector(
                        onTap: _pickReminder,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.notifications_outlined,
                                size: 18,
                                color: Colors.black54,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _reminderAt == null
                                      ? 'Добавить напоминание'
                                      : '${_reminderAt!.day.toString().padLeft(2, '0')}.'
                                          '${_reminderAt!.month.toString().padLeft(2, '0')}.'
                                          '${_reminderAt!.year} · '
                                          '${_reminderAt!.hour.toString().padLeft(2, '0')}:'
                                          '${_reminderAt!.minute.toString().padLeft(2, '0')}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.black54,
                                  ),
                                ),
                              ),
                              if (_reminderAt != null)
                                InkWell(
                                  onTap: () => setState(() => _reminderAt = null),
                                  child: const Icon(
                                    Icons.close,
                                    size: 16,
                                    color: Colors.black45,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),

                      // Панель emoji (раскрывается по кнопке снизу)
                      AnimatedCrossFade(
                        duration: const Duration(milliseconds: 200),
                        crossFadeState: _showEmojiPicker
                            ? CrossFadeState.showFirst
                            : CrossFadeState.showSecond,
                        firstChild: SizedBox(
                          height: 130,
                          child: GridView.builder(
                            padding: const EdgeInsets.only(top: 8),
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 8,
                            ),
                            itemCount: emojiPalette.length,
                            itemBuilder: (context, index) {
                              final emoji = emojiPalette[index];
                              return InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () => _insertEmoji(emoji),
                                child: Center(
                                  child: Text(emoji, style: const TextStyle(fontSize: 20)),
                                ),
                              );
                            },
                          ),
                        ),
                        secondChild: const SizedBox.shrink(),
                      ),

                      const SizedBox(height: 8),

                      // Дата создания — теперь внизу, отдельной строкой,
                      // не разрывает заголовок и текст заметки.
                      Text(
                        'Создано: ${formatDate(_createdAt)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black45,
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Нижняя панель: смайлики/фото — отдельным рядом,
                      // Отмена/Сохранить — отдельным рядом ниже.
                      //
                      // ИСПРАВЛЕНИЕ (повторное — прошлая версия с
                      // горизонтальным скроллом технически убирала ошибку
                      // переполнения, но кнопка "Сохранить" уезжала за
                      // край видимой области и человек просто не мог её
                      // увидеть/нажать при увеличенном масштабе шрифта).
                      // Теперь кнопки Отмена/Сохранить занимают ровно
                      // половину ширины каждая (Expanded) — гарантированно
                      // помещаются целиком при любом масштабе, просто
                      // становятся выше, если текст не помещается в одну
                      // строку, а не уезжают в сторону.
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.emoji_emotions_outlined,
                              size: 22,
                              color: _showEmojiPicker ? Colors.black87 : Colors.black45,
                            ),
                            tooltip: 'Смайлики',
                            visualDensity: VisualDensity.compact,
                            onPressed: () =>
                                setState(() => _showEmojiPicker = !_showEmojiPicker),
                          ),
                          IconButton(
                            icon: const Icon(Icons.image_outlined, size: 22, color: Colors.black45),
                            tooltip: 'Добавить фото',
                            visualDensity: VisualDensity.compact,
                            onPressed: _processingImage ? null : _pickImage,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text(
                                'Отмена',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton(
                              onPressed: _save,
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.black87,
                              ),
                              child: const Text(
                                'Сохранить',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
