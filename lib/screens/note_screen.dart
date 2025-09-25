import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import 'package:notestack/services/secure_storage_service.dart';
import '../models/note.dart';
import '../providers/note_provider.dart';

class NoteScreen extends StatefulWidget {
  final Note? note;

  const NoteScreen({super.key, this.note});

  @override
  NoteScreenState createState() => NoteScreenState();
}

class NoteScreenState extends State<NoteScreen> {
  final _titleController = TextEditingController();
  late QuillController _quillController;
  final _passwordController = TextEditingController();
  final SecureStorageService _secureStorageService = SecureStorageService();
  String _selectedCategory = 'Personal';
  int? _selectedColorValue;
  DateTime? _createdAt;
  bool _isLocked = false;
  bool _isTemporarilyUnlocked = false;
  bool _showToolbar = false; // Start collapsed by default
  bool _showCategoryDropdown = false;

  final List<Color> _defaultColors = [
    Colors.red[200]!, Colors.orange[200]!, Colors.yellow[200]!,
    Colors.green[200]!, Colors.blue[200]!, Colors.indigo[200]!,
    Colors.purple[200]!, Colors.pink[200]!, Colors.teal[200]!,
    Colors.cyan[200]!, Colors.lime[200]!, Colors.grey[400]!,
  ];

  @override
  void initState() {
    super.initState();
    _initializeNote();
  }

