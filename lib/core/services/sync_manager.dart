import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/todo_provider.dart';
import '../providers/notes_provider.dart';
import '../providers/user_profile_provider.dart';
import '../providers/settings_provider.dart';
import 'cloud_sync_service.dart';

/// Связывает локальные провайдеры с облаком (Firestore).
///
/// Firestore на телефоне хранит собственный кэш, и офлайн .get() отдаёт
/// СТАРЫЕ данные вместо ошибки. Поэтому метка "когда обновлялись данные на
/// этом телефоне" сохраняется на диск, и облако применяется, только если
/// оно ДЕЙСТВИТЕЛЬНО новее.
class SyncManager {
  SyncManager({
    required this.todoProvider,
    required this.notesProvider,
    required this.userProfileProvider,
    required this.settingsProvider,
  }) {
    _loadLocalTimestamp();
    todoProvider.addListener(_scheduleLocalPush);
    notesProvider.addListener(_scheduleLocalPush);
    userProfileProvider.addListener(_scheduleLocalPush);
    settingsProvider.addListener(_scheduleLocalPush);

    // Имя и фото профиля отправляются в облако СРАЗУ, без 2-секундной
    // задержки (см. UserProfileProvider.onCriticalChange).
    userProfileProvider.onCriticalChange = () async {
      if (!_isApplyingRemote) {
        await _pushNow();
      }
    };

    FirebaseAuth.instance.authStateChanges().listen(_onAuthChanged);
  }

  static const _localUpdatedAtKey = 'sync_local_updated_at';

  final TodoProvider todoProvider;
  final NotesProvider notesProvider;
  final UserProfileProvider userProfileProvider;
  final SettingsProvider settingsProvider;

  StreamSubscription<Map<String, dynamic>?>? _remoteSub;
  Timer? _pushDebounce;
  bool _isApplyingRemote = false;
  String? _uid;
  DateTime? _lastKnownUpdatedAt;

  // Вызывается из ProfileScreen ПЕРЕД выходом: чужая временная метка не
  // должна достаться следующему человеку на этом же телефоне.
  Future<void> resetLocalTimestamp() async {
    await _remoteSub?.cancel();
    _remoteSub = null;
    _pushDebounce?.cancel();
    _uid = null;
    _lastKnownUpdatedAt = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_localUpdatedAtKey);
  }

  Future<void> _loadLocalTimestamp() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_localUpdatedAtKey);
    if (raw != null) {
      _lastKnownUpdatedAt = DateTime.tryParse(raw);
    }
  }

  Future<void> _saveLocalTimestamp(DateTime time) async {
    _lastKnownUpdatedAt = time;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localUpdatedAtKey, time.toIso8601String());
  }

  Future<void> _onAuthChanged(User? user) async {
    await _remoteSub?.cancel();
    _remoteSub = null;

    if (user == null) {
      _uid = null;
      return;
    }
    _uid = user.uid;

    if (_lastKnownUpdatedAt == null) {
      await _loadLocalTimestamp();
    }

    Map<String, dynamic>? remote;
    try {
      remote = await CloudSyncService.instance.fetchOnce(user.uid);
    } catch (_) {
      remote = null;
    }

    if (remote != null) {
      final remoteUpdatedAt = _timestampOf(remote['updatedAt']);
      if (remoteUpdatedAt != null &&
          (_lastKnownUpdatedAt == null ||
              remoteUpdatedAt.isAfter(_lastKnownUpdatedAt!))) {
        // Облако реально новее того, что мы знаем локально — применяем.
        _applyRemote(remote);
      } else if (_lastKnownUpdatedAt != null) {
        // Локальные данные не старше облачных (или облако — устаревший
        // офлайн-кэш) — досылаем локальное состояние в облако.
        await _pushNow();
      }
    } else {
      await _pushNow();
    }

    _remoteSub = CloudSyncService.instance.watch(user.uid).listen((remote) {
      if (remote == null) return;
      final remoteUpdatedAt = _timestampOf(remote['updatedAt']);
      if (remoteUpdatedAt == null) return;
      if (_lastKnownUpdatedAt != null &&
          !remoteUpdatedAt.isAfter(_lastKnownUpdatedAt!)) {
        return;
      }
      _applyRemote(remote);
    });

    // Картинки заметок, которые не успели уйти в облако (Supabase) раньше.
    unawaited(notesProvider.uploadPendingImages());
  }

  DateTime? _timestampOf(dynamic value) {
    if (value is Timestamp) return value.toDate();
    return null;
  }

  void _applyRemote(Map<String, dynamic> remote) {
    _isApplyingRemote = true;
    try {
      todoProvider.importFromSync(remote);
      notesProvider.importFromSync(remote);
      userProfileProvider.importFromSync(remote);
      settingsProvider.importFromSync(remote);
      final ts = _timestampOf(remote['updatedAt']) ?? DateTime.now();
      _saveLocalTimestamp(ts);
    } finally {
      _isApplyingRemote = false;
    }
  }

  void _scheduleLocalPush() {
    if (_isApplyingRemote || _uid == null) return;
    _pushDebounce?.cancel();
    _pushDebounce = Timer(const Duration(seconds: 2), _pushNow);
  }

  Future<void> _pushNow() async {
    final uid = _uid;
    if (uid == null) return;
    final data = <String, dynamic>{
      ...todoProvider.exportForSync(),
      ...notesProvider.exportForSync(),
      ...userProfileProvider.exportForSync(),
      ...settingsProvider.exportForSync(),
    };
    try {
      await CloudSyncService.instance.push(uid, data);
      await _saveLocalTimestamp(DateTime.now());
    } catch (_) {
      // Нет сети — не страшно, но фиксируем "локальные данные свежее".
      await _saveLocalTimestamp(DateTime.now());
    }
  }
}
