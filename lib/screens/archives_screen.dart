import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart'; // Added import
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/note_provider.dart';
import '../widgets/note_card.dart';

// Helper function to show locked notes dialog (copied from home_screen.dart)
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

// Helper function to show delete confirmation dialog (copied from home_screen.dart)
void _showDeleteSelectedNotesConfirmationDialog(
    BuildContext parentContext, // This context is from where the dialog is called (e.g., Consumer builder)
    NoteProvider noteProvider) {
  final selectedCount = noteProvider.selectedNoteIds.length;
  showDialog(
    context: parentContext, // Use the passed-in context for showing this dialog
    builder: (BuildContext dialogContext) { // This is the context for the Dialog itself
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
                  'Delete Permanently?',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                        if (dialogContext.mounted) { // Check if dialogContext is still valid
                          Navigator.of(dialogContext).pop(); // Pop the confirmation dialog first
                        }

                        if (!deleteSuccess && parentContext.mounted) { // Check if parentContext is still valid
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

class ArchivesScreen extends StatefulWidget {
  const ArchivesScreen({super.key});

  @override
  State<ArchivesScreen> createState() => _ArchivesScreenState();
}

class _ArchivesScreenState extends State<ArchivesScreen> {
  // Persisted view key must match HomeScreen
  static const String _kPrefIsGridView = 'isGridView';
  bool _isGridView = false;

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

  // Updated helper method for bottom sheet actions (similar to HomeScreen)
  Widget _buildBottomSheetAction(
      BuildContext context, IconData icon, String label, VoidCallback onPressed) {
    return Expanded(
      child: InkWell(
        onTap: onPressed,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }
  
  // Method to build the selection bottom sheet (similar to HomeScreen)
  Widget _buildSelectionBottomSheet(BuildContext context, NoteProvider noteProvider) {
    return Container(
      height: 80.0, // Standard height
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
            Icons.unarchive_outlined,
            'Unarchive',
            () => noteProvider.unarchiveSelectedNotes(),
          ),
          _buildBottomSheetAction(
            context,
            Icons.delete_forever_outlined, // Consistent with usage in other parts if permanent
            'Delete',
            () => _showDeleteSelectedNotesConfirmationDialog(context, noteProvider),
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

        // Dynamic padding for the list/grid
        final EdgeInsets listPadding = EdgeInsets.fromLTRB(
          8.0, 
          8.0, 
          8.0, 
          (isSelectionMode && selectedCount > 0) ? 88.0 : 8.0
        );

        return Scaffold(
          appBar: AppBar(
            leading: isSelectionMode
                ? IconButton(
                    icon: const Icon(Icons.close),
                    splashRadius: 24.0,
                    tooltip: 'Cancel selection',
                    onPressed: () {
                      noteProvider.clearSelection();
                    },
                  )
                : null, // Defaults to back arrow
            title: Text(
              isSelectionMode ? '$selectedCount selected' : 'Archives',
              style: Theme.of(context).appBarTheme.titleTextStyle,
            ),
            centerTitle: true,
            // Optionally add actions like view toggle here if needed in the future
          ),
          body: Builder(
            // Builder ensures the context for dialogs/bottom sheets is correct
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
                              (isSelectionMode && selectedCount > 0) ? 88.0 : gridPadding,
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
                        padding: listPadding, // Apply dynamic padding
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
                  padding: listPadding, // Apply dynamic padding
                  itemCount: archivedNotes.length,
                  itemBuilder: (context, index) {
                    final note = archivedNotes[index];
                    return NoteCard(note: note);
                  },
                );
              }

              return Stack(
                children: [
                  content, // The main list or grid
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
          // Removed the old bottomNavigationBar
        );
      },
    );
  }
}
