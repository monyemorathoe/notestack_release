import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:notestack/main.dart';
import 'package:notestack/providers/note_provider.dart';

void main() {
  testWidgets('NoteStack app renders HomeScreen correctly', (WidgetTester tester) async {
    // Provide the NoteProvider to the app
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => NoteProvider(),
        child: const NoteStackApp(),
      ),
    );

    // Trigger a frame
    await tester.pumpAndSettle();

    // Verify the app bar title
    expect(find.text('NoteStack'), findsOneWidget);

    // Verify the "No notes yet" text when there are no notes
    expect(find.text('No notes yet. Add one!'), findsOneWidget);

    // Verify the FloatingActionButton exists
    expect(find.byIcon(Icons.add), findsOneWidget);
  });

  testWidgets('Tapping FAB navigates to NoteScreen', (WidgetTester tester) async {
    // Provide the NoteProvider to the app
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => NoteProvider(),
        child: const NoteStackApp(),
      ),
    );

    // Trigger a frame
    await tester.pumpAndSettle();

    // Tap the FloatingActionButton
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    // Verify that NoteScreen is displayed (check for 'New Note' in app bar)
    expect(find.text('New Note'), findsOneWidget);

    // Verify that the title TextField is present
    expect(find.byType(TextField), findsNWidgets(2)); // Title and Content fields
  });
}