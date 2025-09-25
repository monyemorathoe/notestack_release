import 'dart:convert'; // Added for jsonEncode and jsonDecode
import 'package:parchment/parchment.dart'; // Added for ParchmentDocument

class Note {
  final String id;
  final String title;
  final ParchmentDocument content; // Changed from String to ParchmentDocument
  final String category;
  final DateTime createdAt;
  final DateTime? modifiedAt;
  final bool isArchived;
  final bool isPinned;
  final bool isLocked;
  final int? colorValue;

  Note({
    required this.id,
    required this.title,
    required this.content, // Changed to require ParchmentDocument
    required this.category,
    required this.createdAt,
    this.modifiedAt,
    this.isArchived = false,
    this.isPinned = false,
    this.isLocked = false,
    this.colorValue,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      // Serialize ParchmentDocument to a JSON string for database storage
      'content': jsonEncode(content.toJson()), 
      'category': category,
      'createdAt': createdAt.toIso8601String(),
      'modifiedAt': modifiedAt?.toIso8601String(),
      'isArchived': isArchived ? 1 : 0,
      'isPinned': isPinned ? 1 : 0,
      'isLocked': isLocked ? 1 : 0,
      'colorValue': colorValue,
    };
  }

  factory Note.fromMap(Map<String, dynamic> map) {
    ParchmentDocument docContent;
    // Ensure content is a string, default to empty string if null
    final String stringContent = map['content'] as String? ?? ""; 

    try {
      // Try to parse content as JSON (new format for rich text)
      // ParchmentDocument.fromJson expects List<dynamic>
      final decodedJson = jsonDecode(stringContent);
      if (decodedJson is List) {
        docContent = ParchmentDocument.fromJson(decodedJson.cast<dynamic>());
      } else {
        // If JSON is not a list, treat as plain text for safety
        docContent = ParchmentDocument();
        if (stringContent.isNotEmpty) {
          docContent.insert(0, stringContent);
        }
      }
    } catch (e) {
      // If jsonDecode fails or it's not a list, it's likely plain text (old format)
      // or an empty string for new notes before content is added.
      docContent = ParchmentDocument();
      if (stringContent.isNotEmpty) {
        docContent.insert(0, stringContent); // Treat as plain text
      }
    }

    return Note(
      id: map['id'],
      title: map['title'],
      content: docContent, // Assign the ParchmentDocument
      category: map['category'],
      createdAt: DateTime.parse(map['createdAt']),
      modifiedAt: map['modifiedAt'] == null ? null : DateTime.parse(map['modifiedAt']),
      isArchived: map['isArchived'] == 1,
      isPinned: map['isPinned'] == 1,
      isLocked: (map['isLocked'] as int? ?? 0) == 1,
      colorValue: map['colorValue'] as int?,
    );
  }
}
