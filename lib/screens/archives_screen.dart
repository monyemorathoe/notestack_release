import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart'; // Added import
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/note_provider.dart';
import '../widgets/note_card.dart';

// Helper function to show locked notes dialog
Future<void> _showLockedNotesInfoDialog(BuildContext context) async {
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
                const Text(
                  'Cannot Delete Locked Notes',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Please unlock the selected notes before deleting.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
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

// Helper function to show delete confirmation dialog
void _showDeleteSelectedNotesConfirmationDialog(
    BuildContext parentContext,
    NoteProvider noteProvider,
    VoidCallback onProcessStart, // Callback when process starts
    VoidCallback onProcessEnd    // Callback when process ends
 ) {
  final selectedCount = noteProvider.selectedNoteIds.length;
  showDialog(
    context: parentContext,
    barrierDismissible: false, // Prevent dismissing while loading
    builder: (BuildContext dialogContext) {
      bool isDeletingInDialog = false; // Local state for dialog's button
      return StatefulBuilder( // Use StatefulBuilder for dialog's own loading state
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
                    const Text(
                      'Delete Permanently?',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'This will permanently delete ${selectedCount > 1 ? "these $selectedCount notes" : "this note"}. This action cannot be undone.',
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
                            onProcessStart(); // Notify parent screen that process has started
                            bool deleteSuccess = false;
                            try {
                              deleteSuccess = await noteProvider.deleteSelectedNotes();
                            } finally {
                              if (dialogContext.mounted) {
                                Navigator.of(dialogContext).pop(); 
                              }
                              if (!deleteSuccess && parentContext.mounted) {
                                _showLockedNotesInfoDialog(parentContext);
                              }
                              onProcessEnd(); // Notify parent screen that process has ended
                            }
                          },
                          child: isDeletingInDialog 
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                              : const Text('Delete'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }
      );
    },
  );
}

class ArchivesScreen extends StatefulWidget {
  const ArchivesScreen({super.key});

  @override
  State<ArchivesScreen> createState() => _ArchivesScreenState();
}

class _ArchivesScreenState extends State<ArchivesScreen> {
  static const String _kPrefIsGridView = 'isGridView';
  bool _isGridView = false;
  bool _isPerformingBulkAction = false; // State for loading indicator

  @override
  void initState() {
    super.initState();
    _loadViewPreference();
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
      // ignore
    }
  }

  Widget _buildBottomSheetAction(
      BuildContext context, IconData icon, String label, VoidCallback? onPressed, {bool isEnabled = true}) {
    final theme = Theme.of(context);
    return Expanded(
      child: InkWell(
        onTap: isEnabled ? onPressed : null,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isEnabled ? theme.iconTheme.color : theme.disabledColor),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: isEnabled ? theme.textTheme.bodySmall?.color : theme.disabledColor),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSelectionBottomSheet(BuildContext context, NoteProvider noteProvider) {
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
                  Icons.unarchive_outlined,
                  'Unarchive',
                  _isPerformingBulkAction ? null : () async {
                    if (!mounted) return;
                    setState(() {
                      _isPerformingBulkAction = true;
                    });
                    try {
                      await noteProvider.unarchiveSelectedNotes();
                    } finally {
                      if (mounted) {
                        setState(() {
                          _isPerformingBulkAction = false;
                        });
                      }
                    }
                  },
                  isEnabled: !_isPerformingBulkAction,
                ),
                _buildBottomSheetAction(
                  context,
                  Icons.delete_forever_outlined,
                  'Delete',
                  _isPerformingBulkAction ? null : () {
                    _showDeleteSelectedNotesConfirmationDialog(
                      context, 
                      noteProvider,
                      () { // onProcessStart
                        if (mounted) {
                          setState(() { _isPerformingBulkAction = true; });
                        }
                      },
                      () { // onProcessEnd
                        if (mounted) {
                           setState(() { _isPerformingBulkAction = false; });
                        }
                      }
                    );
                  },
                  isEnabled: !_isPerformingBulkAction,
                ),
              ],
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NoteProvider>(
      builder: (context, noteProvider, child) {
        final archivedNotes = noteProvider.archivedNotes;
        final isSelectionMode = noteProvider.isSelectionMode;
        final selectedCount = noteProvider.selectedNoteIds.length;

        final EdgeInsets listPadding = EdgeInsets.fromLTRB(
          8.0, 
          8.0, 
          8.0, 
          (isSelectionMode && selectedCount > 0 && !_isPerformingBulkAction) ? 88.0 : 8.0
        );

        return Scaffold(
          appBar: AppBar(
            leading: isSelectionMode
                ? IconButton(
                    icon: const Icon(Icons.close),
                    splashRadius: 24.0,
                    tooltip: 'Cancel selection',
                    onPressed: _isPerformingBulkAction ? null : () {
                      noteProvider.clearSelection();
                    },
                  )
                : null, 
            title: Text(
              isSelectionMode ? '$selectedCount selected' : 'Archives',
              style: Theme.of(context).appBarTheme.titleTextStyle,
            ),
            centerTitle: true,
          ),
          body: Builder(
            builder: (context) {
              Widget content;
              if (archivedNotes.isEmpty) {
                content = Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Icon(
                        Icons.archive_outlined,
                        size: 64,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No archived notes.',
                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              } else if (_isGridView) {
                content = (Platform.isWindows || Platform.isMacOS || Platform.isLinux)
                    ? LayoutBuilder(
                        builder: (context, constraints) {
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
                              (isSelectionMode && selectedCount > 0 && !_isPerformingBulkAction) ? 88.0 : gridPadding,
                            ),
                            itemCount: archivedNotes.length,
                            itemBuilder: (context, index) {
                              final note = archivedNotes[index];
                              return NoteCard(note: note, isGridView: true);
                            },
                          );
                        },
                      )
                    : GridView.builder(
                        padding: listPadding,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.75,
                          crossAxisSpacing: 8.0,
                          mainAxisSpacing: 8.0,
                        ),
                        itemCount: archivedNotes.length,
                        itemBuilder: (context, index) {
                          final note = archivedNotes[index];
                          return NoteCard(note: note, isGridView: true);
                        },
                      );
              } else {
                content = ListView.builder(
                  padding: listPadding, 
                  itemCount: archivedNotes.length,
                  itemBuilder: (context, index) {
                    final note = archivedNotes[index];
                    return NoteCard(note: note);
                  },
                );
              }

              return Stack(
                children: [
                  content,
                  if (isSelectionMode && selectedCount > 0)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: _buildSelectionBottomSheet(context, noteProvider),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}
