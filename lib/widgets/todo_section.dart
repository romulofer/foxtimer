import 'package:flutter/material.dart';
import '../models/todo_item.dart';

class TodoSection extends StatelessWidget {
  final List<TodoItem> todos;
  final TextEditingController todoController;
  final VoidCallback onAddTodo;
  final void Function(int index, bool? value) onToggleTodoDone;
  final void Function(int index) onRemoveTodo;

  const TodoSection({
    super.key,
    required this.todos,
    required this.todoController,
    required this.onAddTodo,
    required this.onToggleTodoDone,
    required this.onRemoveTodo,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tarefas (To-do list)',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: todoController,
                decoration: const InputDecoration(
                  labelText: 'Nova tarefa',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => onAddTodo(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: onAddTodo,
              tooltip: 'Adicionar tarefa',
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (todos.isEmpty)
          const Text(
            'Nenhuma tarefa ainda. Adicione algo para acompanhar junto do Pomodoro 🙂',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: todos.length,
            itemBuilder: (context, index) {
              final todo = todos[index];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Checkbox(
                  value: todo.done,
                  onChanged: (value) => onToggleTodoDone(index, value),
                ),
                title: Text(
                  todo.title,
                  style: TextStyle(
                    decoration: todo.done ? TextDecoration.lineThrough : null,
                    color: todo.done ? Colors.grey : null,
                  ),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => onRemoveTodo(index),
                ),
              );
            },
          ),
      ],
    );
  }
}
