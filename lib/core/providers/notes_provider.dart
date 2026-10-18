import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:to_do/core/services/notification_service.dart';
import '../models/note_model.dart';
import '../services/cloud_image_storage.dart';

/// Хранит все заметки экрана "Заметки" — отдельно от задач и отсеков,
/// потому что это самостоятельная фича со своей моделью данных.
///
/// Заметки сохраняются в SharedPreferences после каждого изменения и
/// подгружаются обратно при старте (loadFromPrefs(), вызывается из main.dart).
/// Картинки заметок сначала лежат на телефоне, а затем загружаются в
/// Supabase Storage (см. uploadPendingImages) — и переживают переустановку.
class NotesProvider extends ChangeNotifier {
  static const _notesKey = 'notes_v1';

  List<NoteModel> _notes = [];

  // Новые заметки показываем сверху
  List<NoteModel> get notes => List.unmodifiable(_notes.reversed);

  Future<void> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_notesKey);
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw) as List<dynamic>;
        _notes = decoded
            .map((e) => NoteModel.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (e, st) {
        debugPrint('NotesProvider: ОШИБКА чтения заметок: $e');
        debugPrint('$st');
      }
    }
    notifyListeners();

    // Так же, как и для задач, переставляем напоминания по заметкам при
    // каждом старте приложения — уведомления могут не пережить
    // перезагрузку телефона.
    for (final note in _notes) {
      if (note.reminderAt != null && note.reminderAt!.isAfter(DateTime.now())) {
        NotificationService.instance.scheduleNoteNotification(
          noteId: note.id,
          noteTitle: note.title,
          remindAt: note.reminderAt!,
        );
      }
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _notesKey,
      jsonEncode(_notes.map((n) => n.toJson()).toList()),
    );
  }

  void addNote({
    required String title,
    required String content,
    required Color color,
    String? imagePath,
    DateTime? reminderAt,
  }) {
    final note = NoteModel(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: title,
      content: content,
      color: color,
      imagePath: imagePath,
      reminderAt: reminderAt,
      createdAt: DateTime.now(),
    );
    _notes.add(note);
    notifyListeners();
    _persist();
    unawaited(uploadPendingImages());

    if (reminderAt != null && reminderAt.isAfter(DateTime.now())) {
      NotificationService.instance.scheduleNoteNotification(
        noteId: note.id,
        noteTitle: title,
        remindAt: reminderAt,
      );
    }
  }

  void updateNote(
    String id, {
    String? title,
    String? content,
    Color? color,
    String? imagePath,
    bool clearImage = false,
    DateTime? reminderAt,
    bool clearReminder = false,
  }) {
    final index = _notes.indexWhere((n) => n.id == id);
    if (index == -1) return;

    final note = _notes[index];
    final oldImagePath = note.imagePath;
    if (title != null) note.title = title;
    if (content != null) note.content = content;
    if (color != null) note.color = color;
    if (clearImage) {
      note.imagePath = null;
    } else if (imagePath != null) {
      note.imagePath = imagePath;
    }
    if (clearReminder) {
      note.reminderAt = null;
    } else if (reminderAt != null) {
      note.reminderAt = reminderAt;
    }
    notifyListeners();
    _persist();

    // Картинку заменили/убрали — старую удаляем из облака; новую
    // (если она ещё локальная) отправляем туда.
    if (oldImagePath != note.imagePath) {
      unawaited(CloudImageStorage.instance.deleteByUrl(oldImagePath));
    }
    unawaited(uploadPendingImages());

    if (clearReminder) {
      NotificationService.instance.cancelNoteNotification(id);
    } else if (note.reminderAt != null &&
        note.reminderAt!.isAfter(DateTime.now())) {
      NotificationService.instance.scheduleNoteNotification(
        noteId: id,
        noteTitle: note.title,
        remindAt: note.reminderAt!,
      );
    }
  }

  void deleteNote(String id) {
    final index = _notes.indexWhere((n) => n.id == id);
    final imagePath = index == -1 ? null : _notes[index].imagePath;
    _notes.removeWhere((n) => n.id == id);
    notifyListeners();
    _persist();
    NotificationService.instance.cancelNoteNotification(id);
    unawaited(CloudImageStorage.instance.deleteByUrl(imagePath));
  }

  // ---------- ЗАГРУЗКА КАРТИНОК В ОБЛАКО ----------

  bool _uploadingImages = false;

  /// Отправляет в Supabase Storage все картинки заметок, которые пока лежат
  /// только на телефоне (путь не начинается с http), и подменяет путь на
  /// постоянную ссылку. Если нет сети/входа — просто повторится позже
  /// (при следующем сохранении заметки или входе в приложение).
  Future<void> uploadPendingImages() async {
    if (_uploadingImages) return;
    _uploadingImages = true;
    try {
      for (final note in List<NoteModel>.of(_notes)) {
        final path = note.imagePath;
        if (path == null || path.startsWith('http')) continue;

        final url = await CloudImageStorage.instance.uploadNoteImage(path);
        if (url == null) continue;

        // Пока грузили, заметку могли удалить или поменять картинку.
        final index = _notes.indexWhere((n) => n.id == note.id);
        if (index == -1 || _notes[index].imagePath != path) {
          await CloudImageStorage.instance.deleteByUrl(url);
          continue;
        }
        _notes[index].imagePath = url;
        notifyListeners();
        _persist();
      }
    } finally {
      _uploadingImages = false;
    }
  }

  // ---------- ВЫХОД ИЗ АККАУНТА ----------

  // ИСПРАВЛЕНИЕ КРИТИЧЕСКОГО БАГА: раньше заметки одного аккаунта
  // оставались видны следующему, кто войдёт на этом же телефоне.
  Future<void> resetToDefaults() async {
    for (final note in _notes) {
      NotificationService.instance.cancelNoteNotification(note.id);
    }
    _notes = [];
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_notesKey);
  }

  // ---------- ОБЛАЧНАЯ СИНХРОНИЗАЦИЯ (см. SyncManager) ----------

  Map<String, dynamic> exportForSync() => {
    'notes': _notes.map((n) => n.toJson()).toList(),
  };

  /// imagePath заметки — либо https-ссылка на картинку в облаке (будет
  /// видна на любом телефоне), либо локальный путь, если картинка ещё не
  /// успела загрузиться (на другом телефоне такой путь не откроется).
  void importFromSync(Map<String, dynamic> data) {
    final rawNotes = data['notes'];
    if (rawNotes is List) {
      _notes = rawNotes
          .whereType<Map>()
          .map((e) => NoteModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      notifyListeners();
      _persist();
      for (final note in _notes) {
        if (note.reminderAt != null &&
            note.reminderAt!.isAfter(DateTime.now())) {
          NotificationService.instance.scheduleNoteNotification(
            noteId: note.id,
            noteTitle: note.title,
            remindAt: note.reminderAt!,
          );
        }
      }
    }
  }
}
