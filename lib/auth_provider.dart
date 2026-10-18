import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:to_do/core/services/cloud_image_storage.dart';
import 'package:to_do/core/services/cloud_sync_service.dart';

class AuthResult {
  final bool success;
  final bool cancelled;
  final String? displayName;
  final String? photoUrl;
  final String? errorMessage;

  final bool isNewUser;

  AuthResult({
    required this.success,
    this.cancelled = false,
    this.displayName,
    this.photoUrl,
    this.errorMessage,
    this.isNewUser = false,
  });
}

/// Обёртка над Firebase Authentication: email/пароль и Google.
/// Все методы возвращают AuthResult — экран сам решает, что показать пользователю.
class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  bool _isLoading = false;

  bool get isLoading => _isLoading;
  User? get currentUser => _auth.currentUser;
  bool get isSignedIn => _auth.currentUser != null;

  /// Есть ли у аккаунта вход по email+паролю (у чистого Google-аккаунта
  /// пароля нет — менять и подтверждать нечем).
  bool get hasPasswordLogin =>
      _auth.currentUser?.providerData.any((p) => p.providerId == 'password') ??
      false;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  // EMAIL

  Future<AuthResult> registerWithEmail({
    required String email,
    required String password,
    required String name,
  }) async {
    _setLoading(true);
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await credential.user?.updateDisplayName(name);
      // Обновляем локальный кэш пользователя, чтобы currentUser.displayName
      // сразу отражал новое имя (иначе он подтянется только после reload()).
      await credential.user?.reload();
      _setLoading(false);
      return AuthResult(success: true, displayName: name, isNewUser: true);
    } on FirebaseAuthException catch (e) {
      _setLoading(false);
      return AuthResult(success: false, errorMessage: _mapError(e.code));
    }
  }

  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      _setLoading(false);
      return AuthResult(
        success: true,
        displayName: credential.user?.displayName,
      );
    } on FirebaseAuthException catch (e) {
      _setLoading(false);
      return AuthResult(success: false, errorMessage: _mapError(e.code));
    }
  }

  // GOOGLE

  Future<AuthResult> signInWithGoogle() async {
    _setLoading(true);
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        _setLoading(false);
        return AuthResult(
          success: false,
          cancelled: true,
        ); // пользователь закрыл окно выбора
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final userCredential = await _auth.signInWithCredential(credential);
      _setLoading(false);
      return AuthResult(
        success: true,
        displayName: userCredential.user?.displayName ?? googleUser.displayName,
        photoUrl: userCredential.user?.photoURL ?? googleUser.photoUrl,

        isNewUser: userCredential.additionalUserInfo?.isNewUser ?? false,
      );
    } on FirebaseAuthException catch (e) {
      _setLoading(false);
      return AuthResult(success: false, errorMessage: _mapError(e.code));
    } catch (_) {
      _setLoading(false);
      return AuthResult(
        success: false,
        errorMessage: 'Не удалось войти через Google',
      );
    }
  }

  //  ВОССТАНОВЛЕНИЕ ПАРОЛЯ

  Future<AuthResult> sendPasswordResetEmail({required String email}) async {
    final trimmedEmail = email.trim();
    if (trimmedEmail.isEmpty) {
      return AuthResult(success: false, errorMessage: 'Введите email');
    }
    _setLoading(true);
    try {
      await _auth.sendPasswordResetEmail(email: trimmedEmail);
      _setLoading(false);
      return AuthResult(success: true);
    } on FirebaseAuthException catch (e) {
      _setLoading(false);
      if (e.code == 'user-not-found') {
        return AuthResult(success: true);
      }
      if (e.code == 'invalid-email') {
        return AuthResult(success: false, errorMessage: 'Некорректный email');
      }
      return AuthResult(success: false, errorMessage: _mapError(e.code));
    } catch (_) {
      _setLoading(false);
      return AuthResult(
        success: false,
        errorMessage: 'Не удалось отправить письмо. Попробуйте позже',
      );
    }
  }

  // СМЕНА ПАРОЛЯ

  /// Firebase требует "свежий" вход для смены пароля — поэтому сначала повторно подтверждаем личность текущим паролем (reauthenticate),и только потом меняем на новый.
  Future<AuthResult> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      return AuthResult(
        success: false,
        errorMessage: 'Сначала нужно войти в аккаунт',
      );
    }
    _setLoading(true);
    try {
      final credential = EmailAuthProvider.credential(
        email: email,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
      _setLoading(false);
      return AuthResult(success: true);
    } on FirebaseAuthException catch (e) {
      _setLoading(false);
      return AuthResult(success: false, errorMessage: _mapError(e.code));
    }
  }

  //  ВЫХОД

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    await _auth.signOut();
    notifyListeners();
  }

  // УДАЛЕНИЕ АККАУНТА (требование Google Play)

  /// Firebase разрешает удалять аккаунт только после "свежего" входа,
  /// поэтому сначала повторно подтверждаем личность (паролем или Google),
  /// затем стираем картинки, данные в облаке и сам аккаунт.
  Future<AuthResult> deleteAccount({String? password}) async {
    final user = _auth.currentUser;
    if (user == null) {
      return AuthResult(
        success: false,
        errorMessage: 'Сначала нужно войти в аккаунт',
      );
    }
    _setLoading(true);
    try {
      if (hasPasswordLogin) {
        final email = user.email;
        if (email == null || password == null || password.isEmpty) {
          _setLoading(false);
          return AuthResult(
            success: false,
            errorMessage: 'Введите пароль для подтверждения',
          );
        }
        await user.reauthenticateWithCredential(
          EmailAuthProvider.credential(email: email, password: password),
        );
      } else {
        final googleUser = await _googleSignIn.signIn();
        if (googleUser == null) {
          _setLoading(false);
          return AuthResult(success: false, cancelled: true);
        }
        final googleAuth = await googleUser.authentication;
        await user.reauthenticateWithCredential(
          GoogleAuthProvider.credential(
            accessToken: googleAuth.accessToken,
            idToken: googleAuth.idToken,
          ),
        );
      }

      try {
        await CloudImageStorage.instance.deleteAllMine();
      } catch (_) {
        // Картинки не критичны — аккаунт всё равно удаляем.
      }
      await CloudSyncService.instance.deleteUserData(user.uid);
      await user.delete();
      _setLoading(false);
      return AuthResult(success: true);
    } on FirebaseAuthException catch (e) {
      _setLoading(false);
      return AuthResult(success: false, errorMessage: _mapError(e.code));
    } catch (_) {
      _setLoading(false);
      return AuthResult(
        success: false,
        errorMessage:
            'Не удалось удалить аккаунт. Проверьте интернет и попробуйте ещё раз',
      );
    }
  }

  String _mapError(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'Этот email уже зарегистрирован';
      case 'invalid-email':
        return 'Некорректный email';
      case 'weak-password':
        return 'Пароль слишком простой (минимум 6 символов)';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Неверный email или пароль';
      case 'too-many-requests':
        return 'Слишком много попыток, попробуйте позже';
      case 'requires-recent-login':
        return 'Пожалуйста, войдите заново и повторите попытку';
      default:
        return 'Что-то пошло не так. Попробуйте ещё раз';
    }
  }
}
