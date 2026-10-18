import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/todo_provider.dart';
import '../../../core/providers/user_profile_provider.dart';
import '../../profile/screens/profile_screen.dart';
import 'overdue_tasks_bottom_sheet.dart';
import 'package:google_fonts/google_fonts.dart';

/// Высота верхней панели — одно число на всё (раньше preferredSize был 70,
/// а toolbarHeight 90 — они спорили друг с другом).
const double kTopBarHeight = 70.0;

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
  Size get preferredSize => const Size.fromHeight(kTopBarHeight);
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

  ImageProvider? _avatarImage(String? photoPath) {
    if (photoPath == null || photoPath.isEmpty) return null;
    if (photoPath.startsWith('http')) {
      return NetworkImage(photoPath);
    }
    final file = File(photoPath);
    if (file.existsSync()) {
      return FileImage(file);
    }
    return null;
  }

  Widget _graffitiTitle(
    BuildContext context,
    String title, {
    required double fontSize,
    required Color fillColor,
    required Color outlineColor,
    required double strokeWidth,
  }) {
    return Stack(
      children: [
        // 1. Контур букв (задний слой)
        Text(
          title,
          style: GoogleFonts.chewy(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            fontStyle: FontStyle.italic,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = strokeWidth
              ..color = outlineColor,
          ),
        ),
        // 2. Заливка букв (передний слой)
        Text(
          title,
          style: GoogleFonts.chewy(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            fontStyle: FontStyle.italic,
            color: fillColor,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Проверяем, какая тема сейчас активна на телефоне
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final photoPath = context.watch<UserProfileProvider>().photoPath;
    final avatarImage = _avatarImage(photoPath);

    // Масштаб шрифта внутри верхней панели зафиксирован на 1.0 — при
    // увеличении шрифта в настройках телефона панель не меняется.
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: AppBar(
      // Если тема темная — берем цвет из файла темы, если светлая — оставляем ваш желтый
      backgroundColor: isDark
          ? Theme.of(context).appBarTheme.backgroundColor
          : const Color.fromARGB(255, 255, 218, 34).withValues(alpha: 0.7),
      elevation: 1,
      leading: Padding(
        padding: const EdgeInsets.only(left: 15.0),
        child: Image.asset(
          isDark ? 'assets/to_do_logo4.png' : 'assets/logo_octopus.png',
          width: 50,
          height: 50,
          fit: BoxFit.contain,
          filterQuality:
              FilterQuality.high, // Картинка заполнит область, лишнее обрежется

          errorBuilder: (context, error, stackTrace) =>
              const Icon(Icons.playlist_add_check, size: 30),
        ),
      ),
      leadingWidth: 80,
      toolbarHeight: kTopBarHeight,
      title: widget.title == 'To-Do Octopus'
          ? _graffitiTitle(
              context,
              widget.title,
              fontSize: 28,
              strokeWidth: 4.5,

              outlineColor: isDark
                  ? const Color(0xFF140D06)
                  : const Color(0xFF2B1A08),

              fillColor: isDark
                  ? const Color.fromARGB(255, 181, 77, 255)
                  : const Color(0xFFFF9800),
            )
          : _graffitiTitle(
              context,
              widget.title,
              fontSize: 22,
              strokeWidth: 3.5,

              fillColor: isDark ? Colors.white : Colors.black87,

              outlineColor: isDark ? const Color(0xFF140D06) : Colors.white,
            ),
      centerTitle: true,
      actions: [
        // Колокольчик
        Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_none, size: 28),
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

        // Аватарка с эффектом сжатия — теперь с реальным фото профиля
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
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color.fromARGB(255, 244, 244, 240),
                  backgroundImage: avatarImage,
                  child: avatarImage == null
                      ? const Icon(Icons.person, color: Colors.black, size: 22)
                      : null,
                ),
              ),
            ),
          ),
        ),
      ],
    ),
    );
  }
}
