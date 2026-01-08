class TodoItem {
  String title;
  bool done;

  TodoItem({required this.title, this.done = false});

  Map<String, dynamic> toJson() => {'title': title, 'done': done};

  factory TodoItem.fromJson(Map<String, dynamic> json) => TodoItem(
    title: json['title'] as String,
    done: json['done'] as bool? ?? false,
  );
}
