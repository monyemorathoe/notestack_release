import 'dart:async'; // Added for Timer
import 'dart:io'; // Added for Platform check
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import 'package:notestack/services/secure_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/note_provider.dart';
import '../screens/note_screen.dart';
import '../widgets/note_card.dart';
import 'archives_screen.dart';
import '../widgets/search_delegate.dart';
import 'settings_screen.dart';
import 'dart:ui' as ui;
import 'checklist_screen.dart';
import '../models/note.dart';

Future<void> _showLockedNotesInfoDialog(BuildContext context, {String? title, String? content}) async {
  return showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.85,
          padding: const EdgeInsets.all(24),
          child: ZoomIn(
            duration: const Duration(milliseconds: 250),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title ?? 'Cannot Delete Locked Notes', // Default title
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Text(
                  content ?? 'Please unlock the selected notes before deleting.', // Default content
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      child: const Text('OK'),
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  final SecureStorageService _secureStorageService = SecureStorageService();

  bool _isGridView = false;
  static const String _kPrefIsGridView = 'isGridView';
  bool _swipeToDeleteNotesEnabled = false;
  static const String _kSwipeToDeleteNotes = 'swipeToDeleteNotes'; // Key for SharedPreferences

  // State for inline unlock
  bool _isShowingInlineUnlock = false;
  final TextEditingController _inlinePasswordController = TextEditingController();
  bool _obscureInlinePassword = true;
  String _inlinePasswordHintText = 'Enter password';
  TextStyle? _inlinePasswordHintStyle;
  Timer? _hintErrorTimer;
  static const String _defaultHintText = 'Enter password';

  // Predefined Material colors for the picker (same as NoteScreen)
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
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _loadViewPreference();
    _loadSwipeToDeleteNotesPreference(); // Load swipe to delete preference
  }

  Future<void> _loadViewPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getBool(_kPrefIsGridView);
      if (stored != null && mounted) {
        setState(() {
          _isGridView = stored;
        });
      }
    } catch (e) {
      // ignore errors
    }
  }

  Future<void> _loadSwipeToDeleteNotesPreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _swipeToDeleteNotesEnabled = prefs.getBool(_kSwipeToDeleteNotes) ?? false;
      });
    }
  }

  Future<void> _saveViewPreference(bool isGrid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kPrefIsGridView, isGrid);
    } catch (e) {
      // ignore errors
    }
  }

  void _resetInlinePasswordHint({bool callSetState = true}) {
    _hintErrorTimer?.cancel();
    if (_inlinePasswordHintText != _defaultHintText || _inlinePasswordHintStyle != null) {
      if (callSetState && mounted) {
        setState(() {
          _inlinePasswordHintText = _defaultHintText;
          _inlinePasswordHintStyle = null; // Will fallback to theme default
        });
      } else {
        _inlinePasswordHintText = _defaultHintText;
        _inlinePasswordHintStyle = null;
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _inlinePasswordController.dispose();
    _hintErrorTimer?.cancel();
    super.dispose();
  }
  
  Future<void> _handleSubmittedPasswordForUnlock(NoteProvider noteProvider) async {
    final theme = Theme.of(context);
    final password = _inlinePasswordController.text;
    _hintErrorTimer?.cancel(); // Cancel any existing timer

    if (password.isEmpty) {
      if (mounted) {
        setState(() {
          _inlinePasswordHintText = 'Password required';
          _inlinePasswordHintStyle = TextStyle(color: theme.colorScheme.error);
        });
        _hintErrorTimer = Timer(const Duration(seconds: 3), () {
          _resetInlinePasswordHint();
        });
      }
      return;
    }
    final bool passwordVerified = await _secureStorageService.verifyPassword(password);
    if (!mounted) return;

    if (passwordVerified) {
      _resetInlinePasswordHint(callSetState: false); // Reset hint without immediate set state
      noteProvider.unlockSelectedNotes();
      _inlinePasswordController.clear();
      setState(() {
        _isShowingInlineUnlock = false;
        _obscureInlinePassword = true;
      });
      noteProvider.clearSelection();
    } else {
      _inlinePasswordController.clear(); // Clear field on wrong password
      setState(() {
        _inlinePasswordHintText = 'Wrong password';
        _inlinePasswordHintStyle = TextStyle(color: theme.colorScheme.error);
      });
      _hintErrorTimer = Timer(const Duration(seconds: 3), () {
        _resetInlinePasswordHint();
      });
    }
  }

  Widget _buildBottomSheetAction(
      BuildContext context, IconData icon, String label, VoidCallback? onPressed, {bool isEnabled = true, Color? iconColorOverride}) {
    final theme = Theme.of(context);
    final Color iconColor = isEnabled ? (iconColorOverride ?? theme.iconTheme.color ?? theme.colorScheme.onSurface) : theme.disabledColor;
    final Color labelColor = isEnabled ? (theme.textTheme.bodySmall?.color ?? theme.colorScheme.onSurface) : theme.disabledColor;

    return Expanded(
      child: InkWell(
        onTap: isEnabled ? onPressed : null,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: iconColor),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: labelColor),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showColorPickerForSelectedNotes(BuildContext context, NoteProvider noteProvider) async {
    int? currentCommonColorValue;
    bool multipleColors = false;
    bool canClearColor = false; 

    if (noteProvider.selectedNoteIds.isNotEmpty) {
      final firstNoteId = noteProvider.selectedNoteIds.first;
      try {
        final firstNote = noteProvider.allNotes.firstWhere((n) => n.id == firstNoteId);
        currentCommonColorValue = firstNote.colorValue;
        if (firstNote.colorValue != null) {
          canClearColor = true; 
        }

        for (String noteId in noteProvider.selectedNoteIds) {
          final note = noteProvider.allNotes.firstWhere((n) => n.id == noteId);
          if (note.colorValue != currentCommonColorValue) {
            multipleColors = true;
            currentCommonColorValue = null; 
          }
          if (note.colorValue != null) {
            canClearColor = true; 
          }
          if (multipleColors && canClearColor) break; 
        }
      } catch (e) {
        currentCommonColorValue = null;
      }
    }

    int? initialDialogValue = currentCommonColorValue;

    List<Widget> actionButtons = [
      TextButton(
        onPressed: () => Navigator.of(context).pop(initialDialogValue),
        child: const Text('Cancel'),
      ),
    ];

    if (canClearColor) {
      actionButtons.add(
        TextButton(
          onPressed: () => Navigator.of(context).pop(null), // Clear color
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
                    'Select Color for Notes',
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
                          onTap: () => Navigator.of(dialogContext).pop(color.toARGB32()),
                          borderRadius: BorderRadius.circular(20), // For ink splash
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: !multipleColors && currentCommonColorValue == color.toARGB32()
                                      ? Theme.of(dialogContext).colorScheme.onSurface
                                      : Colors.transparent,
                                  width: 2,
                                )),
                        )); // closes InkWell
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
        ); // closes Dialog
      }, // closes builder
    ); // closes showDialog

    if (newColorValue != initialDialogValue) {
      await noteProvider.setColorForSelectedNotes(newColorValue);
    }
  }

  void _showDeleteSelectedNotesConfirmationDialog(
      BuildContext parentContext,
      NoteProvider noteProvider) {
    final selectedCount = noteProvider.selectedNoteIds.length;

    showDialog(
      context: parentContext,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            width: MediaQuery.of(parentContext).size.width * 0.85,
            padding: const EdgeInsets.all(24),
            child: ZoomIn(
              duration: const Duration(milliseconds: 250),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    selectedCount > 1 ? 'Delete $selectedCount Notes?' : 'Delete Note?',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Are you sure you want to delete ${selectedCount > 1 ? "these $selectedCount notes" : "this note"}? This action cannot be undone.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      TextButton(
                        child: const Text('Cancel'),
                        onPressed: () {
                          Navigator.of(dialogContext).pop();
                        },
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: Colors.red),
                        child: const Text('Delete'),
                        onPressed: () async {
                          bool deleteSuccess = await noteProvider.deleteSelectedNotes();
                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop();
                          }
                          if (!deleteSuccess && parentContext.mounted) {
                            _showLockedNotesInfoDialog(parentContext);
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInlineUnlockBar(BuildContext context, NoteProvider noteProvider) {
    final theme = Theme.of(context);
    _inlinePasswordHintStyle ??= theme.inputDecorationTheme.hintStyle ?? TextStyle(color: theme.hintColor);

    return Container(
      height: 80.0, 
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Material(
              elevation: 2.0,
              borderRadius: BorderRadius.circular(12.0),
              shadowColor: Colors.black38,
              child: TextField(
                controller: _inlinePasswordController,
                obscureText: _obscureInlinePassword,
                decoration: InputDecoration(
                  hintText: _inlinePasswordHintText,
                  hintStyle: _inlinePasswordHintStyle,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.surface,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                autofocus: true,
                onChanged: (_) {
                  if (_inlinePasswordHintText != _defaultHintText) {
                    _resetInlinePasswordHint();
                  }
                },
                onSubmitted: (_) => _handleSubmittedPasswordForUnlock(noteProvider),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Cancel',
            splashRadius: 24.0,
            onPressed: () {
              _inlinePasswordController.clear();
              _resetInlinePasswordHint();
              if (mounted) {
                 setState(() {
                    _isShowingInlineUnlock = false;
                    _obscureInlinePassword = true;
                 });
              }
            },
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.lock_open),
            tooltip: 'Unlock',
            color: theme.colorScheme.primary,
            splashRadius: 24.0,
            onPressed: () => _handleSubmittedPasswordForUnlock(noteProvider),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionBottomSheet(
      BuildContext context,
      NoteProvider noteProvider,
      bool showUnpinAction,
      bool showUnlockAction) {
    bool isAnyNoteLocked = false;
    if (noteProvider.selectedNoteIds.isNotEmpty) {
      for (String noteId in noteProvider.selectedNoteIds) {
        try {
          final note = noteProvider.allNotes.firstWhere((n) => n.id == noteId);
          if (note.isLocked) {
            isAnyNoteLocked = true;
            break;
          }
        } catch (e) {
          // Note not found, ignore for this check
        }
      }
    }

    return Container(
      height: 80.0,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildBottomSheetAction(
            context,
            Icons.palette_outlined,
            'Color',
            isAnyNoteLocked 
              ? null // Simply disable if any note is locked
              : () => _showColorPickerForSelectedNotes(context, noteProvider),
            isEnabled: !isAnyNoteLocked,
          ),
          _buildBottomSheetAction(
            context,
            Icons.archive_outlined,
            'Archive',
            () => noteProvider.archiveSelectedNotes(),
          ),
          _buildBottomSheetAction(
            context,
            Icons.delete_outline,
            'Delete',
            () => _showDeleteSelectedNotesConfirmationDialog(context, noteProvider),
          ),
          _buildBottomSheetAction(
            context,
            showUnlockAction ? Icons.lock_open : Icons.lock_outline,
            showUnlockAction ? 'Unlock' : 'Lock',
            () async {
              _resetInlinePasswordHint(); 
              if (showUnlockAction) {
                final bool isPasswordGloballySet = await _secureStorageService.isPasswordSet();
                if (!mounted) return;
                if (isPasswordGloballySet) {
                  setState(() {
                    _isShowingInlineUnlock = true;
                    _obscureInlinePassword = true;
                  });
                } else {
                  noteProvider.unlockSelectedNotes();
                }
              } else {
                final bool isPasswordGloballySet = await _secureStorageService.isPasswordSet();
                if (!mounted) return;
                if (!isPasswordGloballySet) {
                  showDialog(
                    context: context,
                    builder: (BuildContext dialogContext) {
                      return Dialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        child: Container(
                          width: MediaQuery.of(context).size.width * 0.85,
                          padding: const EdgeInsets.all(24),
                          child: ZoomIn(
                            duration: const Duration(milliseconds: 250),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('Set Password to Lock Notes',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 16),
                                const Text(
                                  'To use the lock feature, you first need to set an application password',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey),
                                ),
                                const SizedBox(height: 24),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton(
                                      child: const Text('Cancel'),
                                      onPressed: () {
                                        Navigator.of(dialogContext).pop();
                                      },
                                    ),
                                    const SizedBox(width: 8),
                                    FilledButton(
                                      onPressed: () {
                                        Navigator.of(dialogContext).pop();
                                        if (!mounted) return;
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (_) => const SettingsScreen()),
                                        );
                                      },
                                      child: const Text('Set Password'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                } else {
                  noteProvider.lockSelectedNotes();
                }
              }
            },
          ),
          _buildBottomSheetAction(
            context,
            showUnpinAction ? Icons.push_pin : Icons.push_pin_outlined,
            showUnpinAction ? 'Unpin' : 'Pin',
            () {
              if (showUnpinAction) {
                noteProvider.unpinSelectedNotes();
              } else {
                noteProvider.pinSelectedNotes();
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NoteProvider>(
      builder: (context, noteProvider, child) {
        final filteredNotes = noteProvider.getFilteredNotes();
        final screenWidth = MediaQuery.of(context).size.width;
        final categoryCount = noteProvider.categories.length;

        final double chipWidth;
        if (categoryCount > 0) {
          chipWidth = (screenWidth - 16 - (categoryCount - 1) * 8) / categoryCount;
        } else {
          chipWidth = 80.0;
        }

        final bool isSelectionMode = noteProvider.isSelectionMode;
        final int selectedCount = noteProvider.selectedNoteIds.length;

        bool showUnpinAction = false;
        if (isSelectionMode && selectedCount > 0) {
          showUnpinAction = noteProvider.selectedNoteIds.every((id) {
            try {
              final note = noteProvider.allNotes.firstWhere((note) => note.id == id);
              return note.isPinned;
            } catch (e) {
              return false;
            }
          });
        }

        bool showUnlockAction = false;
        if (isSelectionMode && selectedCount > 0) {
          showUnlockAction = noteProvider.selectedNoteIds.every((id) {
            try {
              final note = noteProvider.allNotes.firstWhere((note) => note.id == id);
              return note.isLocked;
            } catch (e) {
              return false;
            }
          });
        }
        
        List<Widget> normalModeActions = [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search',
            onPressed: () {
              showSearch(
                context: context,
                delegate: NotesSearchDelegate(),
              );
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            splashRadius: 20.0,
            offset: const Offset(0, 40),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 4,
            onSelected: (String result) async { 
              if (result == 'checklist') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ChecklistScreen()),
                );
              } else if (result == 'archived') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ArchivesScreen()),
                );
              } else if (result == 'settings') {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
                _loadSwipeToDeleteNotesPreference(); 
                _loadViewPreference(); 
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'checklist',
                child: Row(
                  children: <Widget>[
                    Icon(Icons.checklist_rtl_outlined, color: Theme.of(context).iconTheme.color?.withAlpha(179)),
                    const SizedBox(width: 12),
                    const Text('Checklist', style: TextStyle(fontSize: 16.0)),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'archived',
                child: Row(
                  children: <Widget>[
                    Icon(Icons.archive_outlined, color: Theme.of(context).iconTheme.color?.withAlpha(179)),
                    const SizedBox(width: 12),
                    const Text('Archived', style: TextStyle(fontSize: 16.0)),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'settings',
                child: Row(
                  children: <Widget>[
                    Icon(Icons.settings_outlined, color: Theme.of(context).iconTheme.color?.withAlpha(179)),
                    const SizedBox(width: 12),
                    const Text('Settings', style: TextStyle(fontSize: 16.0)),
                  ],
                ),
              ),
            ],
          ),
        ];

        List<Widget> selectionModeActions = [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share',
            onPressed: () async {
              if (noteProvider.selectedNoteIds.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No notes selected to share.')),
                );
                return;
              }
              List<Note> selectedNotes = [];
              int lockedCount = 0;
              for (String id in noteProvider.selectedNoteIds) {
                try {
                  final note = noteProvider.allNotes.firstWhere((n) => n.id == id);
                  selectedNotes.add(note);
                  if (note.isLocked) {
                    lockedCount++;
                  }
                } catch (e) {/* Note not found, ignore */}
              }
              if (lockedCount > 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Unlock $lockedCount note${lockedCount > 1 ? 's' : ''} before sharing.')),
                );
                return;
              }
              List<Note> notesToShare = selectedNotes.where((note) => !note.isLocked).toList();
              if (notesToShare.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Selected notes are locked or could not be found.')),
                );
                return;
              }
              String shareText = '';
              String subjectText = 'NoteStack Note';
              if (notesToShare.length == 1) {
                final note = notesToShare.first;
                shareText = "Title: ${note.title}\nContent: ${note.content}";
                subjectText = note.title.isNotEmpty ? note.title : 'NoteStack Note';
              } else {
                shareText = notesToShare.map((note) {
                  return "Title: ${note.title.isNotEmpty ? note.title : 'Untitled Note'}\nContent: ${note.content}\n\n--------------------\n";
                }).join("");
                subjectText = 'Multiple NoteStack Notes';
              }
              await SharePlus.instance.share(ShareParams(text: shareText, subject: subjectText));
              noteProvider.clearSelection();
            },
          ),
        ];

        if (Platform.isWindows) {
          normalModeActions = [
            Padding(
              padding: const EdgeInsets.only(right: 10.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: normalModeActions,
              ),
            ),
          ];
          selectionModeActions = [
            Padding(
              padding: const EdgeInsets.only(right: 10.0),
              child: selectionModeActions.first, // Assuming Share is the only icon
            ),
          ];
        }

        return Scaffold(
          appBar: AppBar(
            leading: isSelectionMode
                ? IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Cancel selection',
              onPressed: () {
                noteProvider.clearSelection();
                if (_isShowingInlineUnlock) {
                  _inlinePasswordController.clear();
                  _resetInlinePasswordHint();
                  if (mounted) {
                    setState(() {
                      _isShowingInlineUnlock = false;
                      _obscureInlinePassword = true;
                    });
                  }
                }
              },
            )
                : IconButton(
              icon: Icon(_isGridView ? Icons.view_list_outlined : Icons.grid_view_outlined),
              tooltip: 'Toggle View',
              onPressed: () {
                setState(() {
                  _isGridView = !_isGridView;
                  _saveViewPreference(_isGridView);
                });
              },
            ),
            title: Text(
              isSelectionMode ? '$selectedCount selected' : 'NoteStack',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            centerTitle: true,
            actions: isSelectionMode
                ? selectionModeActions
                : normalModeActions,
          ),
          body: Stack(
            children: [
              Column(
                children: [
                  if (noteProvider.categories.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Wrap(
                        spacing: 8.0,
                        runSpacing: 8.0,
                        alignment: WrapAlignment.start,
                        children: noteProvider.categories.map((category) {
                          final isSelected = noteProvider.selectedCategory == category;
                          final clampedChipWidth = chipWidth.clamp(80.0, 100.0);
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: clampedChipWidth,
                                height: 32,
                                child: ChoiceChip(
                                  label: Center(
                                    child: Text(
                                      category,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  selected: isSelected,
                                  onSelected: isSelectionMode
                                      ? null  
                                      : (selected) {
                                    if (selected) {
                                      noteProvider.setCategory(category);
                                    }
                                  },
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  showCheckmark: false,
                                  selectedColor: Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withAlpha(51),
                                  labelPadding: EdgeInsets.zero,
                                  materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                height: isSelected ? 3.0 : 0.0,
                                width: isSelected ? clampedChipWidth * 0.7 : 0.0,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.primary
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(1.5),
                                ),
                                margin: const EdgeInsets.only(top: 3.0),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  Expanded(
                    child: filteredNotes.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                Icon(
                                  Icons.note_add_outlined,
                                  size: 64,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No notes yet. Add one!',
                                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        : _isGridView
                            ? (Platform.isWindows || Platform.isMacOS || Platform.isLinux
                                ? LayoutBuilder(
                                    builder: (context, constraints) {
                                      // Calculate available width/height for cards
                                      final double gridPadding = 8.0;
                                      final double gridSpacing = 8.0;
                                      final int columns = 2;
                                      final int rows = 2;
                                      final double availableWidth = constraints.maxWidth - (gridPadding * 2) - gridSpacing;
                                      final double availableHeight = constraints.maxHeight - (gridPadding * 2) - gridSpacing;
                                      final double cardWidth = availableWidth / columns;
                                      final double cardHeight = availableHeight / rows;
                                      final double aspectRatio = cardWidth / cardHeight;
                                      return GridView.builder(
                                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: columns,
                                          childAspectRatio: aspectRatio,
                                          crossAxisSpacing: gridSpacing,
                                          mainAxisSpacing: gridSpacing,
                                        ),
                                        padding: EdgeInsets.fromLTRB(
                                          gridPadding,
                                          gridPadding,
                                          gridPadding,
                                          (isSelectionMode && selectedCount > 0) || _isShowingInlineUnlock ? 88.0 : gridPadding,
                                        ),
                                        itemCount: filteredNotes.length,
                                        itemBuilder: (context, index) {
                                          final note = filteredNotes[index];
                                          return NoteCard(note: note, isGridView: true);
                                        },
                                      );
                                    },
                                  )
                                : GridView.builder(
                                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2, // Mobile/tablet: original grid
                                      childAspectRatio: 0.75,
                                      crossAxisSpacing: 8.0,
                                      mainAxisSpacing: 8.0,
                                    ),
                                    padding: EdgeInsets.fromLTRB(8.0, 8.0, 8.0, (isSelectionMode && selectedCount > 0) || _isShowingInlineUnlock ? 88.0 : 8.0),
                                    itemCount: filteredNotes.length,
                                    itemBuilder: (context, index) {
                                      final note = filteredNotes[index];
                                      return NoteCard(note: note, isGridView: true);
                                    }))
                            : ListView.builder(
                                padding: EdgeInsets.only(bottom: (isSelectionMode && selectedCount > 0) || _isShowingInlineUnlock ? 88.0 : 8.0), 
                                itemCount: filteredNotes.length,
                                itemBuilder: (context, index) {
                                  final note = filteredNotes[index];
                                  Widget noteCard = NoteCard(note: note);

                                  if (!_isGridView && _swipeToDeleteNotesEnabled) {
                                    return Dismissible(
                                      key: ValueKey(note.id),
                                      background: Container(
                                        color: Theme.of(context).colorScheme.errorContainer,
                                        alignment: Alignment.centerRight,
                                        padding: const EdgeInsets.only(right: 20.0),
                                        child: Icon(Icons.delete_sweep_outlined, color: Theme.of(context).colorScheme.onErrorContainer),
                                      ),
                                      direction: DismissDirection.endToStart,
                                      confirmDismiss: (direction) async {
                                        if (note.isLocked) {
                                          _showLockedNotesInfoDialog(context, 
                                            title: 'Cannot Delete Locked Note',
                                            content: 'Please unlock this note before deleting.'
                                          );
                                          return false; // Do not dismiss if locked
                                        }
                                        return true; // Allow dismiss if not locked
                                      },
                                      onDismissed: (direction) {
                                        final noteTitle = note.title.isNotEmpty ? note.title : "Untitled note";
                                        noteProvider.deleteNote(note.id, isSwipeDelete: true);
                                        ScaffoldMessenger.of(context).removeCurrentSnackBar();
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('"$noteTitle" deleted'),
                                            action: SnackBarAction(
                                              label: 'Undo',
                                              onPressed: () {
                                                noteProvider.undoDeleteNote();
                                              },
                                            ),
                                          ),
                                        );
                                      },
                                      child: noteCard,
                                    );
                                  }
                                  return noteCard;
                                }),
                  ),
                ],
              ),
              if (isSelectionMode && selectedCount > 0)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: _isShowingInlineUnlock
                      ? _buildInlineUnlockBar(context, noteProvider)
                      : _buildSelectionBottomSheet(
                          context,
                          noteProvider,
                          showUnpinAction,
                          showUnlockAction,
                        ),
                ),
            ],
          ),
          floatingActionButton: !isSelectionMode && !_isShowingInlineUnlock
              ? _AnimatedFabMenu(
                  onNewNote: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const NoteScreen()),
                    );
                  },
                  onChecklist: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ChecklistScreen()),
                    );
                  },
                )
              : null,
        );
      },
    );
  }
}

class _AnimatedFabMenu extends StatefulWidget {
  final VoidCallback onNewNote;
  final VoidCallback onChecklist;

  const _AnimatedFabMenu({
    required this.onNewNote,
    required this.onChecklist,
  });

  @override
  State<_AnimatedFabMenu> createState() => _AnimatedFabMenuState();
}

class _AnimatedFabMenuState extends State<_AnimatedFabMenu>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _button1Animation;
  late Animation<double> _button2Animation;
  bool _isOpen = false;
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _button1Animation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
    );
    _button2Animation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _overlayEntry?.remove();
    super.dispose();
  }

  void _toggleMenu() {
    if (_isOpen) {
      _closeMenu();
    } else {
      _showMenu();
    }
  }

  void _showMenu() {
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
    _controller.forward();
    setState(() {
      _isOpen = true;
    });
  }

  void _closeMenu() {
    _controller.reverse().then((_) {
      _overlayEntry?.remove();
      _overlayEntry = null;
      if (mounted) {
        setState(() {
          _isOpen = false;
        });
      }
    });
  }

  OverlayEntry _createOverlayEntry() {
    return OverlayEntry(
      builder: (context) => AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _closeMenu,
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                    child: Container(
                      color: Colors.black.withAlpha(51),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 80,
                right: 16,
                child: ScaleTransition(
                  scale: _button2Animation,
                  child: FadeTransition(
                    opacity: _button2Animation,
                    child: FloatingActionButton.extended(
                      heroTag: 'fab_checklist',
                      onPressed: () {
                        widget.onChecklist();
                        _closeMenu();
                      },
                      icon: const Icon(Icons.checklist_rtl_outlined),
                      label: const Text('Checklist'),
                      backgroundColor: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 140,
                right: 16,
                child: ScaleTransition(
                  scale: _button1Animation,
                  child: FadeTransition(
                    opacity: _button1Animation,
                    child: FloatingActionButton.extended(
                      heroTag: 'fab_new_note',
                      onPressed: () {
                        widget.onNewNote();
                        _closeMenu();
                      },
                      icon: const Icon(Icons.note_add_outlined),
                      label: const Text('New Note'),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: null,
      onPressed: _toggleMenu,
      child: AnimatedRotation(
        turns: _isOpen ? 0.125 : 0.0,
        duration: const Duration(milliseconds: 300),
        child: const Icon(Icons.add),
      ),
    );
  }
}
