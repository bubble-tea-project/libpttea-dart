// libpttea/navigator.dart

import 'dart:async';
import './pattern.dart' as pattern;
import './ptt_action.dart' as ptt_action;
import './sessions.dart';


bool inHome(Session session) {
  if (!session.ansipScreen.bufferEmpty()) {
    session.ansipScreen.parse();
  }

  final currentScreen = session.ansipScreen.toFormattedString();
  if (!currentScreen[0].contains("主功能表")) return false;

  return pattern.regexMenuStatusBar.hasMatch(currentScreen.last);

}

bool inUtility(Session session) {
  if (!session.ansipScreen.bufferEmpty()) {
    session.ansipScreen.parse();
  }
  
  final currentScreen = session.ansipScreen.toFormattedString();
  if (!currentScreen[0].contains("工具程式")) return false;

  return pattern.regexMenuStatusBar.hasMatch(currentScreen.last);
}

bool inBoard(Session session) {
  if (!session.ansipScreen.bufferEmpty()) {
    session.ansipScreen.parse();
  }
  
  final currentScreen = session.ansipScreen.toFormattedString();
  return pattern.regexBoardStatusBar.hasMatch(currentScreen.last);
}

bool inPost(Session session) {
  if (!session.ansipScreen.bufferEmpty()) {
    session.ansipScreen.parse();
  }
  
  final currentScreen = session.ansipScreen.toFormattedString();
  final matchNoContent = pattern.regexPostNoContent.firstMatch(currentScreen.last);
  if (matchNoContent != null) {
    throw Exception("The post has no content; it has already been deleted.");
  }

  return pattern.regexPostStatusBarSimple.hasMatch(currentScreen.last);
}

class Home {
  final Session _session;

  Home(this._session);

  Future<void> _utility() async {
    _session.send("x");
    _session.send(pattern.RIGHT_ARROW);

    await _session.untilStringAndPut("《查看系統資訊》");
    _session.ansipScreen.parse();
  }

  Future<void> _favorite() async {
    _session.send("f");
    _session.send(pattern.RIGHT_ARROW);

    await _session.untilStringAndPut("\x1b[30m已讀/未讀");
    _session.ansipScreen.parse();
  }

  Future<void> go(String target) async {
    switch (target) {
      case "favorite":
        await _favorite();
        break;
      case "utility":
        await _utility();
        break;
      default:
        throw UnimplementedError("Not supported yet , $target.");
    }
  }
}

class Utility {
  final Session _session;

  Utility(this._session);

  Future<void> _info() async {
    _session.send("x");
    _session.send(pattern.RIGHT_ARROW);

    await _session.untilStringAndPut("請按任意鍵繼續");
    _session.ansipScreen.parse();
  }

  Future<void> go(String target) async {
    switch (target) {
      case "info":
        await _info();
        break;
      default:
        throw UnimplementedError("Not supported yet , $target.");
    }
  }

  Future<void> back() async {
    _session.send(pattern.LEFT_ARROW);

    await _session.untilStringAndPut("\x1b[20;41H離開，再見");
    _session.ansipScreen.parse();
  }
}

class UtilityInfo {
  final Session _session;

  UtilityInfo(this._session);

  Future<void> back() async {
    _session.send(pattern.NEW_LINE);

    while (true) {
      await _session.receiveAndPut();
      if (inUtility(_session)) break;
    }
  }
}

class Favorite {
  final Session _session;

  Favorite(this._session);

  Future<void> _goBoard() async {
    _session.send(pattern.RIGHT_ARROW);

    const checkEnterBoard = ["請按任意鍵繼續", "任意鍵停止"];
    while (true) {
      final message = await _session.receiveAndPut();
      _session.ansipScreen.parse();

      if (checkEnterBoard.any((check) => message.contains(check))) {
        _session.send(pattern.RIGHT_ARROW);
        continue;
      }

      if (inBoard(_session)) break;
    }

    _session.send(pattern.END);
    try {
      await _session.untilRegexAndPut(RegExp(r">.+\x1b\["));
    } on TimeoutException {
      // already at the latest
    }

    _session.ansipScreen.parse();
  }

  Future<void> go(String target) async {
    await ptt_action.searchBoard(_session, target);
    await _goBoard();
  }

  Future<void> back() async {
    _session.send(pattern.LEFT_ARROW);

    while (true) {
      await _session.receiveAndPut();
      if (inHome(_session)) break;
    }
  }
}

class Board {
  final Session _session;

  Board(this._session);

  Future<void> _postByIndex(int index) async {
    await ptt_action.searchIndex(_session, index);
    _session.send(pattern.RIGHT_ARROW);

    while (true) {
      await _session.receiveAndPut();
      if (inPost(_session)) break;
    }
  }

  Future<void> go(int target) async {
    await _postByIndex(target);
  }

  Future<void> back() async {
    _session.send(pattern.LEFT_ARROW);

    await _session.untilStringAndPut("\x1b[30m已讀/未讀");
    _session.ansipScreen.parse();
  }
}

class Post {
  final Session _session;

  Post(this._session);

  Future<void> back() async {
    _session.send(pattern.LEFT_ARROW);

    while (true) {
      await _session.receiveAndPut();
      if (inBoard(_session)) break;
    }
  }
}
