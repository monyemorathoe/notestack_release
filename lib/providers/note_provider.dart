import 'package:flutter/material.dart';
import '../models/note.dart';
import '../services/database_helper.dart';
import 'package:uuid/uuid.dart';

class NoteProvider with ChangeNotifier {
  List<Note> _allNotes = []; // Stores all notes including archived
  final List<String> _categories = ['All', 'Personal', 'Work', 'Ideas'];
  String? _selectedCategory = 'All';

  // Selection state
  final Set<String> _selectedNoteIds = {};
  bool _isSelectionMode = false;

  // For Undo functionality
  Note? _lastDeletedNote;
  // No index needed for notes as we reload and re-filter/sort

  List<String> get categories => _categories;
  String? get selectedCategory => _selectedCategory;

  Set<String> get selectedNoteIds => _selectedNoteIds;
  bool get isSelectionMode => _isSelectionMode;
  List<Note> get allNotes => _allNotes; // Primarily for internal use or specific cases like Archives

  NoteProvider() {
    loadNotes();
  }

  void _clearLastDeleted() {
    _lastDeletedNote = null;
  }

  void setCategory(String? category) {
    _selectedCategory = category;
    _clearSelection();
    _clearLastDeleted();
    notifyListeners();
  }

  Future<void> loadNotes() async {
    _allNotes = await DatabaseHelper.instance.getNotes();
    // _clearLastDeleted(); // Do not clear here as it might be needed for an immediate undo
    notifyListeners();
  }

  Future<void> addNote(String title, String content, String category, {DateTime? createdAt, int? colorValue}) async {
    final note = Note(
      id: const Uuid().v4(),
      title: title,
      content: content,
      category: category,
      createdAt: createdAt ?? DateTime.now(),
      modifiedAt: createdAt ?? DateTime.now(), 
      isArchived: false,
      isPinned: false,
      isLocked: false,
      colorValue: colorValue,
    );
    await DatabaseHelper.instance.insertNote(note);
    _clearLastDeleted();
    await loadNotes();
  }

  Future<void> updateNote(Note note) async {
    final Note noteToUpdate = Note(
      id: note.id,
      title: note.title,
      content: note.content,
      category: note.category,
      createdAt: note.createdAt,
      modifiedAt: DateTime.now(),
      isArchived: note.isArchived,
      isPinned: note.isPinned,
      isLocked: note.isLocked,
      colorValue: note.colorValue,
    );
    await DatabaseHelper.instance.updateNote(noteToUpdate);
    _clearLastDeleted();
    await loadNotes();
  }

  // Updated deleteNote for single note deletion (e.g., swipe)
  Future<void> deleteNote(String id, {bool isSwipeDelete = false}) async {
    try {
      final noteToDelete = _allNotes.firstWhere((note) => note.id == id);
      _lastDeletedNote = noteToDelete; // Store for potential undo
    } catch (e) {
      _lastDeletedNote = null; // Note not found, shouldn't happen if ID is correct
      // print("Error finding note to delete: $e");
      return; // Exit if note not found
    }
    
    await DatabaseHelper.instance.deleteNote(id);
    _selectedNoteIds.remove(id); // Ensure it's removed from selection if it was selected
    
    // If it is not a swipe delete, it means it is a bulk delete or other operation,
    // so we don't want to keep the last deleted note for swipe undo.
    if (!isSwipeDelete) {
        _clearLastDeleted();
    }
    await loadNotes(); // Reloads all notes and notifies listeners
  }

  Future<void> undoDeleteNote() async {
    if (_lastDeletedNote != null) {
      await DatabaseHelper.instance.insertNote(_lastDeletedNote!); // Re-insert the note
      await loadNotes(); // Refresh the list
      _clearLastDeleted(); // Clear after undo
    }
  }

  List<Note> getFilteredNotes() {
    List<Note> unarchivedNotes = _allNotes.where((note) => !note.isArchived).toList();
    List<Note> categoryFilteredNotes;
    if (_selectedCategory == 'All' || _selectedCategory == null) {
      categoryFilteredNotes = unarchivedNotes;
    } else {
      categoryFilteredNotes = unarchivedNotes.where((note) => note.category == _selectedCategory).toList();
    }
    categoryFilteredNotes.sort((a, b) {
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;
      return b.modifiedAt?.compareTo(a.modifiedAt ?? a.createdAt) ?? 
             b.createdAt.compareTo(a.createdAt); // Fallback to createdAt if modifiedAt is null
    });
    return categoryFilteredNotes;
  }

  List<Note> get archivedNotes {
    return _allNotes.where((note) => note.isArchived).toList()..sort((a,b) => 
        b.modifiedAt?.compareTo(a.modifiedAt ?? a.createdAt) ?? b.createdAt.compareTo(a.createdAt)
    );
  }

