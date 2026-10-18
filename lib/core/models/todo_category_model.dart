import 'package:flutter/material.dart';

/// Модель карточки-отсека ("стикера") на Главной.
class TodoCategoryModel {
  final String id;
  String title;
  Color color;

  // Отмечает отсек как "Сделано" — задачи автоматически улетают сюда, когда по ним ставится галочка. Флаг, а не название, чтобы отсек продолжал работать даже если его переименуют.
  bool isDoneCategory;

  TodoCategoryModel({
    required this.id,
    required this.title,
    required this.color,
    this.isDoneCategory = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'color': color.toARGB32(),
    'isDoneCategory': isDoneCategory,
  };

  factory TodoCategoryModel.fromJson(Map<String, dynamic> json) =>
      TodoCategoryModel(
        id: json['id'] as String,
        title: json['title'] as String,
        color: Color(json['color'] as int),
        isDoneCategory: json['isDoneCategory'] as bool? ?? false,
      );
}
