class Note {
  final String id;
  final String title;
  final String content; // Raw Quill Delta JSON
  final String plainTextContent; // For search
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
    required this.content,
    required this.plainTextContent,
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
      'content': content,
      'plainTextContent': plainTextContent,
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
    return Note(
      id: map['id'],
      title: map['title'],
      content: map['content'],
      // Ensure plainTextContent is handled, even if it might be null from older db versions initially
      plainTextContent: map['plainTextContent'] as String? ?? '',
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
