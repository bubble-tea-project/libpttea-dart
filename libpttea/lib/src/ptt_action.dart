/// libpttea.ptt_action
/// 
/// This module provides functions that wrap user operations to interact with PTT.

import 'dart:async';
import 'dart:core';
import 'dart:convert';
import './pattern.dart' as pattern;
import './navigator.dart' as navigator;
import './sessions.dart';

Future<void> searchBoard(Session session, String board) async {
  // Move cursor to first item
  session.send(pattern.HOME);

  // Switch to list all
  final currentScreen = session.ansipScreen.toFormattedString();
  final match = RegExp(r"列出全部").hasMatch(currentScreen.last);
  if (match) {
    session.send("y");
  }

  // Search board
  session.send("s");
  await session.untilStringAndPut("請輸入看板名稱(按空白鍵自動搜尋)");

  // Send board name
  session.send(board);
  await session.untilString(board);
  session.send(pattern.NEW_LINE);

  // Check search results
  while (true) {
    final message = await session.receiveAndPut();
    session.ansipScreen.parse();

    // Check if the cursor hasn't moved
    if (pattern.regexFavoriteCursorNotMoved.hasMatch(message)) {
      final regexCursorBoard = RegExp(r"^>.+" + board);
      final currentScreen = session.ansipScreen.toFormattedString();
      if (!currentScreen.any((line) => regexCursorBoard.hasMatch(line))) {
        throw Exception("Board not found");
      } else {
        break;
      }
    }

    // Check if cursor moved, indicating board is not the first item
    if (pattern.regexFavoriteCursorMoved.hasMatch(message)) {
      break;
    }
  }
}

Future<void> searchIndex(Session session, int index) async {
  // Move to the latest item
  session.send(pattern.END);

  // Find post
  session.send(index.toString());
  await session.untilStringAndPut("跳至第幾項");
  session.send(pattern.NEW_LINE);

  // Check if found
  while (true) {
    await session.receiveAndPut();
    session.ansipScreen.parse();

    if (navigator.inBoard(session)) {
      break;
    }

    // Check status bar
    final currentScreen = session.ansipScreen.toFormattedString();
    if (currentScreen.last.isEmpty) {
      break;
    }
  }

  // Recheck for index
  final currentScreen = session.ansipScreen.toFormattedString();
  final regexPostIndex = RegExp(r"^(>| )\s?" + index.toString());
  if (!currentScreen.any((line) => regexPostIndex.hasMatch(line))) {
    throw Exception("Post index not found");
  }
}