  void toggleNoteSelection(String noteId) {
    if (_selectedNoteIds.contains(noteId)) {
      _selectedNoteIds.remove(noteId);
    } else {
      _selectedNoteIds.add(noteId);
    }
    _isSelectionMode = _selectedNoteIds.isNotEmpty;
    _clearLastDeleted();
    notifyListeners();
  }

  void clearSelection() {
    _clearSelection();
    _clearLastDeleted(); // Also clear if selection is cleared externally
    notifyListeners();
  }

  void _clearSelection() {
    _selectedNoteIds.clear();
    _isSelectionMode = false;
  }

  bool isNoteSelected(String noteId) {
    return _selectedNoteIds.contains(noteId);
  }

  Future<void> archiveSelectedNotes() async {
    if (_selectedNoteIds.isEmpty) return;
    for (String noteId in Set.from(_selectedNoteIds)) {
      Note noteToArchive = _allNotes.firstWhere((note) => note.id == noteId, orElse: () => throw Exception("Note $noteId not found for archiving"));
      Note updatedNote = Note(
        id: noteToArchive.id,
        title: noteToArchive.title,
        content: noteToArchive.content,
        category: noteToArchive.category,
        createdAt: noteToArchive.createdAt,
        modifiedAt: DateTime.now(),
        isArchived: true,
        isPinned: noteToArchive.isPinned, // Pin status should be preserved on archive
        isLocked: noteToArchive.isLocked,
        colorValue: noteToArchive.colorValue,
      );
      await DatabaseHelper.instance.updateNote(updatedNote);
    }
    _clearLastDeleted();
    _clearSelection();
    await loadNotes();
  }

  Future<void> unarchiveSelectedNotes() async {
    if (_selectedNoteIds.isEmpty) return;
    for (String noteId in Set.from(_selectedNoteIds)) {
      Note noteToUnarchive = _allNotes.firstWhere((note) => note.id == noteId, orElse: () => throw Exception("Note $noteId not found for unarchiving"));
      Note updatedNote = Note(
        id: noteToUnarchive.id,
        title: noteToUnarchive.title,
        content: noteToUnarchive.content,
        category: noteToUnarchive.category,
        createdAt: noteToUnarchive.createdAt,
        modifiedAt: DateTime.now(),
        isArchived: false,
        isPinned: noteToUnarchive.isPinned,
        isLocked: noteToUnarchive.isLocked,
        colorValue: noteToUnarchive.colorValue,
      );
      await DatabaseHelper.instance.updateNote(updatedNote);
    }
    _clearLastDeleted();
    _clearSelection();
    await loadNotes();
  }

  Future<bool> deleteSelectedNotes() async {
    if (_selectedNoteIds.isEmpty) {
      _clearSelection();
      return true;
    }

    bool hasLockedNote = false;
    for (String id in _selectedNoteIds) {
      try {
        final note = _allNotes.firstWhere((n) => n.id == id);
        if (note.isLocked) {
          hasLockedNote = true;
          break;
        }
      } catch (e) { /* Note not found, ignore */ }
    }

    if (hasLockedNote) {
      notifyListeners(); // To allow UI to react (e.g. show dialog)
      return false;
    }

    for (String id in Set.from(_selectedNoteIds)) {
      // This is a bulk delete, so not for swipe-undo.
      await DatabaseHelper.instance.deleteNote(id);
    }
    _clearLastDeleted(); 
    _clearSelection();
    await loadNotes();
    return true;
  }

  Future<void> togglePinNote(Note note) async {
    final Note updatedNote = Note(
      id: note.id,
      title: note.title,
      content: note.content,
      category: note.category,
      createdAt: note.createdAt,
      modifiedAt: DateTime.now(),
      isArchived: note.isArchived,
      isPinned: !note.isPinned,
      isLocked: note.isLocked,
      colorValue: note.colorValue,
    );
    await DatabaseHelper.instance.updateNote(updatedNote);
    _clearLastDeleted();
    await loadNotes();
  }

