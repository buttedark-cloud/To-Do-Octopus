import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:to_do/auth_provider.dart';
import 'package:to_do/core/services/battery_optimization_service.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/providers/todo_provider.dart';
import '../../../core/providers/notes_provider.dart';
import '../../../core/providers/user_profile_provider.dart';
import '../../../core/services/sync_manager.dart';

/// Экран "Настройки" — вынесен из профиля отдельно, чтобы не перегружать
/// его: цвет по умолчанию для тасков и заметок (полноценное цветовое
/// колесо, а не фиксированная палитра) и смена пароля.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _openColorWheel({
    required BuildContext context,
    required String title,
    required Color current,
    required ValueChanged<Color> onChanged,
  }) async {
    Color picked = current;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: current,
            onColorChanged: (color) => picked = color,
            enableAlpha: false,
            labelTypes: const [],
            pickerAreaHeightPercent: 0.7,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              onChanged(picked);
              Navigator.pop(context);
            },
            child: const Text('Готово'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final passwordController = TextEditingController();
    final needsPassword = auth.hasPasswordLogin;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Удалить аккаунт?'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Будут безвозвратно удалены все ваши задачи, заметки, '
                'картинки и профиль — и на этом телефоне, и в облаке. '
                'Отменить это нельзя.',
              ),
              if (needsPassword) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Ваш пароль для подтверждения',
                    border: OutlineInputBorder(),
                  ),
                ),
              ] else ...[
                const SizedBox(height: 12),
                const Text(
                  'Для подтверждения нужно будет ещё раз выбрать свой '
                  'аккаунт Google.',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Удалить навсегда',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final sync = context.read<SyncManager>();
    final todo = context.read<TodoProvider>();
    final notes = context.read<NotesProvider>();
    final profile = context.read<UserProfileProvider>();
    final settings = context.read<SettingsProvider>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final result = await auth.deleteAccount(password: passwordController.text);
    if (result.cancelled) return;
    if (!result.success) {
      messenger.showSnackBar(
        SnackBar(content: Text(result.errorMessage ?? 'Не удалось удалить')),
      );
      return;
    }

    // Аккаунт удалён — чистим всё локальное и выходим на экран входа.
    await sync.resetLocalTimestamp();
    await todo.resetToDefaults();
    await notes.resetToDefaults();
    await profile.resetToDefaults();
    await settings.resetToDefaults();
    await auth.signOut();
    navigator.popUntil((route) => route.isFirst);
  }

  Future<void> _openChangePasswordDialog(BuildContext context) async {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final newRepeatController = TextEditingController();
    String? error;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('Смена пароля'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: currentController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Текущий пароль',
                    ),
                  ),
                  TextField(
                    controller: newController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Новый пароль (минимум 6 символов)',
                    ),
                  ),
                  TextField(
                    controller: newRepeatController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Повторите новый пароль',
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text(error!, style: const TextStyle(color: Colors.red)),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Отмена'),
                ),
                FilledButton(
                  onPressed: () async {
                    if (newController.text != newRepeatController.text) {
                      setDialogState(() => error = 'Пароли не совпадают');
                      return;
                    }
                    if (newController.text.trim().length < 6) {
                      setDialogState(
                        () => error = 'Пароль должен быть не короче 6 символов',
                      );
                      return;
                    }
                    final result = await dialogContext
                        .read<AuthProvider>()
                        .changePassword(
                          currentPassword: currentController.text,
                          newPassword: newController.text.trim(),
                        );
                    if (!dialogContext.mounted) return;
                    if (result.success) {
                      Navigator.pop(dialogContext);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Пароль изменён')),
                      );
                    } else {
                      setDialogState(
                        () => error =
                            result.errorMessage ?? 'Не удалось сменить пароль',
                      );
                    }
                  },
                  child: const Text('Сохранить'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _openDoneCategoryPicker(BuildContext context) async {
    final todoProvider = context.read<TodoProvider>();
    final categories = todoProvider.categories;
    if (categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Сначала создай хотя бы один отсек на Главной'),
        ),
      );
      return;
    }
    final currentDoneId = todoProvider.doneCategoryId;

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Отсек «Сделано»'),
        // ИСПРАВЛЕНИЕ БАГА (диалог всё ещё переполнялся при огромном
        // масштабе шрифта): раньше прокручиваемым был только список
        // отсеков — а текст-объяснение НАД ним ничем не был ограничен.
        // При экстремальном масштабе один этот текст уже не помещался, и
        // диалог переполнялся ДО того, как доходило до списка. Теперь
        // прокручивается ВЕСЬ контент целиком — текст и список вместе,
        // одним блоком.
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Выполненные задачи автоматически переносятся в выбранный '
                  'здесь отсек. Если удалить прежний отсек «Сделано» — просто '
                  'выбери новый, чтобы завершённым задачам было куда деваться.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color.fromARGB(137, 249, 0, 0),
                  ),
                ),
                const SizedBox(height: 12),
                RadioGroup<String>(
                  groupValue: currentDoneId,
                  onChanged: (value) {
                    if (value != null) {
                      todoProvider.setDoneCategory(value);
                    }
                    Navigator.pop(dialogContext);
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ...categories.map(
                        (category) => RadioListTile<String>(
                          value: category.id,
                          title: Text(category.title),
                          secondary: CircleAvatar(
                            radius: 10,
                            backgroundColor: category.color,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final todoProvider = context.watch<TodoProvider>();
    final doneCategoryId = todoProvider.doneCategoryId;
    final doneCategoryMatches = todoProvider.categories.where(
      (c) => c.id == doneCategoryId,
    );
    final doneCategoryTitle = doneCategoryMatches.isEmpty
        ? null
        : doneCategoryMatches.first.title;
    // "Сменить пароль" имеет смысл только для email/пароль-аккаунтов —
    // у входа через Google своего пароля в этом приложении нет, и
    // попытка сменить его раньше приводила бы к невнятной ошибке.
    final signedInWithPassword =
        context.watch<AuthProvider>().hasPasswordLogin;

    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        // Раньше последний пункт (например, "Сменить пароль") прилипал
        // прямо к нижнему краю экрана — добавляем отступ снизу, с учётом
        // системной области телефона (жесты/навигационная панель), как
        // это уже сделано, например, в NotesScreen.
        padding: EdgeInsets.only(
          bottom: 24 + MediaQuery.of(context).padding.bottom,
        ),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              'Цвета по умолчанию',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
          ListTile(
            leading: CircleAvatar(backgroundColor: settings.defaultTaskColor),
            title: const Text('Цвет новых отсеков-стикеров'),
            subtitle: const Text(
              'Применяется при создании нового отсека на Главной',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openColorWheel(
              context: context,
              title: 'Цвет отсеков',
              current: settings.defaultTaskColor,
              onChanged: (color) =>
                  context.read<SettingsProvider>().setDefaultTaskColor(color),
            ),
          ),
          ListTile(
            leading: CircleAvatar(backgroundColor: settings.defaultNoteColor),
            title: const Text('Цвет новых заметок'),
            subtitle: const Text('Применяется при создании новой заметки'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openColorWheel(
              context: context,
              title: 'Цвет заметок',
              current: settings.defaultNoteColor,
              onChanged: (color) =>
                  context.read<SettingsProvider>().setDefaultNoteColor(color),
            ),
          ),
          const Divider(height: 32),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text(
              'Отсеки и списки',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.check_circle_outline),
            title: const Text('Отсек «Сделано»'),
            subtitle: Text(
              doneCategoryTitle != null
                  ? 'Сейчас: $doneCategoryTitle'
                  : 'Не выбран — выполненные задачи никуда не переносятся',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openDoneCategoryPicker(context),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.sort),
            title: const Text('Группировать «Списки» по разделам'),
            subtitle: const Text('Иначе — общий список всех задач подряд'),
            value: settings.groupTasksByCategory,
            onChanged: (value) =>
                context.read<SettingsProvider>().setGroupTasksByCategory(value),
          ),
          const Divider(height: 32),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text(
              'Уведомления',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
          FutureBuilder<bool>(
            future: BatteryOptimizationService.instance
                .isIgnoringBatteryOptimizations(),
            builder: (context, snapshot) {
              final isSafe = snapshot.data ?? false;
              return ListTile(
                leading: Icon(
                  isSafe
                      ? Icons.notifications_active_outlined
                      : Icons.notifications_off_outlined,
                ),
                title: const Text('Надёжные уведомления'),
                subtitle: Text(
                  isSafe
                      ? 'Включено — система не будет их ограничивать'
                      : 'Система может задерживать или блокировать их',
                ),
                trailing: isSafe ? null : const Icon(Icons.chevron_right),
                onTap: isSafe
                    ? null
                    : () => BatteryOptimizationService.instance
                          .requestIgnoreBatteryOptimizations(),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.rocket_launch_outlined),
            title: const Text('Автозапуск (для MIUI/Xiaomi)'),
            subtitle: const Text(
              'На телефонах Xiaomi это отдельное разрешение — включи его, '
              'если уведомления всё равно не приходят',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () =>
                BatteryOptimizationService.instance.openAutoStartSettings(),
          ),
          const Divider(height: 32),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text(
              'Аккаунт',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
          if (signedInWithPassword)
            ListTile(
              leading: const Icon(Icons.lock_reset_outlined),
              title: const Text('Сменить пароль'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openChangePasswordDialog(context),
            ),
          ListTile(
            leading: const Icon(Icons.delete_forever_outlined, color: Colors.red),
            title: const Text(
              'Удалить аккаунт',
              style: TextStyle(color: Colors.red),
            ),
            subtitle: const Text('Все данные будут удалены безвозвратно'),
            onTap: () => _confirmDeleteAccount(context),
          ),
        ],
      ),
    );
  }
}
