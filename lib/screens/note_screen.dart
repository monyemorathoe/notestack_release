import 'dart:convert';
import 'dart:io'; // Added for Platform check
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart'; // For date formatting
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
  String _selectedCategory = 'Personal'; // Default category
  int? _selectedColorValue;
  DateTime? _createdAt;
  bool _isLocked = false;
  bool _isTemporarilyUnlocked = false;
  bool _showToolbar = true;

  // Predefined Material colors for the picker
  final List<Color> _defaultColors = [
    Colors.red[200]!,
    Colors.orange[200]!,
    Colors.yellow[200]!,
    Colors.green[200]!,
    Colors.blue[200]!,
    Colors.indigo[200]!,
    Colors.purple[200]!,
    Colors.pink[200]!,
    Colors.teal[200]!,
    Colors.cyan[200]!,
    Colors.lime[200]!,
    Colors.grey[400]!,
  ];

  @override
  void initState() {
    super.initState();
    Document document;
    if (widget.note != null) {
      _titleController.text = widget.note!.title;
      _selectedCategory = widget.note!.category;
      _selectedColorValue = widget.note!.colorValue;
      _createdAt = widget.note!.createdAt;
      _isLocked = widget.note!.isLocked;
      try {
        if (widget.note!.content.isNotEmpty) {
          final List<dynamic> jsonData = jsonDecode(widget.note!.content);
          document = Document.fromJson(jsonData);
        } else {
          document = Document();
        }
      } catch (e) {
        // If content is not valid JSON (e.g., plain text from old version)
        // create a document with the existing content as a single line.
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
    _quillController = QuillController(document: document, selection: const TextSelection.collapsed(offset: 0));
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

    // Only save if there is a title, content, or if it's an existing note
    if (title.isEmpty && _quillController.document.isEmpty() && widget.note == null) return;

    final noteProvider = Provider.of<NoteProvider>(context, listen: false);
    final now = DateTime.now();

    if (widget.note == null) {
      noteProvider.addNote(
        title,
        contentJson,
        _selectedCategory,
        colorValue: _selectedColorValue,
        createdAt: now,
      );
    } else {
      noteProvider.updateNote(Note(
        id: widget.note!.id,
        title: title,
        content: contentJson,
        category: _selectedCategory,
        createdAt: widget.note!.createdAt,
        modifiedAt: now,
        isArchived: widget.note!.isArchived,
        isPinned: widget.note!.isPinned,
        isLocked: widget.note!.isLocked,
        colorValue: _selectedColorValue,
      ));
    }
    if (mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _showColorPickerDialog() async {
    int? initialDialogValue = _selectedColorValue;
    List<Widget> actionButtons = [
      TextButton(
        onPressed: () => Navigator.of(context).pop(initialDialogValue),
        child: const Text('Cancel'),
      ),
    ];

    if (_selectedColorValue != null) {
      actionButtons.add(
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Clear Color'),
        ),
      );
    }

    int? newColorValue = await showDialog<int>(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            width: MediaQuery.of(dialogContext).size.width * 0.85,
            padding: const EdgeInsets.all(24),
            child: ZoomIn(
              duration: const Duration(milliseconds: 250),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Select Note Color',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    child: Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      alignment: WrapAlignment.center,
                      children: _defaultColors.map((color) {
                        return InkWell(
                          onTap: () => Navigator.of(dialogContext).pop(color.toARGB32() & 0xFFFFFFFF),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _selectedColorValue == (color.toARGB32() & 0xFFFFFFFF)
                                      ? Theme.of(dialogContext).colorScheme.onSurface
                                      : Colors.transparent,
                                  width: 2,
                                )),
                        ));
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: actionButtons,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (newColorValue != initialDialogValue) {
      setState(() {
        _selectedColorValue = newColorValue;
      });
    }
  }

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return 'N/A';
    return DateFormat.yMMMd().add_jm().format(dateTime);
  }

  void _unlockNote() async {
    final password = _passwordController.text;
    if (password.isEmpty) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password cannot be empty.')));
      return;
    }
    final isCorrect = await _secureStorageService.verifyPassword(password);
    if (isCorrect) {
      setState(() {
        _isTemporarilyUnlocked = true;
      });
    } else {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Incorrect password.')));
    }
  }

  Widget _buildLockedState(ThemeData theme) {
    return Column(
      children: [
        const Spacer(),
        const Icon(Icons.lock_outline, size: 64),
        const SizedBox(height: 16),
        Text('This note is locked.', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text('Enter your password to unlock.', style: theme.textTheme.bodyLarge),
        const SizedBox(height: 24),
        Padding(
            padding: const EdgeInsets.all(8.0),
            child: Material(
                elevation: 4.0,
                borderRadius: BorderRadius.circular(8.0),
                color: theme.cardColor,
                child: Padding(
                  padding: const EdgeInsets.only(left: 16.0, right: 8.0),
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
                        icon: const Icon(Icons.lock_open_outlined),
                        color: theme.colorScheme.primary,
                        tooltip: 'Unlock',
                        iconSize: 28.0,
                        onPressed: _unlockNote,
                      ),
                    ],
                  ),
                ))),
        const Spacer(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final noteProvider = Provider.of<NoteProvider>(context, listen: false);
    final availableCategories = noteProvider.categories.where((c) => c != 'All').toList();
    if (availableCategories.isEmpty && _selectedCategory == 'Personal') {
      availableCategories.add('Personal');
    }
    if (!availableCategories.contains(_selectedCategory) && availableCategories.isNotEmpty) {
      _selectedCategory = availableCategories.first;
    }

    final theme = Theme.of(context);
    final isEditable = !_isLocked || _isTemporarilyUnlocked;

    Color appBarColor = _selectedColorValue != null
        ? Color(_selectedColorValue!).withAlpha((0.7 * 255).toInt())
        : Theme.of(context).appBarTheme.backgroundColor ?? Theme.of(context).colorScheme.primary;
    Color? appBarForegroundColor =
        ThemeData.estimateBrightnessForColor(appBarColor) == Brightness.dark ? Colors.white : Colors.black;

    List<Widget> appBarActions = [
      IconButton(
        icon: const Icon(Icons.palette_outlined),
        onPressed: isEditable ? _showColorPickerDialog : null,
        tooltip: 'Change color',
      ),
      if (widget.note != null)
        IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: isEditable
              ? () {
                  Provider.of<NoteProvider>(context, listen: false).deleteNote(widget.note!.id);
                  if (mounted) Navigator.pop(context);
                }
              : null,
          tooltip: 'Delete note',
        ),
      IconButton(
        icon: const Icon(Icons.save_outlined),
        onPressed: isEditable ? _saveNote : null,
        tooltip: 'Save note',
      ),
    ];

    if (Platform.isWindows) {
      appBarActions = [
        Padding(
          padding: const EdgeInsets.only(right: 10.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: appBarActions,
          ),
        ),
      ];
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.note == null ? 'New Note' : 'Edit Note', style: TextStyle(color: appBarForegroundColor)),
        backgroundColor: appBarColor,
        elevation: _selectedColorValue != null ? 0 : null,
        iconTheme: IconThemeData(color: appBarForegroundColor),
        actionsIconTheme: IconThemeData(color: appBarForegroundColor),
        actions: appBarActions,
      ),
      body: FadeIn(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: !isEditable
              ? _buildLockedState(theme)
              : Column(
                  children: [
                    if (isEditable)
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(_showToolbar ? Icons.expand_less : Icons.expand_more),
                            tooltip: _showToolbar ? 'Hide toolbar' : 'Show toolbar',
                            onPressed: () {
                              setState(() {
                                _showToolbar = !_showToolbar;
                              });
                            },
                          ),
                          const SizedBox(width: 8),
                          Text('Formatting', style: Theme.of(context).textTheme.labelLarge),
                        ],
                      ),
                    if (isEditable)
                      AnimatedCrossFade(
                        firstChild: QuillSimpleToolbar(
                          controller: _quillController,
                          config: const QuillSimpleToolbarConfig(
                            showBackgroundColorButton: false,
                          ),
                        ),
                        secondChild: const SizedBox.shrink(),
                        crossFadeState: _showToolbar ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                        duration: const Duration(milliseconds: 200),
                      ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _titleController,
                      style: Theme.of(context).textTheme.headlineSmall,
                      decoration: InputDecoration(
                        hintText: 'Title',
                        border: InputBorder.none,
                        filled: false,
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      enabled: isEditable,
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: QuillEditor.basic(
                        controller: _quillController,
                        config: const QuillEditorConfig(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (availableCategories.isNotEmpty)
                      DropdownButtonFormField<String>(
                        initialValue: availableCategories.contains(_selectedCategory) ? _selectedCategory : availableCategories.first,
                        decoration: InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                        ),
                        items: availableCategories
                            .map((category) => DropdownMenuItem(
                                  value: category,
                                  child: Text(category),
                                ))
                            .toList(),
                        onChanged: isEditable
                            ? (value) {
                                if (value != null) {
                                  setState(() {
                                    _selectedCategory = value;
                                  });
                                }
                              }
                            : null,
                      ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            'Created: ${_formatDateTime(_createdAt)}',
                            style: Theme.of(context).textTheme.bodySmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    )
                  ],
                ),
        ),
      ),
    );
  }
}
