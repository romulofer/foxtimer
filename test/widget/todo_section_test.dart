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
          onEditTodo: (_, __) {},
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
          onEditTodo: (_, __) {},
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
          onEditTodo: (_, __) {},
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
          onEditTodo: (_, __) {},
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
          onEditTodo: (_, __) {},
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

  testWidgets('completed todos are grouped after pending ones', (tester) async {
    final todos = [
      TodoItem(title: 'A concluída', done: true),
      TodoItem(title: 'B pendente'),
      TodoItem(title: 'C concluída', done: true),
      TodoItem(title: 'D pendente'),
    ];

    await tester.pumpWidget(
      _wrap(
        TodoSection(
          todos: todos,
          todoController: TextEditingController(),
          todoFocusNode: FocusNode(),
          onAddTodo: () {},
          onToggleTodoDone: (_, __) {},
          onEditTodo: (_, __) {},
          onRemoveTodo: (_) {},
        ),
      ),
    );

    // Pending first (in original order), then completed (in original order).
    double dy(String text) => tester.getTopLeft(find.text(text)).dy;
    expect(dy('B pendente'), lessThan(dy('D pendente')));
    expect(dy('D pendente'), lessThan(dy('A concluída')));
    expect(dy('A concluída'), lessThan(dy('C concluída')));
  });

  testWidgets('callbacks target the original index after reordering', (
    tester,
  ) async {
    final toggled = <(int, bool?)>[];
    final todos = [
      TodoItem(title: 'A concluída', done: true),
      TodoItem(title: 'B pendente'),
    ];

    await tester.pumpWidget(
      _wrap(
        TodoSection(
          todos: todos,
          todoController: TextEditingController(),
          todoFocusNode: FocusNode(),
          onAddTodo: () {},
          onToggleTodoDone: (i, v) => toggled.add((i, v)),
          onEditTodo: (_, __) {},
          onRemoveTodo: (_) {},
        ),
      ),
    );

    // 'B pendente' renders first but is index 1 in the original list.
    await tester.tap(find.text('B pendente'));
    await tester.pump();
    expect(toggled, [(1, true)]);
  });

  testWidgets('editing a todo pre-fills the dialog and reports the new title', (
    tester,
  ) async {
    final edited = <(int, String)>[];
    final todos = [TodoItem(title: 'Título antigo')];

    await tester.pumpWidget(
      _wrap(
        TodoSection(
          todos: todos,
          todoController: TextEditingController(),
          todoFocusNode: FocusNode(),
          onAddTodo: () {},
          onToggleTodoDone: (_, __) {},
          onEditTodo: (i, t) => edited.add((i, t)),
          onRemoveTodo: (_) {},
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Editar tarefa'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Título antigo'), findsOneWidget);

    await tester.enterText(
      find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)),
      'Título novo',
    );
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(edited, [(0, 'Título novo')]);
  });

  testWidgets('cancelling the edit dialog does not report a change', (
    tester,
  ) async {
    final edited = <(int, String)>[];
    final todos = [TodoItem(title: 'Inalterado')];

    await tester.pumpWidget(
      _wrap(
        TodoSection(
          todos: todos,
          todoController: TextEditingController(),
          todoFocusNode: FocusNode(),
          onAddTodo: () {},
          onToggleTodoDone: (_, __) {},
          onEditTodo: (i, t) => edited.add((i, t)),
          onRemoveTodo: (_) {},
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)),
      'Descartado',
    );
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(edited, isEmpty);
  });

  testWidgets('editing to an empty title reports no change', (tester) async {
    final edited = <(int, String)>[];
    final todos = [TodoItem(title: 'Mantém')];

    await tester.pumpWidget(
      _wrap(
        TodoSection(
          todos: todos,
          todoController: TextEditingController(),
          todoFocusNode: FocusNode(),
          onAddTodo: () {},
          onToggleTodoDone: (_, __) {},
          onEditTodo: (i, t) => edited.add((i, t)),
          onRemoveTodo: (_) {},
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)),
      '   ',
    );
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(edited, isEmpty);
  });
}
