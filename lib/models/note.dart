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

  Note copyWith({
    String? id,
    String? title,
    String? content,
    String? plainTextContent,
    String? category,
    DateTime? createdAt,
    DateTime? modifiedAt,
    bool? isArchived,
    bool? isPinned,
    bool? isLocked,
    int? colorValue,
    bool clearColorValue = false, // Added to explicitly set colorValue to null
  }) {
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      plainTextContent: plainTextContent ?? this.plainTextContent,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      isArchived: isArchived ?? this.isArchived,
      isPinned: isPinned ?? this.isPinned,
      isLocked: isLocked ?? this.isLocked,
      colorValue: clearColorValue ? null : (colorValue ?? this.colorValue),
    );
  }
}
