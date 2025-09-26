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
  Note? _lastArchivedNote; // For undoing swipe archive

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

  void _clearLastArchived() {
    _lastArchivedNote = null;
  }

  void setCategory(String? category) {
    _selectedCategory = category;
    _clearSelection();
    _clearLastDeleted();
    _clearLastArchived();
    notifyListeners();
  }

  Future<void> loadNotes() async {
    _allNotes = await DatabaseHelper.instance.getNotes();
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
    _clearLastArchived();
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
    _clearLastArchived();
    await loadNotes();
  }

  Future<void> deleteNote(String id, {bool isSwipeDelete = false}) async {
    try {
      final noteToDelete = _allNotes.firstWhere((note) => note.id == id);
      if (isSwipeDelete) {
        _lastDeletedNote = noteToDelete;
        _clearLastArchived(); // Clear other undo types
      }
    } catch (e) {
      _lastDeletedNote = null;
      return;
    }
    
    await DatabaseHelper.instance.deleteNote(id);
    _selectedNoteIds.remove(id);
    
    if (!isSwipeDelete) {
        _clearLastDeleted();
    }
    await loadNotes();
  }

  Future<void> undoDeleteNote() async {
    if (_lastDeletedNote != null) {
      await DatabaseHelper.instance.insertNote(_lastDeletedNote!); 
      await loadNotes(); 
      _clearLastDeleted(); 
    }
  }

  Future<void> archiveNote(String id, {bool isSwipeArchive = false}) async {
    Note? noteToArchive;
    try {
      noteToArchive = _allNotes.firstWhere((note) => note.id == id);
    } catch (e) {
      // print("Note $id not found for archiving: $e");
      return;
    }

    if (isSwipeArchive) {
      _lastArchivedNote = noteToArchive;
      _clearLastDeleted(); // Clear other undo types
    }

    Note updatedNote = Note(
      id: noteToArchive.id,
      title: noteToArchive.title,
      content: noteToArchive.content,
      category: noteToArchive.category,
      createdAt: noteToArchive.createdAt,
      modifiedAt: DateTime.now(),
      isArchived: true, // Set to archived
      isPinned: noteToArchive.isPinned, 
      isLocked: noteToArchive.isLocked,
      colorValue: noteToArchive.colorValue,
    );
    await DatabaseHelper.instance.updateNote(updatedNote);
    _selectedNoteIds.remove(id); // Remove from selection if present

    if (!isSwipeArchive) {
        _clearLastArchived();
    }
    await loadNotes();
  }

  Future<void> undoArchiveNote() async {
    if (_lastArchivedNote != null) {
      Note noteToUnarchive = _lastArchivedNote!;
      Note updatedNote = Note(
        id: noteToUnarchive.id,
        title: noteToUnarchive.title,
        content: noteToUnarchive.content,
        category: noteToUnarchive.category,
        createdAt: noteToUnarchive.createdAt,
        modifiedAt: DateTime.now(), // Or keep original modifiedAt if preferred on undo
        isArchived: false, // Set to unarchived
        isPinned: noteToUnarchive.isPinned,
        isLocked: noteToUnarchive.isLocked,
        colorValue: noteToUnarchive.colorValue,
      );
      await DatabaseHelper.instance.updateNote(updatedNote);
      await loadNotes();
      _clearLastArchived();
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
             b.createdAt.compareTo(a.createdAt);
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
    _clearLastArchived();
    notifyListeners();
  }

  void clearSelection() {
    _clearSelection();
    _clearLastDeleted(); 
    _clearLastArchived();
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
      await archiveNote(noteId, isSwipeArchive: false); // Use the new common archiveNote method
    }
    _clearLastArchived(); // Ensure this is cleared after bulk operation
    _clearSelection();
    await loadNotes(); // loadNotes is called within archiveNote, but an extra one here ensures UI consistency after loop
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
    _clearLastArchived();
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
      notifyListeners(); 
      return false;
    }

    for (String id in Set.from(_selectedNoteIds)) {
      await DatabaseHelper.instance.deleteNote(id);
    }
    _clearLastDeleted(); 
    _clearLastArchived();
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
    _clearLastArchived();
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
    _clearLastArchived();
    clearSelection(); 
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
    _clearLastArchived();
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
      _clearLastArchived();
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
      _clearLastArchived();
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
      _clearLastArchived();
      await loadNotes();
    }
    clearSelection();
  }
}
