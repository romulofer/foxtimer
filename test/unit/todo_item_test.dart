import 'package:flutter_test/flutter_test.dart';
import 'package:foxtimer/models/todo_item.dart';

void main() {
  group('TodoItem', () {
    test('defaults done to false', () {
      final todo = TodoItem(title: 'Estudar');
      expect(todo.title, 'Estudar');
      expect(todo.done, isFalse);
    });

    test('toJson/fromJson round trip preserves title and done', () {
      final todo = TodoItem(title: 'Revisar PR', done: true);

      final json = todo.toJson();
      expect(json, {'title': 'Revisar PR', 'done': true});

      final restored = TodoItem.fromJson(json);
      expect(restored.title, todo.title);
      expect(restored.done, todo.done);
    });

    test('fromJson defaults done to false when missing', () {
      final todo = TodoItem.fromJson({'title': 'Sem status'});
      expect(todo.done, isFalse);
    });
  });
}
