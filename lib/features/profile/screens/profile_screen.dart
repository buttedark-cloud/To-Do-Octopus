import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:to_do/auth_provider.dart';
import 'package:to_do/features/profile/profile_foto.dart';
import 'settings_screen.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/providers/user_profile_provider.dart';
import '../../../core/providers/todo_provider.dart';
import '../../../core/providers/notes_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/services/sync_manager.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  // Диалог редактирования имени — оно же появится внизу карточек-стикеров
  Future<void> _showEditNameDialog(
    BuildContext context,
    UserProfileProvider userProfile,
  ) async {
    final controller = TextEditingController(text: userProfile.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ваше имя'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Например, Аружан'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    if (newName != null) {
      userProfile.updateName(newName);
    }
  }

  // ИСПРАВЛЕНИЕ КРИТИЧЕСКОГО БАГА: раньше при выходе локальные данные
  // (имя, фото, задачи, заметки, настройки) просто оставались на
  // телефоне — следующий человек, вошедший на этом же устройстве, видел
  // чужой профиль. Теперь ПЕРЕД выходом всё это явно сбрасывается.
  Future<void> _handleSignOut(BuildContext context) async {
    // Берём всё нужное ДО первого await — после него context использовать
    // небезопасно.
    final todo = context.read<TodoProvider>();
    final notes = context.read<NotesProvider>();
    final profile = context.read<UserProfileProvider>();
    final settings = context.read<SettingsProvider>();
    final sync = context.read<SyncManager>();
    final auth = context.read<AuthProvider>();
    final navigator = Navigator.of(context);

    await todo.resetToDefaults();
    await notes.resetToDefaults();
    await profile.resetToDefaults();
    await settings.resetToDefaults();
    await sync.resetLocalTimestamp();
    await auth.signOut();

    navigator.popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final userProfile = context.watch<UserProfileProvider>();
    // Реальный email, с которым человек зарегистрировался/вошёл —
    // раньше здесь всегда была статичная надпись "user@example.com".
    final userEmail = context.watch<AuthProvider>().currentUser?.email;

    return Scaffold(
      appBar: AppBar(title: const Text('Профиль')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),

        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 20),
              Center(
                child: Column(
                  children: [
                    const ProfileFoto(),
                    const SizedBox(height: 16),
                    Text(
                      userProfile.name,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      userEmail ?? 'Email не указан',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              Card(
                child: ListView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    ListTile(
                      leading: const Icon(Icons.badge_outlined),
                      title: const Text('Имя на карточках'),
                      subtitle: Text(userProfile.name),
                      trailing: const Icon(Icons.edit_outlined),
                      onTap: () => _showEditNameDialog(context, userProfile),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.dark_mode_outlined),
                      title: const Text('Темная тема'),

                      trailing: Switch(
                        value: Theme.of(context).brightness == Brightness.dark,
                        onChanged: (value) {
                          themeProvider.toggleTheme(value);
                        },
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.settings_outlined),
                      title: const Text('Настройки'),
                      subtitle: const Text('Цвета по умолчанию, смена пароля'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SettingsScreen(),
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(
                        Icons.logout,
                        color: Colors.redAccent,
                      ),
                      title: const Text(
                        'Выйти из аккаунта',
                        style: TextStyle(color: Colors.redAccent),
                      ),
                      onTap: () => _handleSignOut(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
