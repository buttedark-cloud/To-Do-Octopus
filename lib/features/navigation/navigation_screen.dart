import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/todo_provider.dart';
import 'widgets/custom_navigation_widget.dart';
import '../todo_lists/screens/todo_lists_screen.dart';
import '../task_list/screens/task_list_screen.dart';
import '../calendar/screens/calendar_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    TodoListsScreen(),
    TaskListScreen(),
    CalendarScreen(),
    Center(child: Text('Заметки')),
  ];

  final List<String> _titles = const [
    'To-Do Octopus',
    'Мои Списки',
    'Календарь',
    'Заметки',
  ];

  @override
  Widget build(BuildContext context) {
    // Реальное число просроченных задач вместо захардкоженного значения —
    // берём его прямо из провайдера, чтобы бейдж на колокольчике не врал.
    final overdueTasksCount = context
        .watch<TodoProvider>()
        .getOverdueTasks()
        .length;

    return Scaffold(
      appBar: CustomAppBar(
        title: _titles[_selectedIndex],
        overdueTasksCount: overdueTasksCount,
      ),
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Главная',
          ),
          NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            selectedIcon: Icon(Icons.list_alt),
            label: 'Списки',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Календарь',
          ),
          NavigationDestination(
            icon: Icon(Icons.note_alt_outlined),
            selectedIcon: Icon(Icons.note_alt),
            label: 'Заметки',
          ),
        ],
      ),
    );
  }
}
