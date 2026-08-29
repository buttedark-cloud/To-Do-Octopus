import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/todo_provider.dart';
import '../../profile/screens/profile_screen.dart';
import 'overdue_tasks_bottom_sheet.dart';

class CustomAppBar extends StatefulWidget implements PreferredSizeWidget {
  final String title;
  final int overdueTasksCount;

  const CustomAppBar({
    super.key,
    required this.title,
    required this.overdueTasksCount,
  });

  @override
  State<CustomAppBar> createState() => _CustomAppBarState();

  @override
  Size get preferredSize => const Size.fromHeight(80.0); // Задаем высоту 90
} // Вот эта фигурная скобка закрывает класс

class _CustomAppBarState extends State<CustomAppBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.88).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Берём актуальный список просроченных задач из провайдера и передаем в шторку
  void _openNotifications(BuildContext context) {
    final overdueTasks = context.read<TodoProvider>().getOverdueTasks();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => OverdueTasksBottomSheet(overdueTasks: overdueTasks),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: const Color.fromARGB(
        255,
        255,
        218,
        34,
      ).withValues(alpha: 0.6),
      elevation: 2,
      leading: Padding(
        padding: const EdgeInsets.only(left: 8.0),
        child: Image.asset(
          'assets/logo_octopus.png',
          width: 100,
          height: 80,
          fit: BoxFit.contain,
          filterQuality:
              FilterQuality.high, // Картинка заполнит область, лишнее обрежется

          errorBuilder: (context, error, stackTrace) =>
              const Icon(Icons.playlist_add_check, size: 30),
        ),
      ),
      leadingWidth: 80,
      toolbarHeight: 90.0,
      title: Text(
        widget.title,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w500,
          color: Colors.black87,
        ),
      ),
      centerTitle: true,
      actions: [
        // Колокольчик
        Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(
                Icons.notifications_none,
                size: 28,
                color: Colors.black87,
              ),
              onPressed: () => _openNotifications(context),
            ),
            if (widget.overdueTasksCount > 0)
              Positioned(
                right: 8,
                top: 8,
                child: GestureDetector(
                  onTap: () => _openNotifications(context),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '${widget.overdueTasksCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 4),

        // Аватарка с эффектом сжатия
        Padding(
          padding: const EdgeInsets.only(right: 12.0),
          child: GestureDetector(
            onTapDown: (_) => _animationController.forward(),
            onTapUp: (_) {
              _animationController.reverse();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
            onTapCancel: () => _animationController.reverse(),
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black87, width: 1.5),
                ),
                child: const CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.pinkAccent,
                  child: Icon(Icons.person, color: Colors.black, size: 22),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
