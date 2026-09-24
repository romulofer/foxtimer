import 'package:flutter/material.dart';
import '../models/todo_item.dart';

class _EditTodoDialog extends StatefulWidget {
  final String initial;

  const _EditTodoDialog({required this.initial});

  @override
  State<_EditTodoDialog> createState() => _EditTodoDialogState();
}

class _EditTodoDialogState extends State<_EditTodoDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar tarefa'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'O que precisa ser feito?'),
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}

class TodoSection extends StatelessWidget {
  final List<TodoItem> todos;
  final TextEditingController todoController;
  final VoidCallback onAddTodo;
  final void Function(int index, bool? value) onToggleTodoDone;
  final void Function(int index, String newTitle) onEditTodo;
  final void Function(int index) onRemoveTodo;
  final FocusNode todoFocusNode;

  const TodoSection({
    super.key,
    required this.todos,
    required this.todoController,
    required this.onAddTodo,
    required this.onToggleTodoDone,
    required this.onEditTodo,
    required this.onRemoveTodo,
    required this.todoFocusNode,
  });

  Future<void> _showEditDialog(BuildContext context, int index) async {
    final newTitle = await showDialog<String>(
      context: context,
      builder: (dialogContext) => _EditTodoDialog(initial: todos[index].title),
    );

    if (newTitle != null && newTitle.trim().isNotEmpty) {
      onEditTodo(index, newTitle);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Show pending tasks first, then completed ones at the end. Preserve each
    // task's original index so the callbacks still target the right item.
    final orderedIndices = <int>[
      for (var i = 0; i < todos.length; i++)
        if (!todos[i].done) i,
      for (var i = 0; i < todos.length; i++)
        if (todos[i].done) i,
    ];

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
              final originalIndex = orderedIndices[index];
              final todo = todos[originalIndex];
              return Card(
                child: ListTile(
                  onTap: () => onToggleTodoDone(originalIndex, !todo.done),
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
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.edit_outlined,
                          color: colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                        tooltip: 'Editar tarefa',
                        onPressed: () => _showEditDialog(context, originalIndex),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.delete_outline,
                          color: colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                        tooltip: 'Remover tarefa',
                        onPressed: () => onRemoveTodo(originalIndex),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
