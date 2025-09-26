import 'dart:io';

import 'package:flutter/material.dart';
import '../models/note.dart';
import '../services/database_helper.dart';
import 'note_card.dart'; // Assuming NoteCard is in widgets folder

class NotesSearchDelegate extends SearchDelegate<Note?> {
  final bool isGridView;

  NotesSearchDelegate({required this.isGridView});

  @override
  ThemeData appBarTheme(BuildContext context) {
    final theme = Theme.of(context);
    return theme.copyWith(
      appBarTheme: theme.appBarTheme.copyWith(
        backgroundColor: theme.colorScheme.surface, // M3 surface color for search appbar
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
        titleTextStyle: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.onSurface),
      ),
      inputDecorationTheme: searchFieldDecorationTheme ??
          InputDecorationTheme(
            hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            border: InputBorder.none,
          ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          tooltip: 'Clear query',
          onPressed: () {
            query = '';
            showSuggestions(context); // Refresh suggestions
          },
        )
      else
        Container(), // Empty container if query is empty
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      tooltip: 'Back',
      onPressed: () {
        close(context, null);
      },
    );
  }

  Widget _buildSearchResults(BuildContext context, String currentQuery) {
    if (currentQuery.isEmpty) {
      return const Center(
        child: Text('Type to search for notes.'),
      );
    }
    return FutureBuilder<List<Note>>(
      future: DatabaseHelper.instance.searchNotes(currentQuery),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Text(
              'No notes found matching "$currentQuery"',
              textAlign: TextAlign.center,
            ),
          );
        }
        final results = snapshot.data!;
        if (isGridView) {
          return (Platform.isWindows || Platform.isMacOS || Platform.isLinux)
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
                        gridPadding,
                      ),
                      itemCount: results.length,
                      itemBuilder: (context, index) {
                        return NoteCard(note: results[index], isGridView: true);
                      },
                    );
                  },
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(8.0),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, // Standard 2 columns for mobile
                    childAspectRatio: 0.75, // Common aspect ratio for notes
                    crossAxisSpacing: 8.0,
                    mainAxisSpacing: 8.0,
                  ),
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    return NoteCard(note: results[index], isGridView: true);
                  },
                );
        } else {
          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: results.length,
            itemBuilder: (context, index) {
              return NoteCard(note: results[index], isGridView: false);
            },
          );
        }
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    // buildResults is called when the user submits the search query (e.g., presses enter)
    return _buildSearchResults(context, query);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    // buildSuggestions is called as the user types
    // It's common to show live search results or suggestions here
    return _buildSearchResults(context, query);
  }

// Optional: Override to customize the search field's appearance more directly
// @override
// InputDecorationTheme get searchFieldDecorationTheme {
//   return InputDecorationTheme(
//     filled: true,
//     fillColor: Colors.grey[200],
//     hintStyle: TextStyle(color: Colors.grey[600]),
//     border: OutlineInputBorder(
//       borderRadius: BorderRadius.circular(8.0),
//       borderSide: BorderSide.none,
//     ),
//   );
// }
}