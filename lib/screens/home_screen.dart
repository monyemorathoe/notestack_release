import 'dart:async';
import 'dart:io';
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
                  title ?? 'Cannot Perform Action on Locked Note',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Text(
                  content ?? 'Please unlock this note before performing this action.',
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
  bool _swipeToArchiveNotesEnabled = false;
  static const String _kSwipeToDeleteNotes = 'swipeToDeleteNotes';
  static const String _kSwipeToArchiveNotes = 'swipeToArchiveNotes';

  // State for inline unlock
  bool _isShowingInlineUnlock = false;
  final TextEditingController _inlinePasswordController = TextEditingController();
  bool _obscureInlinePassword = true;
  String _inlinePasswordHintText = 'Enter password';
  TextStyle? _inlinePasswordHintStyle;
  Timer? _hintErrorTimer;
  static const String _defaultHintText = 'Enter password';

  // State for bulk action loading
  bool _isPerformingBulkAction = false;

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
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _initializePreferences();
  }

  Future<void> _initializePreferences() async {
    await _loadViewPreference();
    await _loadSwipePreferences();
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
      // Ignore errors
    }
  }

  Future<void> _loadSwipePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _swipeToDeleteNotesEnabled = prefs.getBool(_kSwipeToDeleteNotes) ?? false;
          _swipeToArchiveNotesEnabled = prefs.getBool(_kSwipeToArchiveNotes) ?? false;
        });
      }
    } catch (e) {
      // Ignore errors
    }
  }

  Future<void> _saveViewPreference(bool isGrid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kPrefIsGridView, isGrid);
    } catch (e) {
      // Ignore errors
    }
  }

  void _resetInlinePasswordHint({bool callSetState = true}) {
    _hintErrorTimer?.cancel();
    if (_inlinePasswordHintText != _defaultHintText || _inlinePasswordHintStyle != null) {
      if (callSetState && mounted) {
        setState(() {
          _inlinePasswordHintText = _defaultHintText;
          _inlinePasswordHintStyle = null;
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
    // Capture context and theme before async operations
    final currentContext = context;
    final theme = Theme.of(currentContext);
    final password = _inlinePasswordController.text;

    _hintErrorTimer?.cancel();

    if (password.isEmpty) {
      if (mounted) {
        setState(() {
          _inlinePasswordHintText = 'Password required';
          _inlinePasswordHintStyle = TextStyle(color: theme.colorScheme.error);
        });
        _hintErrorTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) {
            _resetInlinePasswordHint();
          }
        });
      }
      return;
    }

    final bool passwordVerified = await _secureStorageService.verifyPassword(password);

    if (!mounted) return;

    if (passwordVerified) {
      _resetInlinePasswordHint(callSetState: false);
      if (mounted) {
        setState(() {
          _isPerformingBulkAction = true;
        });
      }

      try {
        await noteProvider.unlockSelectedNotes();
        _inlinePasswordController.clear();

        if (mounted) {
          setState(() {
            _isShowingInlineUnlock = false;
            _obscureInlinePassword = true;
          });
        }

        // Use the stored context for provider operations
        if (currentContext.mounted) {
          final provider = Provider.of<NoteProvider>(currentContext, listen: false);
          provider.clearSelection();
        }
      } finally {
        if (mounted) {
          setState(() {
            _isPerformingBulkAction = false;
          });
        }
      }
    } else {
      _inlinePasswordController.clear();
      if (mounted) {
        setState(() {
          _inlinePasswordHintText = 'Wrong password';
          _inlinePasswordHintStyle = TextStyle(color: theme.colorScheme.error);
        });
        _hintErrorTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) {
            _resetInlinePasswordHint();
          }
        });
      }
    }
  }

  Widget _buildBottomSheetAction(
      BuildContext context,
      IconData icon,
      String label,
      VoidCallback? onPressed,
      {bool isEnabled = true,
        Color? iconColorOverride}
      ) {
    final theme = Theme.of(context);
    final Color iconColor = isEnabled
        ? (iconColorOverride ?? theme.iconTheme.color ?? theme.colorScheme.onSurface)
        : theme.disabledColor;
    final Color labelColor = isEnabled
        ? (theme.textTheme.bodySmall?.color ?? theme.colorScheme.onSurface)
        : theme.disabledColor;

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
    if (_isPerformingBulkAction) return;

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

    final int? initialDialogValue = currentCommonColorValue;

    final List<Widget> actionButtons = [
      TextButton(
        onPressed: () => Navigator.of(context).pop(initialDialogValue),
        child: const Text('Cancel'),
      ),
    ];

    if (canClearColor) {
      actionButtons.add(
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Clear Color'),
        ),
      );
    }

    final int? newColorValue = await showDialog<int>(
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
                          borderRadius: BorderRadius.circular(20),
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
                              ),
                            ),
                          ),
                        );
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
      if (!mounted) return;
      setState(() {
        _isPerformingBulkAction = true;
      });
      try {
        await noteProvider.setColorForSelectedNotes(newColorValue);
      } finally {
        if (mounted) {
          setState(() {
            _isPerformingBulkAction = false;
          });
        }
      }
    }
  }

  void _showDeleteSelectedNotesConfirmationDialog(
      BuildContext parentContext,
      NoteProvider noteProvider,
      VoidCallback onProcessStart,
      VoidCallback onProcessEnd) {
    if (_isPerformingBulkAction) return;
    final selectedCount = noteProvider.selectedNoteIds.length;

    showDialog(
      context: parentContext,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        bool isDeletingInDialog = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
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
                            onPressed: isDeletingInDialog ? null : () {
                              Navigator.of(dialogContext).pop();
                            },
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            style: FilledButton.styleFrom(backgroundColor: Colors.red),
                            onPressed: isDeletingInDialog ? null : () async {
                              setDialogState(() {
                                isDeletingInDialog = true;
                              });
                              onProcessStart();
                              bool deleteSuccess = false;
                              try {
                                deleteSuccess = await noteProvider.deleteSelectedNotes();
                              } finally {
                                if (dialogContext.mounted) {
                                  Navigator.of(dialogContext).pop();
                                }
                                if (!deleteSuccess && parentContext.mounted) {
                                  _showLockedNotesInfoDialog(parentContext,
                                    title: 'Cannot Delete Locked Notes',
                                    content: 'Please unlock the selected notes before deleting.',
                                  );
                                }
                                onProcessEnd();
                              }
                            },
                            child: isDeletingInDialog
                                ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                                : const Text('Delete'),
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
      child: _isPerformingBulkAction
          ? const Center(child: CircularProgressIndicator())
          : Row(
        children: [
          Expanded(
            child: Material(
              elevation: 2.0,
              borderRadius: BorderRadius.circular(12.0),
              shadowColor: Colors.black38,
              child: Theme(
                data: Theme.of(context).copyWith(
                  inputDecorationTheme: InputDecorationTheme(
                    filled: true,
                    fillColor: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF323232)
                        : theme.colorScheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    hoverColor: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF323232)
                        : theme.colorScheme.surface,
                  ),
                ),
                child: TextField(
                  controller: _inlinePasswordController,
                  obscureText: _obscureInlinePassword,
                  decoration: InputDecoration(
                    hintText: _inlinePasswordHintText,
                    hintStyle: _inlinePasswordHintStyle,
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
      child: _isPerformingBulkAction
          ? const Center(child: CircularProgressIndicator())
          : Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildBottomSheetAction(
            context,
            Icons.palette_outlined,
            'Color',
            isAnyNoteLocked || _isPerformingBulkAction
                ? null
                : () => _showColorPickerForSelectedNotes(context, noteProvider),
            isEnabled: !isAnyNoteLocked && !_isPerformingBulkAction,
          ),
          _buildBottomSheetAction(
            context,
            Icons.archive_outlined,
            'Archive',
            _isPerformingBulkAction ? null : () => _handleArchiveSelectedNotes(noteProvider),
            isEnabled: !_isPerformingBulkAction,
          ),
          _buildBottomSheetAction(
            context,
            Icons.delete_outline,
            'Delete',
            _isPerformingBulkAction
                ? null
                : () => _showDeleteSelectedNotesConfirmationDialog(context, noteProvider, () {
              setState(() {
                _isPerformingBulkAction = true;
              });
            }, () {
              setState(() {
                _isPerformingBulkAction = false;
              });
            }),
            isEnabled: !_isPerformingBulkAction,
          ),
          _buildBottomSheetAction(
            context,
            showUnlockAction ? Icons.lock_open : Icons.lock_outline,
            showUnlockAction ? 'Unlock' : 'Lock',
            _isPerformingBulkAction ? null : () => _handleLockUnlockAction(
              noteProvider,
              showUnlockAction,
            ),
            isEnabled: !_isPerformingBulkAction,
          ),
          _buildBottomSheetAction(
            context,
            showUnpinAction ? Icons.push_pin : Icons.push_pin_outlined,
            showUnpinAction ? 'Unpin' : 'Pin',
            _isPerformingBulkAction ? null : () => _handlePinUnpinAction(
              noteProvider,
              showUnpinAction,
            ),
            isEnabled: !_isPerformingBulkAction,
          ),
        ],
      ),
    );
  }

  Future<void> _handleArchiveSelectedNotes(NoteProvider noteProvider) async {
    if (!mounted) return;
    setState(() {
      _isPerformingBulkAction = true;
    });
    try {
      await noteProvider.archiveSelectedNotes();
    } finally {
      if (mounted) {
        setState(() {
          _isPerformingBulkAction = false;
        });
      }
    }
  }

  Future<void> _handleLockUnlockAction(NoteProvider noteProvider, bool showUnlockAction) async {
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
        await _performBulkAction(() => noteProvider.unlockSelectedNotes());
      }
    } else {
      final bool isPasswordGloballySet = await _secureStorageService.isPasswordSet();
      if (!mounted) return;

      if (!isPasswordGloballySet) {
        _showSetPasswordDialog();
      } else {
        await _performBulkAction(() => noteProvider.lockSelectedNotes());
      }
    }
  }

  Future<void> _handlePinUnpinAction(NoteProvider noteProvider, bool showUnpinAction) async {
    if (!mounted) return;
    await _performBulkAction(() {
      return showUnpinAction
          ? noteProvider.unpinSelectedNotes()
          : noteProvider.pinSelectedNotes();
    });
  }

  Future<void> _performBulkAction(Future<void> Function() action) async {
    if (!mounted) return;
    setState(() {
      _isPerformingBulkAction = true;
    });
    try {
      await action();
    } finally {
      if (mounted) {
        setState(() {
          _isPerformingBulkAction = false;
        });
      }
    }
  }

  void _showSetPasswordDialog() {
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
                  const Text(
                    'Set Password to Lock Notes',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
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
  }

  List<Widget> _buildNormalModeActions() {
    final actions = [
      IconButton(
        icon: const Icon(Icons.search),
        tooltip: 'Search',
        onPressed: () {
          showSearch(
            context: context,
            delegate: NotesSearchDelegate(isGridView: _isGridView),
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
          switch (result) {
            case 'checklist':
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ChecklistScreen()),
              );
            case 'archived':
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ArchivesScreen()),
              );
            case 'settings':
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
              await _loadSwipePreferences();
              await _loadViewPreference();
          }
        },
        itemBuilder: (BuildContext context) => const <PopupMenuEntry<String>>[
          PopupMenuItem<String>(
            value: 'checklist',
            child: Row(
              children: <Widget>[
                Icon(Icons.checklist_rtl_outlined),
                SizedBox(width: 12),
                Text('Checklist', style: TextStyle(fontSize: 16.0)),
              ],
            ),
          ),
          PopupMenuItem<String>(
            value: 'archived',
            child: Row(
              children: <Widget>[
                Icon(Icons.archive_outlined),
                SizedBox(width: 12),
                Text('Archived', style: TextStyle(fontSize: 16.0)),
              ],
            ),
          ),
          PopupMenuItem<String>(
            value: 'settings',
            child: Row(
              children: <Widget>[
                Icon(Icons.settings_outlined),
                SizedBox(width: 12),
                Text('Settings', style: TextStyle(fontSize: 16.0)),
              ],
            ),
          ),
        ],
      ),
    ];

    if (Platform.isWindows) {
      return [
        Padding(
          padding: const EdgeInsets.only(right: 10.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: actions,
          ),
        ),
      ];
    }

    return actions;
  }

  List<Widget> _buildSelectionModeActions(NoteProvider noteProvider) {
    final actions = [
      IconButton(
        icon: const Icon(Icons.share),
        tooltip: 'Share',
        onPressed: () => _handleShareSelectedNotes(noteProvider),
      ),
    ];

    if (Platform.isWindows) {
      return [
        Padding(
          padding: const EdgeInsets.only(right: 10.0),
          child: actions.first,
        ),
      ];
    }

    return actions;
  }

  Future<void> _handleShareSelectedNotes(NoteProvider noteProvider) async {
    if (noteProvider.selectedNoteIds.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No notes selected to share.')),
        );
      }
      return;
    }

    final List<Note> selectedNotes = [];
    int lockedCount = 0;

    for (String id in noteProvider.selectedNoteIds) {
      try {
        final note = noteProvider.allNotes.firstWhere((n) => n.id == id);
        selectedNotes.add(note);
        if (note.isLocked) {
          lockedCount++;
        }
      } catch (e) {
        // Note not found, ignore
      }
    }

    if (lockedCount > 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unlock $lockedCount note${lockedCount > 1 ? 's' : ''} before sharing.')),
        );
      }
      return;
    }

    final List<Note> notesToShare = selectedNotes.where((note) => !note.isLocked).toList();
    if (notesToShare.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selected notes are locked or could not be found.')),
        );
      }
      return;
    }

    final String shareText = _buildShareText(notesToShare);
    final String subjectText = notesToShare.length == 1
        ? (notesToShare.first.title.isNotEmpty ? notesToShare.first.title : 'NoteStack Note')
        : 'Multiple NoteStack Notes';

    await SharePlus.instance.share(ShareParams(text: shareText, subject: subjectText));
    noteProvider.clearSelection();
  }

  String _buildShareText(List<Note> notes) {
    if (notes.length == 1) {
      final note = notes.first;
      return "Title: ${note.title}\nContent: ${note.plainTextContent}";
    } else {
      return notes.map((note) {
        return "Title: ${note.title.isNotEmpty ? note.title : 'Untitled Note'}\nContent: ${note.plainTextContent}\n\n--------------------\n";
      }).join("");
    }
  }

  Widget _buildCategoryChips(NoteProvider noteProvider, double chipWidth, bool isSelectionMode) {
    return Padding(
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
                  onSelected: isSelectionMode || _isPerformingBulkAction
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
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
    );
  }

  Widget _buildNotesGrid(List<Note> filteredNotes, bool isSelectionMode, int selectedCount) {
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      return LayoutBuilder(
        builder: (context, constraints) {
          const double gridPadding = 8.0;
          const double gridSpacing = 8.0;
          const int columns = 2;
          const int rows = 2;
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
      );
    } else {
      return GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.75,
          crossAxisSpacing: 8.0,
          mainAxisSpacing: 8.0,
        ),
        padding: EdgeInsets.fromLTRB(
            8.0,
            8.0,
            8.0,
            (isSelectionMode && selectedCount > 0) || _isShowingInlineUnlock ? 88.0 : 8.0
        ),
        itemCount: filteredNotes.length,
        itemBuilder: (context, index) {
          final note = filteredNotes[index];
          return NoteCard(note: note, isGridView: true);
        },
      );
    }
  }

  Widget _buildNotesList(List<Note> filteredNotes, NoteProvider noteProvider) {
    return ListView.builder(
      padding: EdgeInsets.only(
          bottom: (_isSelectionMode(noteProvider) && noteProvider.selectedNoteIds.isNotEmpty) || _isShowingInlineUnlock
              ? 88.0
              : 8.0
      ),
      itemCount: filteredNotes.length,
      itemBuilder: (context, index) {
        final note = filteredNotes[index];
        final noteCardListItem = NoteCard(note: note);

        if (!_isGridView && (_swipeToDeleteNotesEnabled || _swipeToArchiveNotesEnabled)) {
          return _buildDismissibleNoteCard(note, noteCardListItem, noteProvider);
        }

        return noteCardListItem;
      },
    );
  }

  Widget _buildDismissibleNoteCard(Note note, Widget noteCardListItem, NoteProvider noteProvider) {
    DismissDirection direction = DismissDirection.none;
    Widget? background;
    Widget? secondaryBackground;

    if (_swipeToDeleteNotesEnabled && _swipeToArchiveNotesEnabled) {
      direction = DismissDirection.horizontal;
      background = Container(
        color: Theme.of(context).colorScheme.primaryContainer,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20.0),
        child: Icon(Icons.archive_outlined, color: Theme.of(context).colorScheme.onPrimaryContainer),
      );
      secondaryBackground = Container(
        color: Theme.of(context).colorScheme.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20.0),
        child: Icon(Icons.delete_sweep_outlined, color: Theme.of(context).colorScheme.onErrorContainer),
      );
    } else if (_swipeToArchiveNotesEnabled) {
      direction = DismissDirection.startToEnd;
      background = Container(
        color: Theme.of(context).colorScheme.primaryContainer,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20.0),
        child: Icon(Icons.archive_outlined, color: Theme.of(context).colorScheme.onPrimaryContainer),
      );
    } else if (_swipeToDeleteNotesEnabled) {
      direction = DismissDirection.endToStart;
      background = Container(
        color: Theme.of(context).colorScheme.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20.0),
        child: Icon(Icons.delete_sweep_outlined, color: Theme.of(context).colorScheme.onErrorContainer),
      );
    }

    if (direction != DismissDirection.none) {
      return Dismissible(
        key: ValueKey(note.id),
        background: background,
        secondaryBackground: secondaryBackground,
        direction: direction,
        confirmDismiss: (dismissDirection) => _confirmNoteDismiss(note, dismissDirection),
        onDismissed: (dismissDirection) => _handleNoteDismiss(note, dismissDirection, noteProvider),
        child: noteCardListItem,
      );
    }

    return noteCardListItem;
  }

  Future<bool?> _confirmNoteDismiss(Note note, DismissDirection dismissDirection) async {
    if (_isPerformingBulkAction) return false;

    // Allow archiving locked notes
    if (dismissDirection == DismissDirection.startToEnd) {
      return true;
    }

    // For deleting, check if locked
    if (note.isLocked && dismissDirection == DismissDirection.endToStart) {
      _showLockedNotesInfoDialog(
        context,
        title: 'Cannot Delete Locked Note',
        content: 'Please unlock this note before deleting.',
      );
      return false;
    }

    return true;
  }

  Future<void> _handleNoteDismiss(Note note, DismissDirection dismissDirection, NoteProvider noteProvider) async {
    final String noteTitle = note.title.isNotEmpty ? note.title : "Untitled note";
    bool isArchive = dismissDirection == DismissDirection.startToEnd;

    if (isArchive) {
      await _performSwipeAction(
            () => noteProvider.archiveNote(note.id, isSwipeArchive: true),
        '"$noteTitle" archived',
        noteProvider,
        isUndoForArchive: true,
      );
    } else { // Is Delete
      await _performSwipeAction(
            () => noteProvider.deleteNote(note.id, isSwipeDelete: true),
        '"$noteTitle" deleted',
        noteProvider,
        isUndoForArchive: false,
      );
    }
  }

  Future<void> _performSwipeAction(
      Future<void> Function() action,
      String successMessage,
      NoteProvider noteProvider,
      {required bool isUndoForArchive}
      ) async {
    if (!mounted) return;

    setState(() {
      _isPerformingBulkAction = true;
    });

    try {
      await action();

      if (mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMessage),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () async {
                if (!mounted) return;
                setState(() {
                  _isPerformingBulkAction = true;
                });
                try {
                  if (isUndoForArchive) {
                    await noteProvider.undoArchiveNote();
                  } else {
                    await noteProvider.undoDeleteNote();
                  }
                } finally {
                  if (mounted) {
                    setState(() {
                      _isPerformingBulkAction = false;
                    });
                  }
                }
              },
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPerformingBulkAction = false;
        });
      }
    }
  }

  bool _isSelectionMode(NoteProvider noteProvider) {
    return noteProvider.isSelectionMode;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NoteProvider>(
      builder: (context, noteProvider, child) {
        final filteredNotes = noteProvider.getFilteredNotes();
        final screenWidth = MediaQuery.of(context).size.width;
        final categoryCount = noteProvider.categories.length;
        final double chipWidth = categoryCount > 0 ? (screenWidth - 16 - (categoryCount - 1) * 8) / categoryCount : 80.0;

        final bool isSelectionMode = _isSelectionMode(noteProvider);
        final int selectedCount = noteProvider.selectedNoteIds.length;

        final bool showUnpinAction = isSelectionMode && selectedCount > 0 &&
            noteProvider.selectedNoteIds.every((id) {
              try {
                final note = noteProvider.allNotes.firstWhere((note) => note.id == id);
                return note.isPinned;
              } catch (e) {
                return false;
              }
            });

        final bool showUnlockAction = isSelectionMode && selectedCount > 0 &&
            noteProvider.selectedNoteIds.every((id) {
              try {
                final note = noteProvider.allNotes.firstWhere((note) => note.id == id);
                return note.isLocked;
              } catch (e) {
                return false;
              }
            });

        return Scaffold(
          appBar: AppBar(
            leading: isSelectionMode
                ? IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Cancel selection',
              onPressed: _isPerformingBulkAction ? null : () {
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
              style: Theme.of(context).appBarTheme.titleTextStyle,
            ),
            centerTitle: true,
            actions: isSelectionMode
                ? _buildSelectionModeActions(noteProvider)
                : _buildNormalModeActions(),
          ),
          body: Stack(
            children: [
              Column(
                children: [
                  if (noteProvider.categories.isNotEmpty)
                    _buildCategoryChips(noteProvider, chipWidth, isSelectionMode),
                  Expanded(
                    child: noteProvider.isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : (filteredNotes.isEmpty
                        ? _buildEmptyState()
                        : _isGridView
                        ? _buildNotesGrid(filteredNotes, isSelectionMode, selectedCount)
                        : _buildNotesList(filteredNotes, noteProvider)),
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
              // Global bottom spinner for bulk actions: visible even if selection is cleared
              if (_isPerformingBulkAction)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
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
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                ),
            ],
          ),
          floatingActionButton: !isSelectionMode && !_isShowingInlineUnlock && !_isPerformingBulkAction
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

  Widget _buildEmptyState() {
    return Center(
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
