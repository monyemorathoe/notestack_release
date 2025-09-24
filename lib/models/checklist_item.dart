// ...existing code...
class ChecklistItem {
  final int id;
  String title;
  bool isDone;

  ChecklistItem({
    required this.id,
    required this.title,
    this.isDone = false,
  });
}
// ...existing code...