import 'package:flutter/material.dart';
import '../models/todo_item.dart';

class TodoSection extends StatelessWidget {
  final List<TodoItem> todos;
  final TextEditingController todoController;
  final VoidCallback onAddTodo;
  final void Function(int index, bool? value) onToggleTodoDone;
  final void Function(int index) onRemoveTodo;
  final FocusNode todoFocusNode;

  const TodoSection({
    super.key,
    required this.todos,
    required this.todoController,
    required this.onAddTodo,
    required this.onToggleTodoDone,
    required this.onRemoveTodo,
    required this.todoFocusNode,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.checklist_rtl, color: colorScheme.primary, size: 22),
            const SizedBox(width: 8),
            const Text(
              'Tarefas',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: todoController,
                    focusNode: todoFocusNode,
                    decoration: const InputDecoration(
                      hintText: 'O que precisa ser feito?',
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    onSubmitted: (_) => onAddTodo(),
                  ),
                ),
                IconButton.filled(
                  icon: const Icon(Icons.add),
                  onPressed: onAddTodo,
                  tooltip: 'Adicionar tarefa',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (todos.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.task_alt,
                    size: 48,
                    color: colorScheme.onSurface.withValues(alpha: 0.25),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Nenhuma tarefa ainda',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Adicione algo para acompanhar junto do seu foco',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: todos.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final todo = todos[index];
              return Card(
                child: ListTile(
                  onTap: () => onToggleTodoDone(index, !todo.done),
                  leading: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: todo.done
                          ? colorScheme.primary
                          : Colors.transparent,
                      border: Border.all(
                        color: todo.done
                            ? colorScheme.primary
                            : colorScheme.onSurface.withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                    child: todo.done
                        ? Icon(Icons.check, size: 16, color: colorScheme.onPrimary)
                        : null,
                  ),
                  title: Text(
                    todo.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      decoration: todo.done ? TextDecoration.lineThrough : null,
                      color: todo.done
                          ? colorScheme.onSurface.withValues(alpha: 0.4)
                          : colorScheme.onSurface,
                    ),
                  ),
                  trailing: IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      color: colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                    onPressed: () => onRemoveTodo(index),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