  Future<void> _updateLockStatusForSelectedNotes(bool lock) async {
    if (_selectedNoteIds.isEmpty) {
      if (_isSelectionMode) {
        _isSelectionMode = false;
        notifyListeners();
      }
      return;
    }

    List<String> idsToProcess = List.from(_selectedNoteIds);

    for (String id in idsToProcess) {
      try {
        Note currentNote = _allNotes.firstWhere((note) => note.id == id);
        if (currentNote.isLocked != lock) {
          Note updatedNote = Note(
            id: currentNote.id,
            title: currentNote.title,
            content: currentNote.content,
            category: currentNote.category,
            createdAt: currentNote.createdAt,
            modifiedAt: DateTime.now(),
            isArchived: currentNote.isArchived,
            isPinned: currentNote.isPinned,
            isLocked: lock,
            colorValue: currentNote.colorValue,
          );
          await DatabaseHelper.instance.updateNote(updatedNote);
        }
      } catch (e) { /* Error finding or updating note */ }
    }
    _clearLastDeleted();
    clearSelection(); // This also calls loadNotes eventually via clearSelection -> loadNotes
    await loadNotes(); 
  }

  Future<void> lockSelectedNotes() async {
    await _updateLockStatusForSelectedNotes(true);
  }

  Future<void> unlockSelectedNotes() async {
    await _updateLockStatusForSelectedNotes(false);
  }

  Future<void> unlockAllNotes() async {
    List<Note> notesToUnlock = _allNotes.where((note) => note.isLocked).toList();
    if (notesToUnlock.isEmpty) return;

    for (Note currentNote in notesToUnlock) {
      Note updatedNote = Note(
        id: currentNote.id,
        title: currentNote.title,
        content: currentNote.content,
        category: currentNote.category,
        createdAt: currentNote.createdAt,
        modifiedAt: DateTime.now(),
        isArchived: currentNote.isArchived,
        isPinned: currentNote.isPinned,
        isLocked: false,
        colorValue: currentNote.colorValue,
      );
      await DatabaseHelper.instance.updateNote(updatedNote);
    }
    _clearLastDeleted();
    await loadNotes(); 
  }

  Future<void> pinSelectedNotes() async {
    if (selectedNoteIds.isEmpty) return;
    List<String> idsToPin = List.from(selectedNoteIds);
    bool changed = false;
    for (String noteId in idsToPin) {
      try {
        final originalNote = _allNotes.firstWhere((n) => n.id == noteId);
        if (!originalNote.isPinned) {
          final Note updatedNote = Note(
            id: originalNote.id,
            title: originalNote.title,
            content: originalNote.content,
            category: originalNote.category,
            createdAt: originalNote.createdAt,
            modifiedAt: DateTime.now(), 
            isArchived: originalNote.isArchived,
            isPinned: true,
            isLocked: originalNote.isLocked,
            colorValue: originalNote.colorValue,
          );
          await DatabaseHelper.instance.updateNote(updatedNote);
          changed = true;
        }
      } catch (e) { /* Note not found */ }
    }

    if (changed) {
      _clearLastDeleted();
      await loadNotes();
    }
    clearSelection(); 
  }

  Future<void> unpinSelectedNotes() async {
    if (selectedNoteIds.isEmpty) return;
    List<String> idsToUnpin = List.from(selectedNoteIds);
    bool changed = false;

    for (String noteId in idsToUnpin) {
      try {
        final originalNote = _allNotes.firstWhere((n) => n.id == noteId);
        if (originalNote.isPinned) {
          final Note updatedNote = Note(
            id: originalNote.id,
            title: originalNote.title,
            content: originalNote.content,
            category: originalNote.category,
            createdAt: originalNote.createdAt,
            modifiedAt: DateTime.now(),
            isArchived: originalNote.isArchived,
            isPinned: false,
            isLocked: originalNote.isLocked,
            colorValue: originalNote.colorValue,
          );
          await DatabaseHelper.instance.updateNote(updatedNote);
          changed = true;
        }
      } catch (e) { /* Note not found */ }
    }

    if (changed) {
      _clearLastDeleted();
      await loadNotes();
    }
    clearSelection();
  }
  
  Future<void> setColorForSelectedNotes(int? colorValue) async {
    if (_selectedNoteIds.isEmpty) return;

    final List<String> idsToProcess = List.from(_selectedNoteIds);
    bool changed = false;

    for (String id in idsToProcess) {
      try {
        final originalNote = _allNotes.firstWhere((n) => n.id == id);
        if (originalNote.colorValue != colorValue) {
          Note updatedNote = Note(
            id: originalNote.id,
            title: originalNote.title,
            content: originalNote.content,
            category: originalNote.category,
            createdAt: originalNote.createdAt,
            modifiedAt: DateTime.now(),
            isArchived: originalNote.isArchived,
            isPinned: originalNote.isPinned,
            isLocked: originalNote.isLocked,
            colorValue: colorValue,
          );
          await DatabaseHelper.instance.updateNote(updatedNote);
          changed = true;
        }
      } catch (e) { /* Note not found */ }
    }

    if (changed) {
      _clearLastDeleted();
      await loadNotes();
    }
    clearSelection();
  }
}
