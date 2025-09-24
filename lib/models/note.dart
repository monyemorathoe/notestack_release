class Note {
  final String id;
  final String title;
  final String content;
  final String category;
  final DateTime createdAt;
  final DateTime? modifiedAt; // Added for modification timestamp
  final bool isArchived;
  final bool isPinned;
  final bool isLocked;
  final int? colorValue;

  Note({
    required this.id,
    required this.title,
    required this.content,
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
      'category': category,
      'createdAt': createdAt.toIso8601String(),
      'modifiedAt': modifiedAt?.toIso8601String(), // Added to map
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
      category: map['category'],
      createdAt: DateTime.parse(map['createdAt']),
      modifiedAt: map['modifiedAt'] == null ? null : DateTime.parse(map['modifiedAt']), // Added from map
      isArchived: map['isArchived'] == 1,
      isPinned: map['isPinned'] == 1,
      isLocked: (map['isLocked'] as int? ?? 0) == 1,
      colorValue: map['colorValue'] as int?,
    );
  }
}