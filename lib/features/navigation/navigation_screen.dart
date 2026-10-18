import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:to_do/core/services/battery_optimization_service.dart';
import '../../core/providers/todo_provider.dart';
import 'widgets/custom_navigation_widget.dart';
import 'widgets/app_bottom_bar.dart';
import '../todo_lists/screens/todo_lists_screen.dart';
import '../task_list/screens/task_list_screen.dart';
import '../calendar/screens/calendar_screen.dart';
import '../notes/screens/notes_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> with WidgetsBindingObserver {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAskAboutBattery());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Догоняем изменения, сделанные из мини-окошка виджета, пока
      // приложение было свёрнуто.
      context.read<TodoProvider>().loadFromPrefs();
    }
  }

  // Спрашиваем один раз за всё время: если система может ограничивать
  // приложение в фоне — уведомления о задачах и заметках могут
  // не доходить. Показываем понятное объяснение с одной кнопкой,
  // а не просто отправляем человека рыться в настройках самому.
  Future<void> _maybeAskAboutBattery() async {
    final alreadyIgnoring = await BatteryOptimizationService.instance.isIgnoringBatteryOptimizations();
    if (alreadyIgnoring) return;

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('asked_battery_optimization') ?? false) return;
    await prefs.setBool('asked_battery_optimization', true);

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Надёжные уведомления'),
        content: const Text(
          'Чтобы напоминания о задачах и заметках приходили вовремя, '
          'даже когда приложение свёрнуто, разреши ему работать в фоне '
          'без ограничений. Это можно изменить позже в Настройках.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Позже')),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              BatteryOptimizationService.instance.requestIgnoreBatteryOptimizations();
            },
            child: const Text('Настроить'),
          ),
        ],
      ),
    );
  }

  final List<Widget> _screens = const [TodoListsScreen(), TaskListScreen(), CalendarScreen(), NotesScreen()];

  final List<String> _titles = const ['To-Do Octopus', 'Мои Списки', 'Календарь', 'Заметки'];

  @override
  Widget build(BuildContext context) {
    // Реальное число просроченных задач вместо захардкоженного значения —
    // берём его прямо из провайдера, чтобы бейдж на колокольчике не врал.
    final overdueTasksCount = context.watch<TodoProvider>().getOverdueTasks().length;

    return Scaffold(
      appBar: CustomAppBar(title: _titles[_selectedIndex], overdueTasksCount: overdueTasksCount),
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: AppBottomBar(
        selectedIndex: _selectedIndex,
        onSelected: (index) => setState(() => _selectedIndex = index),
      ),
    );
  }
}
