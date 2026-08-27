import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foxtimer/models/todo_item.dart';
import 'package:foxtimer/widgets/todo_section.dart';

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

void main() {
  testWidgets('shows the empty state when there are no todos', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        TodoSection(
          todos: const [],
          todoController: TextEditingController(),
          todoFocusNode: FocusNode(),
          onAddTodo: () {},
          onToggleTodoDone: (_, __) {},
          onRemoveTodo: (_) {},
        ),
      ),
    );

    expect(find.text('Nenhuma tarefa ainda'), findsOneWidget);
  });

  testWidgets('renders one row per todo with correct done styling', (
    tester,
  ) async {
    final todos = [
      TodoItem(title: 'Escrever testes'),
      TodoItem(title: 'Revisar PR', done: true),
    ];

    await tester.pumpWidget(
      _wrap(
        TodoSection(
          todos: todos,
          todoController: TextEditingController(),
          todoFocusNode: FocusNode(),
          onAddTodo: () {},
          onToggleTodoDone: (_, __) {},
          onRemoveTodo: (_) {},
        ),
      ),
    );

    expect(find.text('Escrever testes'), findsOneWidget);
    expect(find.text('Revisar PR'), findsOneWidget);
    expect(find.text('Nenhuma tarefa ainda'), findsNothing);

    final doneText = tester.widget<Text>(find.text('Revisar PR'));
    expect(doneText.style?.decoration, TextDecoration.lineThrough);

    final pendingText = tester.widget<Text>(find.text('Escrever testes'));
    expect(pendingText.style?.decoration, isNot(TextDecoration.lineThrough));
  });

  testWidgets('tapping add button invokes onAddTodo', (tester) async {
    var addCount = 0;

    await tester.pumpWidget(
      _wrap(
        TodoSection(
          todos: const [],
          todoController: TextEditingController(),
          todoFocusNode: FocusNode(),
          onAddTodo: () => addCount++,
          onToggleTodoDone: (_, __) {},
          onRemoveTodo: (_) {},
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    expect(addCount, 1);
  });

  testWidgets('submitting the text field invokes onAddTodo', (tester) async {
    var addCount = 0;
    final controller = TextEditingController();

    await tester.pumpWidget(
      _wrap(
        TodoSection(
          todos: const [],
          todoController: controller,
          todoFocusNode: FocusNode(),
          onAddTodo: () => addCount++,
          onToggleTodoDone: (_, __) {},
          onRemoveTodo: (_) {},
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'Nova tarefa');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(addCount, 1);
  });

  testWidgets('tapping a todo row toggles it, tapping delete removes it', (
    tester,
  ) async {
    final toggled = <(int, bool?)>[];
    final removed = <int>[];
    final todos = [TodoItem(title: 'Item único')];

    await tester.pumpWidget(
      _wrap(
        TodoSection(
          todos: todos,
          todoController: TextEditingController(),
          todoFocusNode: FocusNode(),
          onAddTodo: () {},
          onToggleTodoDone: (i, v) => toggled.add((i, v)),
          onRemoveTodo: (i) => removed.add(i),
        ),
      ),
    );

    await tester.tap(find.text('Item único'));
    await tester.pump();
    expect(toggled, [(0, true)]);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pump();
    expect(removed, [0]);
  });
}
