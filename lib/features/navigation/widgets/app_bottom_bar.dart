import 'package:flutter/material.dart';

/// Высота нижней панели (без системной полосы жестов). Хочешь ниже/выше —
/// меняй только это число.
const double kBottomBarHeight = 64;

/// Простая нижняя панель, собранная с нуля: фиксированная высота, иконка в
/// "таблетке" и подпись под ней. Масштаб шрифта внутри зафиксирован, поэтому
/// при увеличении шрифта в настройках телефона панель не меняется.
class AppBottomBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const AppBottomBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  static const List<_BarItem> _items = [
    _BarItem(Icons.home_outlined, Icons.home, 'Главная'),
    _BarItem(Icons.list_alt_outlined, Icons.list_alt, 'Списки'),
    _BarItem(
      Icons.calendar_month_outlined,
      Icons.calendar_month,
      'Календарь',
    ),
    _BarItem(Icons.note_alt_outlined, Icons.note_alt, 'Заметки'),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: Material(
        color: scheme.surfaceContainer,
        elevation: 3,
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: kBottomBarHeight,
            child: Row(
              children: [
                for (var i = 0; i < _items.length; i++)
                  Expanded(
                    child: _BarButton(
                      item: _items[i],
                      selected: i == selectedIndex,
                      onTap: () => onSelected(i),
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

class _BarItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  const _BarItem(this.icon, this.selectedIcon, this.label);
}

class _BarButton extends StatelessWidget {
  final _BarItem item;
  final bool selected;
  final VoidCallback onTap;

  const _BarButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 56,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? scheme.secondaryContainer : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              selected ? item.selectedIcon : item.icon,
              size: 22,
              color: selected
                  ? scheme.onSecondaryContainer
                  : scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
