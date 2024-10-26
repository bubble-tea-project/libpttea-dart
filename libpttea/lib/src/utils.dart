import 'dart:async';
import 'dart:collection';



extension RegExpMatchExtension on RegExpMatch {
  /// Returns a map of all named groups from this match.
  Map<String, String?> namedGroupToMap() {
    return {
      for (var name in this.groupNames) name: this.namedGroup(name)
    };
  }
}





class AsyncQueue<T> {
  final Queue<T> _queue = Queue<T>();
  Completer<void>? _notEmptyCompleter;

  // Adds an item to the queue and notifies any waiting consumers
  void put(T item) {
    _queue.add(item);
    _notEmptyCompleter?.complete();
    _notEmptyCompleter = null;
  }

  // Retrieves an item from the queue, waiting if necessary until one is available
  Future<T> get() async {
    while (_queue.isEmpty) {
      _notEmptyCompleter = Completer<void>();
      await _notEmptyCompleter!.future;
    }
    return _queue.removeFirst();
  }

  // Checks if the queue is empty
  bool get isEmpty => _queue.isEmpty;

  // Checks if the queue is not empty
  bool get isNotEmpty => _queue.isNotEmpty;

  // Returns the current length of the queue
  int get length => _queue.length;
}
