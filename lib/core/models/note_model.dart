import 'package:flutter/material.dart';

/// Модель заметки для экрана "Заметки".
class NoteModel {
  final String id;
  String title;
  String content;
  Color color;
  String? imagePath; // локальный путь к прикреплённой картинке
  DateTime? reminderAt;
  final DateTime createdAt;

  NoteModel({
    required this.id,
    required this.title,
    required this.content,
    required this.color,
    this.imagePath,
    this.reminderAt,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'content': content,
    'color': color.toARGB32(),
    'imagePath': imagePath,
    'reminderAt': reminderAt?.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
  };

  factory NoteModel.fromJson(Map<String, dynamic> json) => NoteModel(
    id: json['id'] as String,
    title: json['title'] as String,
    content: json['content'] as String,
    color: Color(json['color'] as int),
    imagePath: json['imagePath'] as String?,
    reminderAt: json['reminderAt'] != null
        ? DateTime.tryParse(json['reminderAt'] as String)
        : null,
    createdAt: DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now(),
  );
}
