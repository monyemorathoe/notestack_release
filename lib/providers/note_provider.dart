import 'dart:convert'; // Added for jsonDecode
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart'; // Added for Document
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
  List<Note> get allNotes => List.unmodifiable(_allNotes); // Return unmodifiable list

  NoteProvider() {
    loadNotes();
  }

  String _getPlainTextFromDeltaJson(String deltaJson) {
    if (deltaJson.isEmpty) {
      return '';
    }
    try {
      final List<dynamic> jsonData = jsonDecode(deltaJson);
      final doc = Document.fromJson(jsonData);
      return doc.toPlainText().trim();
    } catch (e) {
      return deltaJson.trim();
    }
  }

  void _clearLastDeleted() {
    _lastDeletedNote = null;
  }

  void _clearLastArchived() {
    _lastArchivedNote = null;
  }

  void _sortNotes() {
    _allNotes.sort((a, b) {
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;
      final modCompare = (b.modifiedAt ?? b.createdAt).compareTo(a.modifiedAt ?? a.createdAt);
      if (modCompare != 0) return modCompare;
      return b.createdAt.compareTo(a.createdAt);
    });
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
    _sortNotes(); // Ensure notes are sorted after loading
    notifyListeners();
  }

  Future<void> addNote(String title, String contentJson, String category, {DateTime? createdAt, int? colorValue}) async {
    final plainTextContent = _getPlainTextFromDeltaJson(contentJson);
    final now = createdAt ?? DateTime.now();
    final note = Note(
      id: const Uuid().v4(),
      title: title,
      content: contentJson,
      plainTextContent: plainTextContent,
      category: category,
      createdAt: now,
      modifiedAt: now,
      isArchived: false,
      isPinned: false,
      isLocked: false,
      colorValue: colorValue,
    );
    await DatabaseHelper.instance.insertNote(note);
    _allNotes.add(note); // Optimistic add
    _sortNotes();
    _clearLastDeleted();
    _clearLastArchived();
    notifyListeners();
  }

  Future<void> updateNote(Note note, {bool skipSortAndNotify = false}) async {
    final plainTextContent = _getPlainTextFromDeltaJson(note.content);
    final Note noteToUpdate = Note(
      id: note.id,
      title: note.title,
      content: note.content,
      plainTextContent: plainTextContent,
      category: note.category,
      createdAt: note.createdAt,
      modifiedAt: DateTime.now(),
      isArchived: note.isArchived,
      isPinned: note.isPinned,
      isLocked: note.isLocked,
      colorValue: note.colorValue,
    );
    
    final index = _allNotes.indexWhere((n) => n.id == noteToUpdate.id);
    if (index != -1) {
      _allNotes[index] = noteToUpdate; // Optimistic update
    }
    
    if (!skipSortAndNotify) {
      _sortNotes();
      _clearLastDeleted();
      _clearLastArchived();
      notifyListeners();
    }

    await DatabaseHelper.instance.updateNote(noteToUpdate);
  }

  Future<void> deleteNote(String id, {bool isSwipeDelete = false}) async {
    Note? noteToDelete;
    int originalIndex = -1;

    try {
      originalIndex = _allNotes.indexWhere((note) => note.id == id);
      if (originalIndex != -1) {
        noteToDelete = _allNotes[originalIndex];
      } else {
        return; // Note not found in local list
      }

      if (isSwipeDelete) {
        _lastDeletedNote = noteToDelete;
        _clearLastArchived();
      } else {
        _clearLastDeleted();
      }

      _allNotes.removeAt(originalIndex); // Optimistic remove
      _selectedNoteIds.remove(id);
      notifyListeners(); // Notify immediately

      await DatabaseHelper.instance.deleteNote(id);

    } catch (e) {
      // print("Error deleting note: $e");
      if (noteToDelete != null && isSwipeDelete && originalIndex != -1) {
        // Revert optimistic delete if DB operation failed for swipe
        _allNotes.insert(originalIndex, noteToDelete);
        _lastDeletedNote = null; // Clear undo state as it failed
        notifyListeners();
      }
      // For non-swipe deletes, or if re-adding fails, a full loadNotes() might be a fallback.
      // Consider a more robust error handling / user notification strategy here.
    }
  }

  Future<void> undoDeleteNote() async {
    if (_lastDeletedNote != null) {
      Note noteToRestore = _lastDeletedNote!;
      _allNotes.add(noteToRestore); // Optimistic add back
      _sortNotes();
      _lastDeletedNote = null;
      notifyListeners(); // Notify immediately

      try {
        await DatabaseHelper.instance.insertNote(noteToRestore);
      } catch (e) {
        // print("Error undoing delete: $e");
        // Revert optimistic undo if DB operation failed
        _allNotes.removeWhere((n) => n.id == noteToRestore.id);
        notifyListeners();
        // Consider a more robust error handling / user notification strategy here.
      }
    }
  }

  Future<void> archiveNote(String id, {bool isSwipeArchive = false}) async {
    Note? originalNote;
    int originalIndex = -1;

    try {
      originalIndex = _allNotes.indexWhere((note) => note.id == id);
      if (originalIndex != -1) {
        originalNote = _allNotes[originalIndex];
      } else {
        return; // Note not found
      }

      Note updatedNote = originalNote.copyWith(
        isArchived: true,
        modifiedAt: DateTime.now(),
      );

      if (isSwipeArchive) {
        _lastArchivedNote = originalNote; // Store original for undo
        _clearLastDeleted();
      } else {
        _clearLastArchived();
      }

      _allNotes[originalIndex] = updatedNote; // Optimistic update
      _selectedNoteIds.remove(id);
      _sortNotes(); // Re-sort as archiving can affect filtered list
      notifyListeners(); // Notify immediately

      await DatabaseHelper.instance.updateNote(updatedNote);

    } catch (e) {
      // print("Error archiving note: $e");
      if (originalNote != null && isSwipeArchive && originalIndex != -1) {
        // Revert optimistic archive if DB operation failed for swipe
        _allNotes[originalIndex] = originalNote;
        _lastArchivedNote = null;
        _sortNotes();
        notifyListeners();
      }
      // Consider a more robust error handling.
    }
  }

  Future<void> undoArchiveNote() async {
    if (_lastArchivedNote != null) {
      Note noteToRestoreOriginalState = _lastArchivedNote!;
      Note noteToUnarchive = noteToRestoreOriginalState.copyWith(
        isArchived: false,
        modifiedAt: DateTime.now(),
      );
      
      int index = _allNotes.indexWhere((n) => n.id == noteToUnarchive.id);
      if (index != -1) {
        _allNotes[index] = noteToUnarchive; // Optimistic update
      }
      _sortNotes();
      _lastArchivedNote = null;
      notifyListeners(); // Notify immediately

      try {
        await DatabaseHelper.instance.updateNote(noteToUnarchive);
      } catch (e) {
        // print("Error undoing archive: $e");
        // Revert optimistic undo if DB operation failed
        if (index != -1) {
           _allNotes[index] = noteToRestoreOriginalState; // Restore original archived state
        }
        _sortNotes();
        notifyListeners();
        // Consider a more robust error handling.
      }
    }
  }

  List<Note> getFilteredNotes() {
    List<Note> unarchivedNotes = _allNotes.where((note) => !note.isArchived).toList();
    // _sortNotes() is called after any modification to _allNotes, so it's already sorted.
    // We just filter by category here.
    if (_selectedCategory == 'All' || _selectedCategory == null) {
      return unarchivedNotes;
    } else {
      return unarchivedNotes.where((note) => note.category == _selectedCategory).toList();
    }
  }

  List<Note> get archivedNotes {
    // _sortNotes() ensures _allNotes is sorted correctly.
    return _allNotes.where((note) => note.isArchived).toList();
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

  // For bulk operations, we might still want to do a full load or ensure consistency.
  // The swipe actions are the most sensitive to the Dismissible issue.

  Future<void> archiveSelectedNotes() async {
    if (_selectedNoteIds.isEmpty) return;
    List<String> idsToProcess = List.from(_selectedNoteIds);
    _clearSelection(); // Clear selection early for UI responsiveness
    notifyListeners();

    for (String noteId in idsToProcess) {
      await archiveNote(noteId, isSwipeArchive: false);
    }
    // No explicit loadNotes() here if archiveNote handles its optimistic update correctly.
    // However, since multiple items are changed, a final sort and notify might be good.
    _sortNotes();
    notifyListeners();
  }

  Future<void> unarchiveSelectedNotes() async {
    if (_selectedNoteIds.isEmpty) return;
    List<String> idsToProcess = List.from(_selectedNoteIds);
     _clearSelection(); // Clear selection early
    notifyListeners();

    for (String noteId in idsToProcess) {
       Note? originalNote;
      int originalIndex = -1;
      try {
        originalIndex = _allNotes.indexWhere((note) => note.id == noteId);
        if (originalIndex != -1) {
          originalNote = _allNotes[originalIndex];
        } else {
          continue; 
        }

        Note updatedNote = originalNote.copyWith(
          isArchived: false,
          modifiedAt: DateTime.now(),
        );
        _allNotes[originalIndex] = updatedNote; // Optimistic
        await DatabaseHelper.instance.updateNote(updatedNote);
      } catch (e) {
        // print("Error unarchiving note $noteId: $e");
        if(originalNote != null && originalIndex != -1) {
          _allNotes[originalIndex] = originalNote; // Revert
        }
      }
    }
    _sortNotes();
    notifyListeners();
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
    List<String> idsToDelete = List.from(_selectedNoteIds);
    _clearSelection(); // Clear selection early
    notifyListeners();
    
    List<Note> successfullyDeletedNotesForUI = [];

    for (String id in idsToDelete) {
      int originalIndex = _allNotes.indexWhere((note) => note.id == id);
      if (originalIndex != -1) {
        successfullyDeletedNotesForUI.add(_allNotes.removeAt(originalIndex)); // Optimistic remove
      }
    }
    notifyListeners(); // Notify after all local removals

    for (String id in idsToDelete) { // DB operations
        try {
            await DatabaseHelper.instance.deleteNote(id);
        } catch(e) {
            // print("Failed to delete $id from DB. It was already removed from UI.");
            // Optionally, re-add to _allNotes if critical, or log error
        }
    }
    _clearLastDeleted(); 
    _clearLastArchived();
    // _sortNotes(); // Already sorted as we only removed items or handled order above
    // notifyListeners(); // Already notified
    return true;
  }

  Future<void> togglePinNote(Note note) async {
    final Note updatedNote = note.copyWith(
      isPinned: !note.isPinned,
      modifiedAt: DateTime.now(),
    );
    await updateNote(updatedNote);
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
    _clearSelection(); // Clear selection early for UI
    notifyListeners();

    for (String id in idsToProcess) {
      int index = _allNotes.indexWhere((n) => n.id == id);
      if (index != -1) {
        Note originalNote = _allNotes[index];
        if (originalNote.isLocked != lock) {
          Note updatedNote = originalNote.copyWith(
            isLocked: lock,
            modifiedAt: DateTime.now(),
          );
           _allNotes[index] = updatedNote; // Optimistic
           await DatabaseHelper.instance.updateNote(updatedNote); // DB update follows
        }
      }
    }
    _sortNotes();
    notifyListeners();
  }

  Future<void> lockSelectedNotes() async {
    await _updateLockStatusForSelectedNotes(true);
  }

  Future<void> unlockSelectedNotes() async {
    await _updateLockStatusForSelectedNotes(false);
  }

  Future<void> unlockAllNotes() async {
    List<Note> notesToActuallyUnlock = _allNotes.where((note) => note.isLocked).toList();
    if (notesToActuallyUnlock.isEmpty) return;

    for (Note currentNote in notesToActuallyUnlock) {
      int index = _allNotes.indexWhere((n) => n.id == currentNote.id);
      if(index != -1) {
        Note updatedNote = currentNote.copyWith(
          isLocked: false,
          modifiedAt: DateTime.now(),
        );
        _allNotes[index] = updatedNote; // Optimistic
        await DatabaseHelper.instance.updateNote(updatedNote);
      }
    }
    _sortNotes();
    notifyListeners();
  }

  Future<void> pinSelectedNotes() async {
    if (selectedNoteIds.isEmpty) return;
    List<String> idsToPin = List.from(selectedNoteIds);
    _clearSelection();
    notifyListeners();

    for (String noteId in idsToPin) {
      int index = _allNotes.indexWhere((n) => n.id == noteId);
      if (index != -1) {
        Note originalNote = _allNotes[index];
        if (!originalNote.isPinned) {
          Note updatedNote = originalNote.copyWith(
            isPinned: true,
            modifiedAt: DateTime.now(),
          );
          _allNotes[index] = updatedNote;
          await DatabaseHelper.instance.updateNote(updatedNote);
        }
      }
    }
    _sortNotes();
    notifyListeners();
  }

  Future<void> unpinSelectedNotes() async {
    if (selectedNoteIds.isEmpty) return;
    List<String> idsToUnpin = List.from(selectedNoteIds);
    _clearSelection();
    notifyListeners();

    for (String noteId in idsToUnpin) {
      int index = _allNotes.indexWhere((n) => n.id == noteId);
      if (index != -1) {
        Note originalNote = _allNotes[index];
        if (originalNote.isPinned) {
          Note updatedNote = originalNote.copyWith(
            isPinned: false,
            modifiedAt: DateTime.now(),
          );
          _allNotes[index] = updatedNote;
          await DatabaseHelper.instance.updateNote(updatedNote);
        }
      }
    }
    _sortNotes();
    notifyListeners();
  }
  
  Future<void> setColorForSelectedNotes(int? colorValue) async {
    if (_selectedNoteIds.isEmpty) return;

    final List<String> idsToProcess = List.from(_selectedNoteIds);
    _clearSelection();
    notifyListeners();
    
    for (String id in idsToProcess) {
      int index = _allNotes.indexWhere((n) => n.id == id);
      if (index != -1) {
        Note originalNote = _allNotes[index];
         if (originalNote.colorValue != colorValue) {
            Note updatedNote = originalNote.copyWith(
              colorValue: colorValue,
              modifiedAt: DateTime.now(),
            );
           _allNotes[index] = updatedNote;
           await DatabaseHelper.instance.updateNote(updatedNote);
         }
      }
    }
    _sortNotes();
    notifyListeners();
  }
}

// Added copyWith to Note model for easier updates
extension NoteCopyWith on Note {
  Note copyWith({
    String? id,
    String? title,
    String? content,
    String? plainTextContent,
    String? category,
    DateTime? createdAt,
    DateTime? modifiedAt,
    bool? isArchived,
    bool? isPinned,
    bool? isLocked,
    int? colorValue,
    bool clearColorValue = false, // Added to explicitly set colorValue to null
  }) {
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      plainTextContent: plainTextContent ?? this.plainTextContent,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      isArchived: isArchived ?? this.isArchived,
      isPinned: isPinned ?? this.isPinned,
      isLocked: isLocked ?? this.isLocked,
      colorValue: clearColorValue ? null : (colorValue ?? this.colorValue),
    );
  }
}
