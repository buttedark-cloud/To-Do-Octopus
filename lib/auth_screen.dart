import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:to_do/auth_provider.dart';
import 'package:to_do/primary_gradient_button.dart';
import 'package:to_do/social_button.dart';
import 'package:to_do/styled_text_field.dart';
import 'package:to_do/core/providers/user_profile_provider.dart';

const Color kAuthYellow = Color(0xFFFFD34E);
const Color kAuthAmber = Color(0xFFFF9800);
const Color kAuthCream = Color(0xFFFFF8E1);
const Color kAuthDarkText = Color(0xFF3A2B00);

const String _kAuthLogoAsset = 'assets/logo_octopus.png';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLoginMode = false;
  String? _errorMessage;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Имя из Google — в приоритете; если его нет, используется то, что
  // человек ввёл в поле "Имя" сам.
  Future<void> _applyProfileFromResult(AuthResult result) async {
    final profile = context.read<UserProfileProvider>();
    final fallbackName = _nameController.text.trim();
    final name = (result.displayName?.trim().isNotEmpty ?? false)
        ? result.displayName!.trim()
        : fallbackName;
    if (name.isNotEmpty) {
      await profile.updateName(name);
    }

    if (result.photoUrl != null) {
      await profile.updatePhoto(result.photoUrl);
    }
  }

  Future<void> _handleResult(AuthResult result) async {
    if (!mounted) return;
    if (result.success) {
      setState(() => _errorMessage = null);

      if (result.isNewUser) {
        await _applyProfileFromResult(result);
      }
      // Дальше ничего вручную открывать не нужно — AuthGate сам покажет
      // главный экран, как только Firebase подтвердит вход.
    } else if (!result.cancelled) {
      setState(
        () => _errorMessage = result.errorMessage ?? 'Что-то пошло не так',
      );
    }
  }

  Future<void> _submit() async {
    final auth = context.read<AuthProvider>();
    setState(() => _errorMessage = null);
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty ||
        password.isEmpty ||
        (!_isLoginMode && _nameController.text.trim().isEmpty)) {
      setState(() => _errorMessage = 'Заполните все поля');
      return;
    }
    final result = _isLoginMode
        ? await auth.signInWithEmail(email: email, password: password)
        : await auth.registerWithEmail(
            email: email,
            password: password,
            name: _nameController.text.trim(),
          );
    await _handleResult(result);
  }

  Future<void> _showForgotPasswordDialog() async {
    final resetEmailController = TextEditingController(
      text: _emailController.text.trim(),
    );
    String? dialogError;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('Восстановление пароля'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Введите email, указанный при регистрации — пришлём '
                    'ссылку для смены пароля.',
                    style: TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: resetEmailController,
                    autofocus: true,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (dialogError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      dialogError!,
                      style: const TextStyle(
                        color: Color(0xFFD32F2F),
                        fontSize: 13,
                      ),
                    ),
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
                    final result = await context
                        .read<AuthProvider>()
                        .sendPasswordResetEmail(
                          email: resetEmailController.text,
                        );
                    if (!dialogContext.mounted) return;
                    if (result.success) {
                      Navigator.pop(dialogContext);
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Если такой аккаунт существует — письмо со '
                            'ссылкой для смены пароля уже отправлено',
                          ),
                          duration: Duration(seconds: 5),
                        ),
                      );
                    } else {
                      setDialogState(
                        () => dialogError =
                            result.errorMessage ??
                            'Не удалось отправить письмо',
                      );
                    }
                  },
                  child: const Text('Отправить'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _submitGoogle() async {
    setState(() => _errorMessage = null);
    final result = await context.read<AuthProvider>().signInWithGoogle();
    await _handleResult(result);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [kAuthCream, kAuthYellow],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 24,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 48,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      //  ЛОГОТИП
                      Image.asset(
                        _kAuthLogoAsset,
                        width: 150,
                        height: 150,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(
                              Icons.checklist_rtl,
                              color: kAuthAmber,
                              size: 36,
                            ),
                      ),
                      const SizedBox(height: 25),

                      Text(
                        _isLoginMode ? 'С возвращением' : 'Создать аккаунт',
                        style: const TextStyle(
                          color: kAuthDarkText,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isLoginMode
                            ? 'Войдите в свой аккаунт'
                            : 'Заполните форму или выберите Google',
                        style: TextStyle(
                          color: kAuthDarkText.withValues(alpha: 0.6),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 28),

                      // --- ПОЛЯ ФОРМЫ (только email) ---
                      if (!_isLoginMode)
                        StyledTextField(
                          controller: _nameController,
                          hint: 'Имя',
                          icon: Icons.person_outline,
                        ),
                      StyledTextField(
                        controller: _emailController,
                        hint: 'Email',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      StyledTextField(
                        controller: _passwordController,
                        hint: 'Пароль',
                        icon: Icons.lock_outline,
                        obscureText: true,
                      ),

                      // "Забыли пароль?" имеет смысл только при входе — при
                      // регистрации пароля ещё не существует, нечего сбрасывать.
                      if (_isLoginMode)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _showForgotPasswordDialog,
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              'Забыли пароль?',
                              style: TextStyle(
                                color: kAuthDarkText.withValues(alpha: 0.6),
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 4),

                      if (_errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: Color(0xFFD32F2F),
                              fontSize: 13,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),

                      PrimaryGradientButton(
                        label: _isLoginMode ? 'Войти' : 'Зарегистрироваться',
                        onPressed: _submit,
                        isLoading: auth.isLoading,
                      ),
                      const SizedBox(height: 24),

                      Row(
                        children: [
                          Expanded(
                            child: Divider(
                              color: kAuthDarkText.withValues(alpha: 0.15),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'или',
                              style: TextStyle(
                                color: kAuthDarkText.withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Divider(
                              color: kAuthDarkText.withValues(alpha: 0.15),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      SocialButton(
                        icon: const GoogleGIcon(),
                        label: 'Продолжить с Google',
                        onPressed: _submitGoogle,
                      ),
                      const SizedBox(height: 24),

                      TextButton(
                        onPressed: () {
                          setState(() {
                            _isLoginMode = !_isLoginMode;
                            _errorMessage = null;
                          });
                        },
                        child: Text(
                          _isLoginMode
                              ? 'Нет аккаунта? Зарегистрироваться'
                              : 'Уже есть аккаунт? Войти',
                          style: const TextStyle(
                            color: kAuthDarkText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      SizedBox(height: 50),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
