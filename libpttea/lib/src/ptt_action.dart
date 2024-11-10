/// libpttea.ptt_action
/// ----------
///
/// This module provides functions that wrap user operations to interact with PTT.
library;

import 'dart:async';

import './pattern.dart' as pattern;
import './navigator.dart' as navigator;
import './sessions.dart';

/// Search for the board, and if it is found, the cursor will move to that position.
Future<void> searchBoard(Session session, String board) async {
  // let cursor to first item in favorite
  session.send(pattern.home);

  // Switch to list all
  final currentScreen = session.ansipScreen.toFormattedString();
  // check status bar
  if (RegExp(r"列出全部").hasMatch(currentScreen.last)) {
    session.send("y");
  }

  // Search board
  session.send("s");
  await session.untilStringAndPut("請輸入看板名稱(按空白鍵自動搜尋)");

  // Send board name
  session.send(board);
  await session.untilString(board);
  session.send(pattern.newLine);

  // Check search results
  while (true) {
    // wait page load
    final message = await session.receiveAndPut();
    session.ansipScreen.parse();

    // The cursor has not moved
    if (pattern.regexFavoriteCursorNotMoved.hasMatch(message)) {
      // Found, it is the first item

      // Recheck if the board is present on the current page
      final regexCursorBoard = RegExp(r"^>.+" + board);
      final currentScreen = session.ansipScreen.toFormattedString();
      if (!currentScreen.any((line) => regexCursorBoard.hasMatch(line))) {
        // Not found
        throw Exception("Board not found");
      } else {
        break;
      }
    }

    // The cursor has moved
    // Found, not the first item
    if (pattern.regexFavoriteCursorMoved.hasMatch(message)) {
      break;
    }
  }
}

/// Search for the index, and if it is found, the cursor will move to that position.
Future<void> searchIndex(Session session, int index) async {
  // go to the latest page of the board
  session.send(pattern.end);

  // Find post
  session.send(index.toString());
  await session.untilStringAndPut("跳至第幾項");
  session.send(pattern.newLine);

  // Check if found
  while (true) {
    await session.receiveAndPut();
    session.ansipScreen.parse();

    if (navigator.inBoard(session)) {
      // found in different page
      break;
    }

    final currentScreen = session.ansipScreen.toFormattedString();
    if (currentScreen.last.isEmpty) {
      // If found on the same page, the status bar will disappear.
      break;
    }
  }

  // Recheck if the index is present on the current page
  final currentScreen = session.ansipScreen.toFormattedString();

  // '>351769 +  10/22 kannax       □  [Vtub] '
  final regexPostIndex = RegExp(r"^(>| )\s?" + index.toString());
  if (!currentScreen.any((line) => regexPostIndex.hasMatch(line))) {
    // same page , but not found
    throw Exception("Post index not found");
  }
}
