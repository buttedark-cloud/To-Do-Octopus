import 'package:flutter/material.dart';

/// Кнопка входа через соцсеть — белая "таблетка" с иконкой и текстом.
class SocialButton extends StatelessWidget {
  final Widget icon;
  final String label;
  final VoidCallback? onPressed;

  const SocialButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    // ИСПРАВЛЕНИЕ БАГА (полосатое переполнение при сильно увеличенном
    // системном масштабе шрифта): раньше была жёсткая height: 50 —
    // текст "Продолжить с Google" при большом масштабе физически не
    // помещался в эту высоту и вылезал за рамки кнопки. Теперь высота
    // не фиксированная (минимум 50, дальше растёт по необходимости), а
    // текст может переноситься на вторую строку вместо переполнения.
    return SizedBox(
      width: double.infinity,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 50),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  icon,
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Простая цветная "G" вместо официального лого Google (чтобы не тащить
/// картинку-ассет только ради одной иконки). При желании эту иконку легко
/// заменить на официальный PNG/SVG из брендбука Google — см. README.
class GoogleGIcon extends StatelessWidget {
  const GoogleGIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black12),
      ),
      child: const Text(
        'G',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Color(0xFF4285F4),
        ),
      ),
    );
  }
}
