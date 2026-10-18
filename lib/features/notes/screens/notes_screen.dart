import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/notes_provider.dart';
import '../../../core/models/note_model.dart';
import '../widgets/note_card.dart';
import '../widgets/note_editor_dialog.dart';

/// Экран "Заметки". Заметки выложены в две колонки в стиле мозаики
class NotesScreen extends StatelessWidget {
  const NotesScreen({super.key});

  Future<void> _confirmDelete(BuildContext context, NoteModel note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить заметку?'),
        content: Text(
          '«${note.title.isEmpty ? 'Без названия' : note.title}» будет удалена безвозвратно.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.read<NotesProvider>().deleteNote(note.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notes = context.watch<NotesProvider>().notes;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.small(
        heroTag: 'fab_button_one',
        onPressed: () => showNoteEditor(context),
        backgroundColor: const Color(0xFF8BC34A),
        child: const Icon(Icons.add, color: Colors.white, size: 30),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: notes.isEmpty
          ? _EmptyNotesState(onCreate: () => showNoteEditor(context))
          : Padding(
              padding: EdgeInsets.fromLTRB(
                12,
                12,
                12,
                
                5 + MediaQuery.of(context).padding.bottom,
              ),
              child: _NotesMasonryGrid(notes: notes, onDelete: _confirmDelete),
            ),
    );
  }
}


class _NotesMasonryGrid extends StatelessWidget {
  final List<NoteModel> notes;
  final Future<void> Function(BuildContext, NoteModel) onDelete;

  const _NotesMasonryGrid({required this.notes, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final left = <NoteModel>[];
    final right = <NoteModel>[];
    for (var i = 0; i < notes.length; i++) {
      (i.isEven ? left : right).add(notes[i]);
    }

    Widget buildColumn(List<NoteModel> column) {
      return Expanded(
        child: Column(
          children: column
              .map(
                (note) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: NoteCard(
                    note: note,
                    onTap: () => showNoteEditor(context, initialNote: note),
                    onDelete: () => onDelete(context, note),
                  ),
                ),
              )
              .toList(),
        ),
      );
    }

    return SingleChildScrollView(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildColumn(left),
          const SizedBox(width: 12),
          buildColumn(right),
        ],
      ),
    );
  }
}

class _EmptyNotesState extends StatelessWidget {
  final VoidCallback onCreate;
  const _EmptyNotesState({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.sticky_note_2_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'Пока нет ни одной заметки',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 4),
          Text(
            'Нажмите + внизу справа, чтобы создать первую',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}
