import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:logging/logging.dart';
import 'package:ansiparser/ansiparser.dart' as ansiparser;
import 'websocket_client.dart';
import './pattern.dart' as pattern; // Imports for regex patterns and other necessary components
import './router.dart' ;

final Logger logger = Logger('session');

class Session {
  final websocketClient = WebSocketClient();
  final ansipScreen = ansiparser.newScreen();
  late Router router ;

  Session() {
    router = Router(this);
  } 

  Uint8List send(String message) {
    final encodedMessage = utf8.encode(message);
    websocketClient.send(encodedMessage);

    return encodedMessage;
  }

  Future<List<int>> receiveRaw({int timeout = 2}) async {
    try {
      // return await websocketClient.messages.first.timeout(Duration(seconds: timeout));
      return await websocketClient.receiveQueue.get().timeout(Duration(seconds: timeout));
    } on TimeoutException {
      throw TimeoutException("Wait for receive timeout.");
    }
  }

  Future<String> receive({int timeout = 5}) async {
    final List<List<int>> messageFrames = [];

    while (true) {
      final frame = await receiveRaw(timeout: timeout);
      messageFrames.add(frame);

      try {
        final message = utf8.decode(messageFrames.expand((x) => x).toList(), allowMalformed: true);

        if (pattern.regexIncompleteAnsiEscape.hasMatch(message)) {
          continue; // Incomplete ANSI sequence, continue receiving
        }

        return message;
      } catch (e) {
        continue; // Continue receiving if decoding fails
      }
    }
  }

  Future<dynamic> untilString(String searchString, {bool drop = false, int timeout = 10}) async {
    return drop ? await _untilStringDrop(searchString, timeout) : await _untilString(searchString, timeout);
  }

  Future<String> _untilStringDrop(String searchString, int timeout) async {
    while (true) {
      final message = await receive(timeout: timeout);
      if (message.contains(searchString)) {
        return message;
      }
    }
  }

  Future<List<String>> _untilString(String searchString, int timeout) async {
    final messages = <String>[];

    while (true) {
      final message = await receive(timeout: timeout);
      messages.add(message);
      if (message.contains(searchString)) {
        return messages;
      }
    }
  }

  Future<dynamic> untilRegex(RegExp regex, {bool drop = false, int timeout = 10}) async {
    return drop ? await _untilRegexDrop(regex, timeout) : await _untilRegex(regex, timeout);
  }

  Future<String> _untilRegexDrop(RegExp regex, int timeout) async {
    while (true) {
      final message = await receive(timeout: timeout);
      if (regex.hasMatch(message)) {
        return message;
      }
    }
  }

  Future<List<String>> _untilRegex(RegExp regex, int timeout) async {
    final messages = <String>[];

    while (true) {
      final message = await receive(timeout: timeout);
      messages.add(message);
      if (regex.hasMatch(message)) {
        return messages;
      }
    }
  }

  Future<String> receiveAndPut({int timeout = 5}) async {
    final message = await receive(timeout: timeout);
    ansipScreen.put(message);
    return message;
  }

  Future<List<String>> untilStringAndPut(String searchString, {int timeout = 10}) async {
    final messages = await untilString(searchString, drop: false, timeout: timeout);
    for (var message in messages) {
      ansipScreen.put(message);
    }
    return messages;
  }

  Future<List<String>> untilRegexAndPut(RegExp regex, {int timeout = 10}) async {
    final messages = await untilRegex(regex, drop: false, timeout: timeout);
    for (var message in messages) {
      ansipScreen.put(message);
    }
    return messages;
  }
}
