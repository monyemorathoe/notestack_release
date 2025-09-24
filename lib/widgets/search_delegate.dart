import 'package:flutter/material.dart';
import '../models/note.dart';
import '../services/database_helper.dart';
import 'note_card.dart'; // Assuming NoteCard is in widgets folder

class NotesSearchDelegate extends SearchDelegate<Note?> {
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
        return ListView.builder(
          padding: const EdgeInsets.all(8.0),
          itemCount: results.length,
          itemBuilder: (context, index) {
            // Note: If you want to navigate to NoteScreen when a search result is tapped:
            // return InkWell(
            //   onTap: () {
            //     close(context, results[index]); // This will pass the selected note back
            //     // You might want to navigate to NoteScreen with results[index] from where you called showSearch
            //   },
            //   child: NoteCard(note: results[index]),
            // );
            return NoteCard(note: results[index]);
          },
        );
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