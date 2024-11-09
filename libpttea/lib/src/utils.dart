/// libpttea.utils
/// ----------
///
/// This module provides utilities used within libpttea.
library;

import 'dart:async';
import 'dart:collection';

extension RegExpMatchExtension on RegExpMatch {
  /// Returns a map of all named groups from match.
  Map<String, String?> groupMap({String? noMatch}) {
    /// Returns a map {groupNames: namedGroup_value}
    /// If a capture group does not match, namedGroup_value will be 'noMatch'
    return {
      for (var name in this.groupNames) name: (this.namedGroup(name) ?? noMatch)
    };
  }
}

/// A first in, first out (FIFO) asynchronous queue.
class AsyncQueue<T> {
  final Queue<T> _queue = Queue<T>();
  Completer<void>? _notEmptyCompleter;

  /// Put an item into the queue.
  void put(T item) {
    _queue.add(item);

    // notify any waiting consumers
    _notEmptyCompleter?.complete();
    _notEmptyCompleter = null;
  }

  /// Remove and return an item from the queue. If queue is empty, wait until an item is available.
  Future<T> get() async {
    while (_queue.isEmpty) {
      _notEmptyCompleter = Completer<void>();

      // wait until item is available
      await _notEmptyCompleter!.future;
    }

    return _queue.removeFirst();
  }

  /// Return True if the queue is empty, False otherwise.
  bool get isEmpty => _queue.isEmpty;

  /// Return the number of items in the queue.
  int get length => _queue.length;
}