  void _initializeNote() {
    Document document;
    if (widget.note != null) {
      _titleController.text = widget.note!.title;
      _selectedCategory = widget.note!.category;
      _selectedColorValue = widget.note!.colorValue;
      _createdAt = widget.note!.createdAt;
      _isLocked = widget.note!.isLocked;

      try {
        document = widget.note!.content.isNotEmpty
            ? Document.fromJson(jsonDecode(widget.note!.content))
            : Document();
      } catch (e) {
        document = Document()..insert(0, widget.note!.content);
      }
    } else {
      document = Document();
      final categories = Provider.of<NoteProvider>(context, listen: false).categories;
      if (categories.isNotEmpty && !categories.contains('All')) {
        _selectedCategory = categories.firstWhere((c) => c != 'All', orElse: () => 'Personal');
      }
      _createdAt = DateTime.now();
    }
    _quillController = QuillController(
        document: document,
        selection: const TextSelection.collapsed(offset: 0)
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _quillController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _saveNote() {
    final title = _titleController.text.trim();
    final contentJson = jsonEncode(_quillController.document.toDelta().toJson());

    if (title.isEmpty && _quillController.document.isEmpty() && widget.note == null) return;

    final noteProvider = Provider.of<NoteProvider>(context, listen: false);
    final now = DateTime.now();

    if (widget.note == null) {
      noteProvider.addNote(
        title, contentJson, _selectedCategory,
        colorValue: _selectedColorValue,
        createdAt: now,
      );
    } else {
      noteProvider.updateNote(Note(
        id: widget.note!.id, title: title, content: contentJson,
        category: _selectedCategory, createdAt: widget.note!.createdAt,
        modifiedAt: now, isArchived: widget.note!.isArchived,
        isPinned: widget.note!.isPinned, isLocked: widget.note!.isLocked,
        colorValue: _selectedColorValue,
      ));
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _showColorPickerDialog() async {
    int? newColorValue = await showDialog<int>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: ZoomIn(
            duration: const Duration(milliseconds: 250),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Select Note Color', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: _defaultColors.map((color) {
                    final colorValue = color.toARGB32() & 0xFFFFFFFF;
                    return InkWell(
                      onTap: () => Navigator.of(context).pop(colorValue),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _selectedColorValue == colorValue
                                  ? Theme.of(context).colorScheme.onSurface
                                  : Colors.transparent,
                              width: 2,
                            )),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(_selectedColorValue),
                      child: const Text('Cancel'),
                    ),
                    if (_selectedColorValue != null) ...[
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(null),
                        child: const Text('Clear Color'),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (newColorValue != _selectedColorValue) {
      setState(() => _selectedColorValue = newColorValue);
    }
  }

  Widget _buildCategorySelector(List<String> availableCategories, bool isEditable) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: InkWell(
        onTap: isEditable ? () => setState(() => _showCategoryDropdown = !_showCategoryDropdown) : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.category_outlined, size: 20),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Category: $_selectedCategory')),
                  Icon(_showCategoryDropdown ? Icons.expand_less : Icons.expand_more),
                ],
              ),
              if (_showCategoryDropdown) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: availableCategories.map((cat) {
                    return FilterChip(
                      label: Text(cat),
                      selected: _selectedCategory == cat,
                      onSelected: isEditable ? (selected) {
                        if (selected) {
                          setState(() {
                            _selectedCategory = cat;
                            _showCategoryDropdown = false;
                          });
                        }
                      } : null,
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToolbarCard() {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: InkWell(
        onTap: () => setState(() => _showToolbar = !_showToolbar),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.format_color_text, size: 20),
                  const SizedBox(width: 12),
                  const Expanded(child: Text('Formatting Tools')),
                  // Vertically aligned chevron, matching category selector
                  Icon(_showToolbar ? Icons.expand_less : Icons.expand_more),
                ],
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                child: SizedBox(
                  height: _showToolbar ? null : 0,
                  child: _showToolbar ? QuillSimpleToolbar(
                    controller: _quillController,
                    config: const QuillSimpleToolbarConfig(
                      showBackgroundColorButton: false,
                    ),
                  ) : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLockedState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 64),
            const SizedBox(height: 16),
            Text('This note is locked', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text('Enter your password to unlock', style: theme.textTheme.bodyLarge),
            const SizedBox(height: 24),
            Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          hintText: 'Enter password...',
                          border: InputBorder.none,
                        ),
                        onSubmitted: (_) => _unlockNote(),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.lock_open),
                      onPressed: _unlockNote,
                      tooltip: 'Unlock',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _unlockNote() async {
    final password = _passwordController.text;
    if (password.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password cannot be empty')));
      }
      return;
    }

    final isCorrect = await _secureStorageService.verifyPassword(password);
    if (isCorrect && mounted) {
      setState(() => _isTemporarilyUnlocked = true);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Incorrect password')));
    }
  }

  String _formatDateTime(DateTime? dateTime) {
    return dateTime != null ? DateFormat.yMMMd().add_jm().format(dateTime) : 'N/A';
  }

  @override
  Widget build(BuildContext context) {
    final noteProvider = Provider.of<NoteProvider>(context, listen: false);
    final availableCategories = noteProvider.categories.where((c) => c != 'All').toList();

    if (availableCategories.isEmpty) availableCategories.add('Personal');
    if (!availableCategories.contains(_selectedCategory)) {
      _selectedCategory = availableCategories.first;
    }

    final theme = Theme.of(context);
    final isEditable = !_isLocked || _isTemporarilyUnlocked;

    // App bar color calculation
    Color appBarColor = _selectedColorValue != null
        ? Color(_selectedColorValue!).withAlpha((0.7 * 255).toInt())
        : theme.appBarTheme.backgroundColor ?? theme.colorScheme.primary;

    Color appBarForegroundColor = ThemeData.estimateBrightnessForColor(appBarColor) == Brightness.dark
        ? Colors.white : Colors.black;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.note == null ? 'New Note' : 'Edit Note',
            style: TextStyle(color: appBarForegroundColor)),
        backgroundColor: appBarColor,
        elevation: _selectedColorValue != null ? 0 : null,
        iconTheme: IconThemeData(color: appBarForegroundColor),
        actionsIconTheme: IconThemeData(color: appBarForegroundColor),
        actions: [
          IconButton(
            icon: const Icon(Icons.palette_outlined),
            onPressed: isEditable ? _showColorPickerDialog : null,
            tooltip: 'Change color',
          ),
          if (widget.note != null) IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: isEditable ? () {
              noteProvider.deleteNote(widget.note!.id);
              if (mounted) Navigator.pop(context);
            } : null,
            tooltip: 'Delete note',
          ),
          IconButton(
            icon: const Icon(Icons.save_outlined),
            onPressed: isEditable ? _saveNote : null,
            tooltip: 'Save note',
          ),
          if (Platform.isWindows) const SizedBox(width: 10),
        ],
      ),
      body: FadeIn(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: !isEditable ? _buildLockedState(theme) : Column(
            children: [
              // Formatting toolbar (collapsible)
              _buildToolbarCard(),

              // Category selector (compact dropdown style)
              _buildCategorySelector(availableCategories, isEditable),

              // Note content area (maximized space)
              Expanded(
                child: Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _titleController,
                          decoration: const InputDecoration(
                            hintText: 'Title',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
                          textCapitalization: TextCapitalization.sentences,
                        ),
                        const SizedBox(height: 8),
                        const Divider(height: 1),
                        const SizedBox(height: 12),
                        Expanded(
                          child: QuillEditor.basic(
                            controller: _quillController,
                            config: const QuillEditorConfig(
                              padding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Created date (subtle footer)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'Created: ${_formatDateTime(_createdAt)}',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}