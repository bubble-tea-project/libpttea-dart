/// libpttea.navigator
/// ----------
///
/// This module provides navigation capabilities used by the router.
library;

import 'dart:async';

import './pattern.dart' as pattern;
import './ptt_action.dart' as ptt_action;
import './sessions.dart';

bool inHome(Session session) {
  if (!session.ansipScreen.bufferEmpty()) {
    session.ansipScreen.parse();
  }

  final currentScreen = session.ansipScreen.toFormattedString();

  // Check the title line
  if (!currentScreen[0].contains("主功能表")) {
    return false;
  }

  // check status bar
  if (!pattern.regexMenuStatusBar.hasMatch(currentScreen.last)) {
    return false;
  }

  return true;
}

bool inUtility(Session session) {
  if (!session.ansipScreen.bufferEmpty()) {
    session.ansipScreen.parse();
  }

  final currentScreen = session.ansipScreen.toFormattedString();

  // Check the title line
  if (!currentScreen[0].contains("工具程式")) {
    return false;
  }

  // check status bar
  if (!pattern.regexMenuStatusBar.hasMatch(currentScreen.last)) {
    return false;
  }

  return true;
}

bool inBoard(Session session) {
  if (!session.ansipScreen.bufferEmpty()) {
    session.ansipScreen.parse();
  }

  final currentScreen = session.ansipScreen.toFormattedString();

  // check status bar
  if (!pattern.regexBoardStatusBar.hasMatch(currentScreen.last)) {
    return false;
  }

  return true;
}

bool inPost(Session session) {
  if (!session.ansipScreen.bufferEmpty()) {
    session.ansipScreen.parse();
  }

  final currentScreen = session.ansipScreen.toFormattedString();

  // check status bar
  if (pattern.regexPostNoContent.hasMatch(currentScreen.last)) {
    throw Exception("The post has no content; it has already been deleted.");
  }

  if (pattern.regexPostStatusBarSimple.hasMatch(currentScreen.last)) {
    return true;
  }

  return false;
}

/// Path is `/`.
class Home {
  final Session _session;

  Home(this._session);

  Future<void> _goUtility() async {
    _session.send("x");
    _session.send(pattern.rightArrow);

    await _session.untilStringAndPut("《查看系統資訊》");
    _session.ansipScreen.parse();
  }

  Future<void> _goFavorite() async {
    _session.send("f");
    _session.send(pattern.rightArrow);

    await _session.untilStringAndPut("\x1b[30m已讀/未讀");
    _session.ansipScreen.parse();
  }

  Future<void> go(String target) async {
    switch (target) {
      case "favorite":
        await _goFavorite();

      case "utility":
        await _goUtility();

      default:
        throw UnimplementedError("Not supported yet , $target.");
    }
  }
}

/// Path is `/utility`.
class Utility {
  final Session _session;

  Utility(this._session);

  Future<void> _goInfo() async {
    _session.send("x");
    _session.send(pattern.rightArrow);

    await _session.untilStringAndPut("請按任意鍵繼續");
    _session.ansipScreen.parse();
  }

  Future<void> go(String target) async {
    switch (target) {
      case "info":
        await _goInfo();

      default:
        throw UnimplementedError("Not supported yet , $target.");
    }
  }

  Future<void> back() async {
    _session.send(pattern.leftArrow);

    await _session.untilStringAndPut("\x1b[20;41H離開，再見");
    _session.ansipScreen.parse();
  }
}

class UtilityInfo {
  final Session _session;

  UtilityInfo(this._session);

  Future<void> back() async {
    _session.send(pattern.newLine);

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
    // go board
    _session.send(pattern.rightArrow);

    // wait for board loaded
    // 動畫播放中…可按 q,Ctrl-C 或其它任意鍵停止
    // 請按任意鍵繼續
    const checkEnterBoard = ["請按任意鍵繼續", "任意鍵停止"];

    while (true) {
      final message = await _session.receiveAndPut();
      _session.ansipScreen.parse();

      // skip - Enter board screen
      if (checkEnterBoard.any((check) => message.contains(check))) {
        _session.send(pattern.rightArrow);
        continue;
      }

      // if already in board
      if (inBoard(_session)) break;
    }

    // go to the latest
    _session.send(pattern.end);

    // wait if cursor has moved.
    try {
      await _session.untilRegexAndPut(RegExp(r">.+\x1b\["));
    } on TimeoutException {
      // already latest
    }

    _session.ansipScreen.parse();
  }

  Future<void> go(String target) async {
    await ptt_action.searchBoard(_session, target);
    await _goBoard();
  }

  Future<void> back() async {
    _session.send(pattern.leftArrow);

    while (true) {
      await _session.receiveAndPut();
      if (inHome(_session)) break;
    }
  }
}

/// Path is `/favorite/board`.
class Board {
  final Session _session;

  Board(this._session);

  Future<void> _goPostByIndex(int index) async {
    // find index
    await ptt_action.searchIndex(_session, index);

    // go to post
    _session.send(pattern.rightArrow);

    // wait post loaded
    while (true) {
      await _session.receiveAndPut();
      if (inPost(_session)) break;
    }
  }

  Future<void> go(int target) async {
    await _goPostByIndex(target);
  }

  Future<void> back() async {
    _session.send(pattern.leftArrow);

    await _session.untilStringAndPut("\x1b[30m已讀/未讀");
    _session.ansipScreen.parse();
  }
}

/// Path is `/favorite/board/post`.
class Post {
  final Session _session;

  Post(this._session);

  Future<void> back() async {
    _session.send(pattern.leftArrow);

    while (true) {
      await _session.receiveAndPut();
      if (inBoard(_session)) break;
    }
  }
}
