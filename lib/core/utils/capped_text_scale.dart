import 'package:flutter/material.dart';

/// Ограничивает системный масштаб шрифта ВНУТРИ конкретного диалога — не
/// трогая масштаб во всём остальном приложении.
///
/// Зачем: встроенные Flutter-пикеры даты и времени (showDatePicker,
/// showTimePicker) физически не рассчитаны на экстремально увеличенный
/// системный масштаб шрифта (Настройки -> Экран -> Размер шрифта на
/// максимум) — числа в календарной сетке начинают накладываться друг на
/// друга и обрезаться до одной цифры (например, "12" превращается в
/// "1"). Это ограничение самих системных виджетов Flutter, а не нашего
/// кода — полностью убрать его нельзя, но можно аккуратно "придержать"
/// масштаб именно в этом диалоге, чтобы цифры оставались читаемыми.
///
/// Использование — передать как builder в showDatePicker/showTimePicker:
///   builder: (context, child) => capTextScale(context, child),
Widget capTextScale(
  BuildContext context,
  Widget? child, {
  double maxScale = 1.3,
}) {
  final currentScale = MediaQuery.textScalerOf(context).scale(1.0);
  final cappedScale = currentScale > maxScale ? maxScale : currentScale;
  return MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(cappedScale)),
    child: child!,
  );
}
