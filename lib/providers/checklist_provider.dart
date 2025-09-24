import 'package:flutter/material.dart';
import '../models/checklist_item.dart';
import '../services/checklist_database.dart';

class ChecklistProvider extends ChangeNotifier {
  final List<ChecklistItem> _items = [];
  int _nextId = 0;

  // For Undo functionality
  ChecklistItem? _lastDeletedItem;
  int? _lastDeletedItemIndex;

  ChecklistProvider() {
    _loadItems();
  }

  Future<void> _loadItems() async {
    final loadedItems = await ChecklistDatabase.getItems();
    _items.clear();
    _items.addAll(loadedItems);
    if (_items.isNotEmpty) {
      _nextId = _items.map((e) => e.id).reduce((a, b) => a > b ? a : b) + 1;
    }
    notifyListeners();
  }

  List<ChecklistItem> get items => List.unmodifiable(_items);

  void addItem(String title) {
    final item = ChecklistItem(
      id: _nextId++,
      title: title,
    );
    _items.add(item); // Adds to the end by default
    ChecklistDatabase.insertItem(item);
    _lastDeletedItem = null; // Clear last deleted on new action
    _lastDeletedItemIndex = null;
    notifyListeners();
  }

  void toggleDone(int id) {
    try {
      final item = _items.firstWhere((i) => i.id == id);
      item.isDone = !item.isDone;
      ChecklistDatabase.updateItem(item);
      _lastDeletedItem = null; // Clear last deleted on new action
      _lastDeletedItemIndex = null;
      notifyListeners();
    } catch (e) {
      // Consider logging this error to a more robust system if needed
      // print('Error toggling done for item $id: $e');
    }
  }

  Future<void> updateChecklistItem({
    required int id,
    required String newTitle,
  }) async {
    try {
      final item = _items.firstWhere((i) => i.id == id);
      item.title = newTitle;
      await ChecklistDatabase.updateItem(item);
      _lastDeletedItem = null; // Clear last deleted on new action
      _lastDeletedItemIndex = null;
      notifyListeners();
    } catch (e) {
      // print('Error updating checklist item $id: $e');
    }
  }

  void deleteItem(int id) {
    try {
      _lastDeletedItemIndex = _items.indexWhere((i) => i.id == id);
      if (_lastDeletedItemIndex != -1) {
        _lastDeletedItem = _items[_lastDeletedItemIndex!];
        _items.removeAt(_lastDeletedItemIndex!);
        ChecklistDatabase.deleteItem(id);
        notifyListeners();
      } else {
        _lastDeletedItem = null;
        _lastDeletedItemIndex = null;
      }
    } catch (e) {
      // print('Error deleting item $id: $e');
      _lastDeletedItem = null;
      _lastDeletedItemIndex = null;
    }
  }

  Future<void> undoDeleteItem() async {
    if (_lastDeletedItem != null && _lastDeletedItemIndex != null) {
      if (_lastDeletedItemIndex! >= 0 && _lastDeletedItemIndex! <= _items.length) {
        _items.insert(_lastDeletedItemIndex!, _lastDeletedItem!);
        await ChecklistDatabase.insertItem(_lastDeletedItem!); // Use insertItem as it handles conflict/replace
      } else {
        // Index out of bounds, add to the end as a fallback
        _items.add(_lastDeletedItem!);
        await ChecklistDatabase.insertItem(_lastDeletedItem!); 
      }
      _lastDeletedItem = null;
      _lastDeletedItemIndex = null;
      notifyListeners();
    }
  }

  void reorderItem(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final ChecklistItem item = _items.removeAt(oldIndex);
    _items.insert(newIndex, item);
    _lastDeletedItem = null; // Clear last deleted on new action
    _lastDeletedItemIndex = null;
    notifyListeners();
  }

  void sortItemsByDefault() {
    _items.sort((a, b) {
      if (a.isDone != b.isDone) {
        return a.isDone ? 1 : -1;
      }
      return a.id.compareTo(b.id);
    });
    _lastDeletedItem = null; // Clear last deleted on new action
    _lastDeletedItemIndex = null;
    notifyListeners();
  }
}
