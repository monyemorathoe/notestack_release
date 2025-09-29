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
  final FocusNode _quillFocusNode = FocusNode(); // Focus node for QuillEditor
  final FocusNode _titleFocusNode = FocusNode(); // Focus node for title
  final SecureStorageService _secureStorageService = SecureStorageService();
  String _selectedCategory = 'Personal';
  int? _selectedColorValue;
  DateTime? _createdAt;
  bool _isLocked = false;
  bool _isTemporarilyUnlocked = false;
  bool _showToolbar = false; // Start collapsed by default
  bool _showCategoryDropdown = false;
  late bool _isEmpty;
  late bool _hasFocus;

  // Persist last applied style so formatting stays "sticky" across focus changes.
  Map<String, Attribute> _lastStyle = {};

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

    // initial state
    _isEmpty = _quillController.document.isEmpty();
    _hasFocus = _quillFocusNode.hasFocus;

    // listeners
    _quillController.addListener(_onQuillChanged);
    _quillFocusNode.addListener(_onFocusChange);
  }

  /// Called whenever the Quill controller changes (selection or document)
  void _onQuillChanged() {
    final newIsEmpty = _quillController.document.isEmpty();
    final newHasFocus = _quillFocusNode.hasFocus;

    // Update ephemeral UI state (hint/empty)
    if (newIsEmpty != _isEmpty || newHasFocus != _hasFocus) {
      if (mounted) {
        setState(() {
          _isEmpty = newIsEmpty;
          _hasFocus = newHasFocus;
        });
      }
    }

    // Capture the current selection style attributes and persist them.
    // This allows toolbar toggles to be remembered across focus changes.
    final selectionStyle = _quillController.getSelectionStyle().attributes;
    _lastStyle = Map<String, Attribute>.from(selectionStyle);
    if (mounted) setState(() {}); // Also triggers rebuild for word count
  }

  /// When editor gains focus, reapply the last persisted style so typing continues with it.
  void _onFocusChange() {
    final gainedFocus = _quillFocusNode.hasFocus;
    if (gainedFocus && _lastStyle.isNotEmpty) {
      _lastStyle.forEach((_, attr) {
        _quillController.formatSelection(attr);
      });
      // No direct setState here for _isEmpty as it might be premature.
      // _onQuillChanged will handle _isEmpty based on document content.
    }
    if (mounted) {
      setState(() {
        _hasFocus = gainedFocus;
        // If focus is gained, the placeholder should hide, so ensure _isEmpty reflects that if needed.
        // However, the primary trigger for placeholder is _hasFocus becoming true.
        // And _isEmpty should reflect the actual document state.
      });
    }
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
      selection: const TextSelection.collapsed(offset: 0),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _quillController.removeListener(_onQuillChanged);
    _quillFocusNode.removeListener(_onFocusChange);
    _quillController.dispose();
    _passwordController.dispose();
    _quillFocusNode.dispose();
    _titleFocusNode.dispose();
    super.dispose();
  }

  void _saveNote() {
    final title = _titleController.text.trim();
    final contentJson = jsonEncode(_quillController.document.toDelta().toJson());

    // Using document.isEmpty() for save condition, assuming it is sufficient.
    // If a more complex check (like _isDocumentEffectivelyEmpty) was needed, it should be used here.
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
        plainTextContent: _quillController.document.toPlainText(),
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

  int _getWordCount() {
    final plainText = _quillController.document.toPlainText().trim();
    if (plainText.isEmpty) {
      return 0;
    }
    // This regex splits by any sequence of whitespace characters.
    // .where((s) => s.isNotEmpty) filters out empty strings that might result from multiple spaces.
    return plainText.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).length;
  }

  @override
  Widget build(BuildContext context) {
    final noteProvider = Provider.of<NoteProvider>(context, listen: false);
    final availableCategories = noteProvider.categories.where((c) => c != 'All').toList();

    if (availableCategories.isEmpty) availableCategories.add('Personal');
    if (!availableCategories.contains(_selectedCategory)) {
      _selectedCategory = availableCategories.first;
    }

    final ThemeData theme = Theme.of(context);
    final bool isOverallDarkMode = theme.brightness == Brightness.dark;
    final isEditable = !_isLocked || _isTemporarilyUnlocked;

    Color appBarColor = _selectedColorValue != null
        ? Color(_selectedColorValue!).withAlpha((0.7 * 255).toInt())
        : theme.appBarTheme.backgroundColor ?? theme.colorScheme.primary;

    Color appBarForegroundColor;
    if (isOverallDarkMode) {
      appBarForegroundColor = Colors.white;
    } else {
      appBarForegroundColor = ThemeData.estimateBrightnessForColor(appBarColor) == Brightness.dark
          ? Colors.white
          : Colors.black;
    }
    
    TextStyle appBarTitleTextStyle = theme.appBarTheme.titleTextStyle?.copyWith(
      color: appBarForegroundColor
    ) ?? TextStyle(color: appBarForegroundColor);
    
    final int wordCount = _getWordCount(); // Calculate word count for the build
    final TextStyle? bottomTextStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurface.withAlpha((0.75 * 255).round()),
      fontWeight: FontWeight.w500 // MODIFIED
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.note == null ? 'New Note' : 'Edit Note',
          style: appBarTitleTextStyle,
        ),
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
              _buildToolbarCard(),
              _buildCategorySelector(availableCategories, isEditable),
              Expanded(
                child: Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onTap: () {
                            if (!_titleFocusNode.hasFocus) {
                              _titleFocusNode.requestFocus();
                            }
                          },
                          child: TextField(
                            controller: _titleController,
                            focusNode: _titleFocusNode,
                            decoration: const InputDecoration(
                              hintText: 'Title',
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.only(left: 16.0),
                            ),
                            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
                            textCapitalization: TextCapitalization.sentences,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Divider(height: 1),
                        const SizedBox(height: 12),
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTap: () {
                              if (!_quillFocusNode.hasFocus) {
                                _quillFocusNode.requestFocus();
                              }
                            },
                            child: Stack(
                              children: [
                                QuillEditor.basic(
                                  controller: _quillController,
                                  focusNode: _quillFocusNode,
                                  config: const QuillEditorConfig(
                                    padding: EdgeInsets.only(left: 16.0), // Editor's own content padding
                                  ),
                                ),
                                if (_isEmpty && !_hasFocus)
                                  Positioned.fill(
                                    child: Center( // Center the placeholder text
                                      child: Text(
                                        'click to start typing', // New placeholder text
                                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                          color: Theme.of(context).hintColor.withAlpha((0.7 * 255).round()),
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8.0, left: 4.0, right: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Created: ${_formatDateTime(_createdAt)}',
                      style: bottomTextStyle,
                    ),
                    Text(
                      'Words: $wordCount',
                      style: bottomTextStyle,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
