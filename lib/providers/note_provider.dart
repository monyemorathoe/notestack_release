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
  List<Note> get allNotes => _allNotes; // Primarily for internal use or specific cases like Archives

  NoteProvider() {
    loadNotes();
  }

  // Helper to convert Quill Delta JSON string to plain text
  String _getPlainTextFromDeltaJson(String deltaJson) {
    if (deltaJson.isEmpty) {
      return '';
    }
    try {
      final List<dynamic> jsonData = jsonDecode(deltaJson);
      final doc = Document.fromJson(jsonData);
      return doc.toPlainText().trim();
    } catch (e) {
      // Fallback for old plain text data or if JSON is invalid
      // print("Error decoding JSON in provider, using raw content: $e");
      return deltaJson.trim(); 
    }
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
    _clearLastDeleted();
    _clearLastArchived();
    await loadNotes();
  }

  Future<void> updateNote(Note note) async {
    // When a note is fundamentally updated (e.g. title or content change),
    // its plainTextContent is re-derived from the main content.
    final plainTextContent = _getPlainTextFromDeltaJson(note.content);
    final Note noteToUpdate = Note(
      id: note.id,
      title: note.title,
      content: note.content,
      plainTextContent: plainTextContent, // Ensure this is passed
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
      return;
    }

    if (isSwipeArchive) {
      _lastArchivedNote = noteToArchive;
      _clearLastDeleted(); 
    }
    // For archiving, content doesn't change, so plainTextContent is carried over.
    Note updatedNote = Note(
      id: noteToArchive.id,
      title: noteToArchive.title,
      content: noteToArchive.content,
      plainTextContent: noteToArchive.plainTextContent, // Carry over existing plainTextContent
      category: noteToArchive.category,
      createdAt: noteToArchive.createdAt,
      modifiedAt: DateTime.now(),
      isArchived: true, 
      isPinned: noteToArchive.isPinned, 
      isLocked: noteToArchive.isLocked,
      colorValue: noteToArchive.colorValue,
    );
    await DatabaseHelper.instance.updateNote(updatedNote);
    _selectedNoteIds.remove(id); 

    if (!isSwipeArchive) {
        _clearLastArchived();
    }
    await loadNotes();
  }

  Future<void> undoArchiveNote() async {
    if (_lastArchivedNote != null) {
      Note noteToUnarchive = _lastArchivedNote!;
      // For undoing archive, content doesn't change, so plainTextContent is carried over.
      Note updatedNote = Note(
        id: noteToUnarchive.id,
        title: noteToUnarchive.title,
        content: noteToUnarchive.content,
        plainTextContent: noteToUnarchive.plainTextContent, // Carry over existing plainTextContent
        category: noteToUnarchive.category,
        createdAt: noteToUnarchive.createdAt,
        modifiedAt: DateTime.now(), 
        isArchived: false, 
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
      final modCompare = (b.modifiedAt ?? b.createdAt).compareTo(a.modifiedAt ?? a.createdAt);
      if (modCompare != 0) return modCompare;
      return b.createdAt.compareTo(a.createdAt);
    });
    return categoryFilteredNotes;
  }

  List<Note> get archivedNotes {
    return _allNotes.where((note) => note.isArchived).toList()..sort((a,b) => 
        (b.modifiedAt ?? b.createdAt).compareTo(a.modifiedAt ?? a.createdAt)
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
      await archiveNote(noteId, isSwipeArchive: false); 
    }
    _clearLastArchived(); 
    _clearSelection();
    await loadNotes(); 
  }

  Future<void> unarchiveSelectedNotes() async {
    if (_selectedNoteIds.isEmpty) return;
    for (String noteId in Set.from(_selectedNoteIds)) {
      Note noteToUnarchive = _allNotes.firstWhere((note) => note.id == noteId, orElse: () => throw Exception("Note $noteId not found for unarchiving"));
      // For unarchiving, content doesn't change, so plainTextContent is carried over.
      Note updatedNote = Note(
        id: noteToUnarchive.id,
        title: noteToUnarchive.title,
        content: noteToUnarchive.content,
        plainTextContent: noteToUnarchive.plainTextContent, // Carry over existing plainTextContent
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
    // For toggling pin, content doesn't change, so plainTextContent is carried over.
    final Note updatedNote = Note(
      id: note.id,
      title: note.title,
      content: note.content,
      plainTextContent: note.plainTextContent, // Carry over existing plainTextContent
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
          // For locking/unlocking, content doesn't change, so plainTextContent is carried over.
          Note updatedNote = Note(
            id: currentNote.id,
            title: currentNote.title,
            content: currentNote.content,
            plainTextContent: currentNote.plainTextContent, // Carry over existing plainTextContent
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
      // For unlocking, content doesn't change, so plainTextContent is carried over.
      Note updatedNote = Note(
        id: currentNote.id,
        title: currentNote.title,
        content: currentNote.content,
        plainTextContent: currentNote.plainTextContent, // Carry over existing plainTextContent
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
          // For pinning, content doesn't change, so plainTextContent is carried over.
          final Note updatedNote = Note(
            id: originalNote.id,
            title: originalNote.title,
            content: originalNote.content,
            plainTextContent: originalNote.plainTextContent, // Carry over existing plainTextContent
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
          // For unpinning, content doesn't change, so plainTextContent is carried over.
          final Note updatedNote = Note(
            id: originalNote.id,
            title: originalNote.title,
            content: originalNote.content,
            plainTextContent: originalNote.plainTextContent, // Carry over existing plainTextContent
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
          // For setting color, content doesn't change, so plainTextContent is carried over.
          Note updatedNote = Note(
            id: originalNote.id,
            title: originalNote.title,
            content: originalNote.content,
            plainTextContent: originalNote.plainTextContent, // Carry over existing plainTextContent
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
