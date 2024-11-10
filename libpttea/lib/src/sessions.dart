/// libpttea.sessions
/// ----------
///
/// This module provides a Session object to manage resources (websocket_client, ansip_screen, router)
/// in the connection.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:logging/logging.dart';
import 'package:ansiparser/ansiparser.dart' as ansiparser;

import './websocket_client.dart';
import './pattern.dart' as pattern;
import './router.dart';

final Logger logger = Logger('session');

class Session {
  final websocketClient = WebSocketClient();
  final ansipScreen = ansiparser.newScreen();
  late Router router;

  /// timeout_delay (seconds) , default_timeout + timeout_delay = total_timeout
  int timeoutDelay;

  Session({this.timeoutDelay = 0}) {
    router = Router(this);
  }

  /// calculate the `total_timeout`
  Duration _totalTimeout(int? timeout) {
    if (timeout == null) {
      // Return a long Duration for blocking operations.
      return Duration(days: 365);
    } else {
      return Duration(seconds: timeout + timeoutDelay);
    }
  }

  /// Send the message, encoded in UTF-8.
  Uint8List send(String message) {
    final encodedBytes = utf8.encode(message);
    websocketClient.send(encodedBytes);

    return encodedBytes;
  }

  /// Receive the raw message that is in bytestring.
  Future<List<int>> receiveRaw({int? timeout = 3}) async {
    try {
      return await websocketClient.receiveQueue
          .get()
          .timeout(_totalTimeout(timeout));
    } on TimeoutException {
      throw TimeoutException("Wait for receive timeout.");
    }
  }

  /// Receive the raw message, wait until all fragments are received,
  /// reassemble them, and return the UTF-8 decoded message
  Future<String> receive({int? timeout = 5}) async {
    //
    Future<String> _receive() async {
      // store fragmented messages
      final List<List<int>> messageFrames = [];

      while (true) {
        final frame = await receiveRaw(timeout: null);
        messageFrames.add(frame);

        try {
          final message = utf8.decode(messageFrames.expand((x) => x).toList(),
              allowMalformed: false);

          if (pattern.regexIncompleteAnsiEscape.hasMatch(message)) {
            // message contains an incomplete ANSI escape sequence
            continue;
          }

          return message;
        } on FormatException {
          // if Unicode decode error
          continue;
        }
      }
    }

    return await _receive().timeout(_totalTimeout(timeout));
  }

  /// Wait until the specified `string` is found in the received message.
  /// If `drop` is false, return all messages in the process.
  /// Otherwise , returns the message containing the string.
  Future<dynamic> untilString(String str,
      {bool drop = false, int timeout = 10}) async {
    //
    Future<String> _untilStringDrop() async {
      //
      while (true) {
        final message = await receive(timeout: null);
        if (message.contains(str)) {
          return message;
        }
      }
    }

    Future<List<String>> _untilString() async {
      //
      final messages = <String>[];

      while (true) {
        final message = await receive(timeout: null);
        messages.add(message);
        if (message.contains(str)) {
          return messages;
        }
      }
    }

    if (drop) {
      return await _untilStringDrop().timeout(_totalTimeout(timeout));
    } else {
      return await _untilString().timeout(_totalTimeout(timeout));
    }
  }

  /// Wait until the received message matches the `regex`.
  /// If `drop` is false, return all messages in the process.
  /// Otherwise , returns the message matches the `regex`.
  Future<dynamic> untilRegex(RegExp regex,
      {bool drop = false, int timeout = 10}) async {
    //
    Future<String> _untilRegexDrop() async {
      //
      while (true) {
        final message = await receive(timeout: null);
        if (regex.hasMatch(message)) {
          return message;
        }
      }
    }

    Future<List<String>> _untilRegex() async {
      //
      final messages = <String>[];

      while (true) {
        final message = await receive(timeout: null);
        messages.add(message);
        if (regex.hasMatch(message)) {
          return messages;
        }
      }
    }

    if (drop) {
      return await _untilRegexDrop().timeout(_totalTimeout(timeout));
    } else {
      return await _untilRegex().timeout(_totalTimeout(timeout));
    }
  }

  /// Call `receive()` and put the returned message into [ansipScreen].
  Future<String> receiveAndPut({int timeout = 5}) async {
    //
    final message = await receive(timeout: timeout);
    ansipScreen.put(message);

    return message;
  }

  /// Call `until_string(drop=False)` and put the returned message into [ansipScreen].
  Future<List<String>> untilStringAndPut(String str, {int timeout = 10}) async {
    //
    final messages = await untilString(str, drop: false, timeout: timeout);
    for (var message in messages) {
      ansipScreen.put(message);
    }

    return messages;
  }

  /// Call `until_regex(drop=False)` and put the returned message into [ansipScreen].
  Future<List<String>> untilRegexAndPut(RegExp regex,
      {int timeout = 10}) async {
    //
    final messages = await untilRegex(regex, drop: false, timeout: timeout);
    for (var message in messages) {
      ansipScreen.put(message);
    }

    return messages;
  }
}
