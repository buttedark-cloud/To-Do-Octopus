import 'package:flutter/material.dart';
import '../../../core/models/note_model.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/image_provider_for.dart';

/// Карточка одной заметки в сетке. Тап открывает редактирование, иконка корзины в углу — удаление (с подтверждением снаружи).
class NoteCard extends StatelessWidget {
  final NoteModel note;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const NoteCard({
    super.key,
    required this.note,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: note.color,
      borderRadius: BorderRadius.circular(18),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.25),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      note.title.isEmpty ? 'Без названия' : note.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: onDelete,
                    child: const Padding(
                      padding: EdgeInsets.all(2.0),
                      child: Icon(
                        Icons.delete_outline,
                        size: 20,
                        color: Colors.black45,
                      ),
                    ),
                  ),
                ],
              ),
              if (note.imagePath != null) ...[
                const SizedBox(height: 8),
          
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 160),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image(
                      image: imageProviderFor(note.imagePath!),
                      width: double.infinity,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 70,
                        alignment: Alignment.center,
                        color: Colors.black12,
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.broken_image_outlined,
                              size: 20,
                              color: Colors.black45,
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Не удалось загрузить картинку',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.black54,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              if (note.content.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  note.content,
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              
              const SizedBox(height: 6),
              Text(
                formatDate(note.createdAt),
                style: const TextStyle(fontSize: 10, color: Colors.black45),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
